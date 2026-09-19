use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::Path;

use anyhow::{Context, Result, bail};
use serde::Deserialize;

pub const ROLE_ORDER: [&str; 13] = [
    "browser",
    "shell",
    "terminal",
    "notifications",
    "tui_editor",
    "gui_editor",
    "bar",
    "dock",
    "calendar",
    "bluetooth",
    "network",
    "audio",
    "launcher",
];

const REQUIRED_ROLE_PACKAGE_EXCEPTIONS: [&str; 1] = ["networkmanager"];

#[derive(Clone, Copy, Debug, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum PackageSource {
    Pacman,
    Aur,
}

impl PackageSource {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Pacman => "pacman",
            Self::Aur => "aur",
        }
    }
}

#[derive(Clone, Copy, Debug, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum SelectionKind {
    Single,
    Multiple,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RequiredPackages {
    pub pacman: Vec<String>,
    pub aur: Vec<String>,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RoleOption {
    pub package: String,
    pub source: PackageSource,
    pub executable: String,
    pub args: Vec<String>,
    #[serde(default)]
    pub terminal: bool,
    #[serde(default)]
    pub class: Option<String>,
    #[serde(default)]
    pub extra_packages: Vec<String>,
    #[serde(default)]
    pub shell_path: Option<String>,
    #[serde(default)]
    pub editor_bin: Option<String>,
    #[serde(default)]
    pub desktop_file: Option<String>,
    #[serde(default)]
    pub dmenu_executable: Option<String>,
    #[serde(default)]
    pub dmenu_args: Option<Vec<String>>,
    #[serde(default)]
    pub process: Option<String>,
    #[serde(default)]
    pub namespace: Option<String>,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RoleDefinition {
    pub label: String,
    pub selection: SelectionKind,
    pub required: bool,
    pub default: Option<String>,
    pub options: Vec<RoleOption>,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PackagesRoot {
    pub hyprland_packages: BTreeMap<String, Vec<String>>,
    pub aur_packages: BTreeMap<String, Vec<String>>,
    #[serde(default)]
    pub package_descriptions: BTreeMap<String, String>,
    pub required: RequiredPackages,
    pub roles: BTreeMap<String, RoleDefinition>,
}

impl PackagesRoot {
    pub fn load(path: &Path) -> Result<Self> {
        let data = fs::read_to_string(path)
            .with_context(|| format!("read package registry {}", path.display()))?;
        let registry: Self = serde_json::from_str(&data)
            .with_context(|| format!("parse package registry {}", path.display()))?;
        registry.validate()?;
        Ok(registry)
    }

    pub fn validate(&self) -> Result<()> {
        let actual_roles: BTreeSet<&str> = self.roles.keys().map(String::as_str).collect();
        let expected_roles: BTreeSet<&str> = ROLE_ORDER.into_iter().collect();
        if actual_roles != expected_roles {
            bail!(
                "roles must be exactly {}; found {}",
                ROLE_ORDER.join(", "),
                self.roles.keys().cloned().collect::<Vec<_>>().join(", ")
            );
        }

        let mut registry_sources: BTreeMap<&str, PackageSource> = BTreeMap::new();
        self.collect_registry_packages(
            &self.hyprland_packages,
            PackageSource::Pacman,
            &mut registry_sources,
        )?;
        self.collect_registry_packages(
            &self.aur_packages,
            PackageSource::Aur,
            &mut registry_sources,
        )?;

        let mut role_packages: BTreeMap<&str, BTreeSet<&str>> = BTreeMap::new();
        for role_name in ROLE_ORDER {
            let role = &self.roles[role_name];
            if role.label.trim().is_empty() || has_control(&role.label) {
                bail!("role {role_name} has an invalid label");
            }
            if role.options.is_empty() {
                bail!("role {role_name} has no options");
            }
            match role.default.as_deref() {
                Some(default) if !role.options.iter().any(|option| option.package == default) => {
                    bail!("default package {default} is not an option for role {role_name}")
                }
                None if role.required => bail!("required role {role_name} must have a default"),
                _ => {}
            }

            let mut packages_in_role = BTreeSet::new();
            for option in &role.options {
                validate_option(role_name, option)?;
                if !packages_in_role.insert(option.package.as_str()) {
                    bail!(
                        "package {} is duplicated in role {role_name}",
                        option.package
                    );
                }
                match registry_sources.get(option.package.as_str()) {
                    Some(source) if *source == option.source => {}
                    Some(source) => bail!(
                        "role {role_name} package {} is marked {} but registered as {}",
                        option.package,
                        option.source.as_str(),
                        source.as_str()
                    ),
                    None => bail!(
                        "role {role_name} package {} is not in the package registry",
                        option.package
                    ),
                }
                role_packages
                    .entry(option.package.as_str())
                    .or_default()
                    .insert(role_name);
                for extra in &option.extra_packages {
                    validate_package_name(extra)?;
                    match registry_sources.get(extra.as_str()) {
                        Some(source) if *source == option.source => {}
                        Some(source) => bail!(
                            "extra package {extra} for {} is marked {} but registered as {}",
                            option.package,
                            option.source.as_str(),
                            source.as_str()
                        ),
                        None => bail!(
                            "extra package {extra} for {} is not in the package registry",
                            option.package
                        ),
                    }
                }
            }
        }

        self.validate_required(
            &self.required.pacman,
            PackageSource::Pacman,
            &registry_sources,
            &role_packages,
        )?;
        self.validate_required(
            &self.required.aur,
            PackageSource::Aur,
            &registry_sources,
            &role_packages,
        )?;
        Ok(())
    }

    fn collect_registry_packages<'a>(
        &'a self,
        categories: &'a BTreeMap<String, Vec<String>>,
        source: PackageSource,
        packages: &mut BTreeMap<&'a str, PackageSource>,
    ) -> Result<()> {
        for (category, names) in categories {
            if category.trim().is_empty() || has_control(category) {
                bail!("package registry has an invalid category name");
            }
            for package in names {
                validate_package_name(package)?;
                if let Some(previous_source) = packages.insert(package, source) {
                    bail!(
                        "package {package} appears more than once ({} and {})",
                        previous_source.as_str(),
                        source.as_str()
                    );
                }
            }
        }
        Ok(())
    }

    fn validate_required<'a>(
        &'a self,
        required: &'a [String],
        expected_source: PackageSource,
        registry_sources: &BTreeMap<&'a str, PackageSource>,
        role_packages: &BTreeMap<&'a str, BTreeSet<&'a str>>,
    ) -> Result<()> {
        let mut seen = BTreeSet::new();
        for package in required {
            validate_package_name(package)?;
            if !seen.insert(package) {
                bail!("required package {package} is duplicated");
            }
            match registry_sources.get(package.as_str()) {
                Some(source) if *source == expected_source => {}
                Some(source) => bail!(
                    "required package {package} is listed under {} instead of {}",
                    source.as_str(),
                    expected_source.as_str()
                ),
                None => bail!("required package {package} is not in the package registry"),
            }
            if let Some(roles) = role_packages.get(package.as_str())
                && !REQUIRED_ROLE_PACKAGE_EXCEPTIONS.contains(&package.as_str())
            {
                bail!(
                    "required package {package} is also an option for role(s) {}",
                    roles.iter().copied().collect::<Vec<_>>().join(", ")
                );
            }
        }
        Ok(())
    }

    pub fn categorized(&self, source: PackageSource) -> Vec<(String, Vec<String>)> {
        let categories = match source {
            PackageSource::Pacman => &self.hyprland_packages,
            PackageSource::Aur => &self.aur_packages,
        };
        let controlled = self.role_controlled_packages(source);
        categories
            .iter()
            .filter_map(|(category, packages)| {
                let mut packages: Vec<String> = packages
                    .iter()
                    .filter(|package| !controlled.contains(package.as_str()))
                    .cloned()
                    .collect();
                packages.sort();
                (!packages.is_empty()).then(|| (category.clone(), packages))
            })
            .collect()
    }

    pub fn required_set(&self, source: PackageSource) -> BTreeSet<String> {
        match source {
            PackageSource::Pacman => self.required.pacman.iter().cloned().collect(),
            PackageSource::Aur => self.required.aur.iter().cloned().collect(),
        }
    }

    pub fn role_controlled_packages(&self, source: PackageSource) -> BTreeSet<&str> {
        self.roles
            .values()
            .flat_map(|role| &role.options)
            .filter(|option| option.source == source)
            .flat_map(|option| {
                std::iter::once(option.package.as_str())
                    .chain(option.extra_packages.iter().map(String::as_str))
            })
            .collect()
    }

    pub fn is_role_controlled_package(&self, package: &str) -> bool {
        self.roles.values().any(|role| {
            role.options.iter().any(|option| {
                option.package == package
                    || option.extra_packages.iter().any(|extra| extra == package)
            })
        })
    }
}

pub fn enforce_required(required: &BTreeSet<String>, selections: &mut BTreeMap<String, bool>) {
    for package in required {
        selections.insert(package.clone(), true);
    }
}

pub fn toggle_with_required(
    required: &BTreeSet<String>,
    selections: &mut BTreeMap<String, bool>,
    package: &str,
) {
    if required.contains(package) {
        enforce_required(required, selections);
        return;
    }
    let selected = selections.entry(package.to_string()).or_insert(false);
    *selected = !*selected;
    enforce_required(required, selections);
}

pub fn set_all_with_required(
    required: &BTreeSet<String>,
    selections: &mut BTreeMap<String, bool>,
    selected: bool,
) {
    for value in selections.values_mut() {
        *value = selected;
    }
    enforce_required(required, selections);
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
struct RoleChoice {
    members: BTreeSet<String>,
    primary: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RoleSelection {
    selected: BTreeMap<String, RoleChoice>,
}

impl RoleSelection {
    pub fn defaults(registry: &PackagesRoot) -> Self {
        Self {
            selected: ROLE_ORDER
                .into_iter()
                .map(|role_name| {
                    let primary = registry.roles[role_name].default.clone();
                    let members = primary.iter().cloned().collect();
                    (role_name.to_string(), RoleChoice { members, primary })
                })
                .collect(),
        }
    }

    #[cfg(test)]
    fn empty() -> Self {
        Self {
            selected: ROLE_ORDER
                .into_iter()
                .map(|role_name| (role_name.to_string(), RoleChoice::default()))
                .collect(),
        }
    }

    pub fn selected_package(&self, role_name: &str) -> Option<&str> {
        self.selected
            .get(role_name)
            .and_then(|choice| choice.primary.as_deref())
    }

    pub fn selected_packages(&self, role_name: &str) -> Option<&BTreeSet<String>> {
        self.selected.get(role_name).map(|choice| &choice.members)
    }

    pub fn toggle_member(
        &mut self,
        registry: &PackagesRoot,
        role_name: &str,
        package: &str,
    ) -> Result<()> {
        let role = registry
            .roles
            .get(role_name)
            .with_context(|| format!("unknown role {role_name}"))?;
        if !role.options.iter().any(|option| option.package == package) {
            bail!("package {package} is not an option for role {role_name}");
        }
        let choice = self
            .selected
            .get_mut(role_name)
            .with_context(|| format!("selection state is missing role {role_name}"))?;
        if choice.members.contains(package) {
            choice.members.remove(package);
            if choice.primary.as_deref() == Some(package) {
                choice.primary = choice.members.first().cloned();
            }
        } else if role.selection == SelectionKind::Single {
            choice.members.clear();
            choice.members.insert(package.to_string());
            choice.primary = Some(package.to_string());
        } else {
            choice.members.insert(package.to_string());
            if choice.primary.is_none() {
                choice.primary = Some(package.to_string());
            }
        }
        Ok(())
    }

    pub fn clear(&mut self, registry: &PackagesRoot, role_name: &str) -> Result<()> {
        registry
            .roles
            .get(role_name)
            .with_context(|| format!("unknown role {role_name}"))?;
        let choice = self
            .selected
            .get_mut(role_name)
            .with_context(|| format!("selection state is missing role {role_name}"))?;
        choice.members.clear();
        choice.primary = None;
        Ok(())
    }

    pub fn set_primary(
        &mut self,
        registry: &PackagesRoot,
        role_name: &str,
        package: &str,
    ) -> Result<()> {
        let role = registry
            .roles
            .get(role_name)
            .with_context(|| format!("unknown role {role_name}"))?;
        if !role.options.iter().any(|option| option.package == package) {
            bail!("package {package} is not an option for role {role_name}");
        }
        let choice = self
            .selected
            .get_mut(role_name)
            .with_context(|| format!("selection state is missing role {role_name}"))?;
        if !choice.members.contains(package) {
            bail!("primary package {package} is not selected for role {role_name}");
        }
        choice.primary = Some(package.to_string());
        Ok(())
    }

    pub fn missing_roles<'a>(&'a self, registry: &'a PackagesRoot) -> Vec<&'a str> {
        ROLE_ORDER
            .into_iter()
            .filter(|role_name| {
                let role = &registry.roles[*role_name];
                let choice = &self.selected[*role_name];
                role.required && choice.members.is_empty()
            })
            .map(|role_name| registry.roles[role_name].label.as_str())
            .collect()
    }

    pub fn selected_install_packages(
        &self,
        registry: &PackagesRoot,
        source: PackageSource,
    ) -> BTreeSet<String> {
        ROLE_ORDER
            .into_iter()
            .flat_map(|role_name| {
                let members = &self.selected[role_name].members;
                registry.roles[role_name]
                    .options
                    .iter()
                    .filter(move |option| {
                        option.source == source && members.contains(&option.package)
                    })
                    .flat_map(|option| {
                        std::iter::once(option.package.clone())
                            .chain(option.extra_packages.iter().cloned())
                    })
            })
            .collect()
    }

    pub fn export_env(&self, registry: &PackagesRoot) -> Result<BTreeMap<String, String>> {
        let missing = self.missing_roles(registry);
        if !missing.is_empty() {
            bail!("required roles without a selection: {}", missing.join(", "));
        }
        let mut env = BTreeMap::new();
        for role_name in ROLE_ORDER {
            let role = &registry.roles[role_name];
            let choice = &self.selected[role_name];
            if role.selection == SelectionKind::Single && choice.members.len() > 1 {
                bail!("single-select role {role_name} has multiple members");
            }
            if choice
                .primary
                .as_ref()
                .is_some_and(|primary| !choice.members.contains(primary))
            {
                bail!("primary for role {role_name} is not selected");
            }
            if !choice.members.is_empty() && choice.primary.is_none() {
                bail!("role {role_name} has selected members but no primary");
            }
            let key = role_name.to_ascii_uppercase();
            env.insert(
                format!("ROLE_{key}"),
                choice.primary.clone().unwrap_or_default(),
            );
            env.insert(
                format!("ROLE_{key}_PACKAGES"),
                choice.members.iter().cloned().collect::<Vec<_>>().join(" "),
            );
        }
        Ok(env)
    }
}

fn validate_option(role_name: &str, option: &RoleOption) -> Result<()> {
    validate_package_name(&option.package)?;
    validate_executable(&option.executable, "executable")?;
    validate_args(&option.args)?;

    match role_name {
        "browser" | "terminal" => {
            require_token(&option.class, "class", &option.package)?;
            reject_fields(
                option,
                &["shell_path", "editor_bin", "desktop_file", "dmenu"],
            )?;
        }
        "shell" => {
            let shell_path = option.shell_path.as_deref().with_context(|| {
                format!("shell option {} is missing shell_path", option.package)
            })?;
            if !shell_path.starts_with('/') {
                bail!("shell path for {} must be absolute", option.package);
            }
            validate_executable(shell_path, "shell_path")?;
            reject_fields(option, &["class", "editor_bin", "desktop_file", "dmenu"])?;
        }
        "gui_editor" => {
            require_token(&option.editor_bin, "editor_bin", &option.package)?;
            require_token(&option.desktop_file, "desktop_file", &option.package)?;
            reject_fields(option, &["class", "shell_path", "dmenu"])?;
        }
        "tui_editor" => {
            require_token(&option.editor_bin, "editor_bin", &option.package)?;
            reject_fields(option, &["class", "shell_path", "desktop_file", "dmenu"])?;
        }
        "launcher" => {
            let dmenu = option.dmenu_executable.as_deref().with_context(|| {
                format!(
                    "launcher option {} is missing dmenu_executable",
                    option.package
                )
            })?;
            validate_executable(dmenu, "dmenu_executable")?;
            validate_args(option.dmenu_args.as_deref().with_context(|| {
                format!("launcher option {} is missing dmenu_args", option.package)
            })?)?;
            require_token(&option.process, "process", &option.package)?;
            require_token(&option.namespace, "namespace", &option.package)?;
            reject_fields(
                option,
                &["class", "shell_path", "editor_bin", "desktop_file"],
            )?;
        }
        "notifications" | "bar" | "dock" | "calendar" | "bluetooth" | "network" | "audio" => {
            reject_fields(
                option,
                &["class", "shell_path", "editor_bin", "desktop_file", "dmenu"],
            )?
        }
        _ => bail!("unknown role {role_name}"),
    }
    Ok(())
}

fn reject_fields(option: &RoleOption, fields: &[&str]) -> Result<()> {
    for field in fields {
        let present = match *field {
            "class" => option.class.is_some(),
            "shell_path" => option.shell_path.is_some(),
            "editor_bin" => option.editor_bin.is_some(),
            "desktop_file" => option.desktop_file.is_some(),
            "dmenu" => {
                option.dmenu_executable.is_some()
                    || option.dmenu_args.is_some()
                    || option.process.is_some()
                    || option.namespace.is_some()
            }
            _ => false,
        };
        if present {
            bail!(
                "option {} has field not valid for its role: {field}",
                option.package
            );
        }
    }
    Ok(())
}

fn validate_package_name(name: &str) -> Result<()> {
    if name.is_empty()
        || !name.bytes().all(|byte| {
            byte.is_ascii_lowercase() || byte.is_ascii_digit() || b"@._+-".contains(&byte)
        })
    {
        bail!("invalid package name {name:?}");
    }
    Ok(())
}

fn validate_executable(value: &str, field: &str) -> Result<()> {
    if value.is_empty()
        || !value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || b"@._+/-".contains(&byte))
    {
        bail!("invalid {field} value {value:?}");
    }
    Ok(())
}

fn validate_args(args: &[String]) -> Result<()> {
    for arg in args {
        if has_control(arg) {
            bail!("argument contains control characters");
        }
        if arg.contains("{HOME}") && !arg.starts_with("{HOME}/") {
            bail!("{{HOME}} is only allowed as a leading path token");
        }
    }
    Ok(())
}

fn require_token(value: &Option<String>, field: &str, package: &str) -> Result<()> {
    let value = value
        .as_deref()
        .with_context(|| format!("option {package} is missing {field}"))?;
    if value.is_empty()
        || has_control(value)
        || !value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || b"@._+-".contains(&byte))
    {
        bail!("option {package} has invalid {field}");
    }
    Ok(())
}

fn has_control(value: &str) -> bool {
    value.chars().any(char::is_control)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn shipped_registry() -> PackagesRoot {
        PackagesRoot::load(Path::new(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/packages.json"
        )))
        .expect("shipped package registry must be valid")
    }

    #[test]
    fn shipped_schema_has_all_roles_and_cardinalities() {
        let registry = shipped_registry();
        assert_eq!(registry.roles.len(), ROLE_ORDER.len());
        assert_eq!(
            ROLE_ORDER
                .into_iter()
                .filter(|role| registry.roles[*role].selection == SelectionKind::Single)
                .count(),
            7
        );
        assert_eq!(
            ROLE_ORDER
                .into_iter()
                .filter(|role| registry.roles[*role].selection == SelectionKind::Multiple)
                .count(),
            6
        );
        assert_eq!(
            ROLE_ORDER
                .into_iter()
                .filter(|role| registry.roles[*role].required)
                .count(),
            11
        );
        assert_eq!(
            registry
                .roles
                .values()
                .map(|role| role.options.len())
                .sum::<usize>(),
            54
        );
    }

    #[test]
    fn multiple_selection_tracks_membership_and_primary_independently() {
        let registry = shipped_registry();
        let mut selection = RoleSelection::defaults(&registry);
        selection
            .toggle_member(&registry, "terminal", "foot")
            .unwrap();
        assert_eq!(selection.selected_package("terminal"), Some("kitty"));
        assert_eq!(
            selection.selected_packages("terminal").unwrap(),
            &BTreeSet::from(["foot".to_string(), "kitty".to_string()])
        );
        selection
            .set_primary(&registry, "terminal", "foot")
            .unwrap();
        assert_eq!(selection.selected_package("terminal"), Some("foot"));
    }

    #[test]
    fn single_selection_replaces_previous_member_and_can_be_temporarily_empty() {
        let registry = shipped_registry();
        let mut selection = RoleSelection::defaults(&registry);
        selection
            .toggle_member(&registry, "launcher", "fuzzel")
            .unwrap();
        assert_eq!(
            selection.selected_packages("launcher").unwrap(),
            &BTreeSet::from(["fuzzel".to_string()])
        );
        selection
            .toggle_member(&registry, "launcher", "fuzzel")
            .unwrap();
        assert!(selection.selected_packages("launcher").unwrap().is_empty());
        assert_eq!(selection.missing_roles(&registry), vec!["Launcher"]);
    }

    #[test]
    fn optional_roles_export_explicit_empty_values() {
        let registry = shipped_registry();
        let selection = RoleSelection::defaults(&registry);
        let env = selection.export_env(&registry).unwrap();
        assert_eq!(env["ROLE_DOCK"], "");
        assert_eq!(env["ROLE_DOCK_PACKAGES"], "");
        assert_eq!(env["ROLE_GUI_EDITOR"], "visual-studio-code-bin");
        assert_eq!(env.len(), ROLE_ORDER.len() * 2);
    }

    #[test]
    fn selected_package_union_includes_dependencies_and_shared_members() {
        let registry = shipped_registry();
        let mut selection = RoleSelection::defaults(&registry);
        selection
            .toggle_member(&registry, "bar", "nwg-panel")
            .unwrap();
        selection
            .toggle_member(&registry, "dock", "nwg-panel")
            .unwrap();
        selection
            .toggle_member(&registry, "browser", "vivaldi")
            .unwrap();
        let selected = selection.selected_install_packages(&registry, PackageSource::Pacman);
        assert!(selected.contains("nwg-panel"));
        assert!(selected.contains("vivaldi"));
        assert!(selected.contains("vivaldi-ffmpeg-codecs"));
        assert!(!selected.contains("plasma-systemmonitor"));
        assert!(!selected.contains("zenity"));
        assert_eq!(selected.iter().filter(|p| *p == "nwg-panel").count(), 1);
    }

    #[test]
    fn role_packages_are_hidden_from_generic_categories() {
        let registry = shipped_registry();
        for source in [PackageSource::Pacman, PackageSource::Aur] {
            let generic: BTreeSet<String> = registry
                .categorized(source)
                .into_iter()
                .flat_map(|(_, packages)| packages)
                .collect();
            assert!(
                generic.is_disjoint(
                    &registry
                        .role_controlled_packages(source)
                        .into_iter()
                        .map(str::to_string)
                        .collect()
                )
            );
        }
    }

    #[test]
    fn required_packages_survive_none_and_toggle_attempts() {
        let registry = shipped_registry();
        let required = registry.required_set(PackageSource::Pacman);
        let mut selections: BTreeMap<String, bool> = registry
            .hyprland_packages
            .values()
            .flatten()
            .map(|package| (package.clone(), true))
            .collect();

        set_all_with_required(&required, &mut selections, false);
        assert!(required.iter().all(|package| selections[package]));
        assert!(!selections["dolphin"]);
        toggle_with_required(&required, &mut selections, "networkmanager");
        assert!(selections["networkmanager"]);
    }

    #[test]
    fn networkmanager_is_the_only_required_role_package_exception() {
        let registry = shipped_registry();
        assert!(
            registry
                .required
                .pacman
                .contains(&"networkmanager".to_string())
        );
        assert!(
            registry.roles["network"]
                .options
                .iter()
                .any(|option| option.package == "networkmanager")
        );

        let mut invalid = shipped_registry();
        invalid.required.pacman.push("waybar".to_string());
        assert!(
            invalid
                .validate()
                .unwrap_err()
                .to_string()
                .contains("also an option")
        );
    }

    #[test]
    fn zero_selected_required_roles_block_export_but_optional_roles_do_not() {
        let registry = shipped_registry();
        let selection = RoleSelection::empty();
        let error = selection.export_env(&registry).unwrap_err().to_string();
        assert!(error.contains("Browser"));
        assert!(error.contains("Launcher"));
        assert!(!error.contains("GUI editor"));
        assert!(!error.contains("Dock"));
    }

    #[test]
    fn source_corrections_and_terminal_metadata_are_preserved() {
        let registry = shipped_registry();
        let tofi = registry.roles["launcher"]
            .options
            .iter()
            .find(|option| option.package == "tofi")
            .unwrap();
        assert_eq!(tofi.source, PackageSource::Aur);
        assert_eq!(tofi.executable, "tofi-drun");
        assert_eq!(tofi.args, ["--drun-launch=true"]);
        assert!(
            registry.roles["calendar"]
                .options
                .iter()
                .find(|option| option.package == "khal")
                .unwrap()
                .terminal
        );
        assert!(
            registry.roles["audio"]
                .options
                .iter()
                .find(|option| option.package == "alsa-utils")
                .unwrap()
                .terminal
        );
    }

    #[test]
    fn shipped_packages_use_current_hyprland_guiutils_name() {
        let registry = shipped_registry();
        let packages: BTreeSet<&str> = registry
            .hyprland_packages
            .values()
            .flatten()
            .map(String::as_str)
            .collect();
        assert!(packages.contains("hyprland-guiutils"));
        assert!(!packages.contains("hyprland-qtutils"));
    }

    #[test]
    fn zed_role_uses_the_installed_arch_executable() {
        let registry = shipped_registry();
        let zed = registry.roles["gui_editor"]
            .options
            .iter()
            .find(|option| option.package == "zed")
            .unwrap();
        assert_eq!(zed.executable, "zeditor");
        assert_eq!(zed.editor_bin.as_deref(), Some("zeditor"));
        assert_eq!(zed.desktop_file.as_deref(), Some("dev.zed.Zed.desktop"));
    }

    #[test]
    fn restricted_role_tokens_reject_path_separators() {
        let mut registry = shipped_registry();
        registry.roles.get_mut("launcher").unwrap().options[0].namespace =
            Some("bad/name".to_string());
        assert!(
            registry
                .validate()
                .unwrap_err()
                .to_string()
                .contains("invalid namespace")
        );
    }
}
