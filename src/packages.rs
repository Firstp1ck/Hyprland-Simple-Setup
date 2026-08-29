use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::Path;

use anyhow::{Context, Result, bail};
use serde::Deserialize;

pub const ROLE_ORDER: [&str; 6] = [
    "browser",
    "terminal",
    "shell",
    "gui_editor",
    "tui_editor",
    "launcher",
];

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
    pub class: Option<String>,
    #[serde(default)]
    pub extra_packages: Vec<String>,
    #[serde(default)]
    pub shell_path: Option<String>,
    #[serde(default)]
    pub editor_bin: Option<String>,
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
    pub default: String,
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

        let mut role_packages: BTreeMap<&str, &str> = BTreeMap::new();
        for role_name in ROLE_ORDER {
            let role = &self.roles[role_name];
            if role.label.trim().is_empty() || has_control(&role.label) {
                bail!("role {role_name} has an invalid label");
            }
            if role.options.is_empty() {
                bail!("role {role_name} has no options");
            }
            if !role
                .options
                .iter()
                .any(|option| option.package == role.default)
            {
                bail!(
                    "default package {} is not an option for role {role_name}",
                    role.default
                );
            }

            for option in &role.options {
                validate_option(role_name, option)?;
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
                if let Some(previous_role) = role_packages.insert(&option.package, role_name) {
                    bail!(
                        "package {} appears in roles {previous_role} and {role_name}",
                        option.package
                    );
                }
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
        role_packages: &BTreeMap<&'a str, &'a str>,
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
            if let Some(role) = role_packages.get(package.as_str()) {
                bail!("required package {package} is also an option for role {role}");
            }
        }
        Ok(())
    }

    pub fn categorized(&self, source: PackageSource) -> Vec<(String, Vec<String>)> {
        let categories = match source {
            PackageSource::Pacman => &self.hyprland_packages,
            PackageSource::Aur => &self.aur_packages,
        };
        categories
            .iter()
            .map(|(category, packages)| {
                let mut packages = packages.clone();
                packages.sort();
                (category.clone(), packages)
            })
            .collect()
    }

    pub fn required_set(&self, source: PackageSource) -> BTreeSet<String> {
        match source {
            PackageSource::Pacman => self.required.pacman.iter().cloned().collect(),
            PackageSource::Aur => self.required.aur.iter().cloned().collect(),
        }
    }

    pub fn role_for_package(&self, package: &str) -> Option<&str> {
        ROLE_ORDER.into_iter().find(|role_name| {
            self.roles[*role_name]
                .options
                .iter()
                .any(|option| option.package == package)
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

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RoleSelection {
    selected: BTreeMap<String, Option<String>>,
}

impl RoleSelection {
    pub fn defaults(registry: &PackagesRoot) -> Self {
        Self {
            selected: ROLE_ORDER
                .into_iter()
                .map(|role_name| {
                    (
                        role_name.to_string(),
                        Some(registry.roles[role_name].default.clone()),
                    )
                })
                .collect(),
        }
    }

    #[cfg(test)]
    fn empty() -> Self {
        Self {
            selected: ROLE_ORDER
                .into_iter()
                .map(|role_name| (role_name.to_string(), None))
                .collect(),
        }
    }

    pub fn selected_package(&self, role_name: &str) -> Option<&str> {
        self.selected.get(role_name).and_then(Option::as_deref)
    }

    pub fn clear_source(&mut self, registry: &PackagesRoot, source: PackageSource) {
        for role_name in ROLE_ORDER {
            let selected_source = self.selected_package(role_name).and_then(|package| {
                registry.roles[role_name]
                    .options
                    .iter()
                    .find(|option| option.package == package)
                    .map(|option| option.source)
            });
            if selected_source == Some(source) {
                self.selected.insert(role_name.to_string(), None);
            }
        }
    }

    pub fn select(
        &mut self,
        registry: &PackagesRoot,
        role_name: &str,
        package: Option<&str>,
    ) -> Result<()> {
        let role = registry
            .roles
            .get(role_name)
            .with_context(|| format!("unknown role {role_name}"))?;
        if let Some(package) = package
            && !role.options.iter().any(|option| option.package == package)
        {
            bail!("package {package} is not an option for role {role_name}");
        }
        self.selected.insert(
            role_name.to_string(),
            package.map(std::string::ToString::to_string),
        );
        Ok(())
    }

    pub fn toggle_package(&mut self, registry: &PackagesRoot, package: &str) -> Result<bool> {
        let Some(role_name) = registry.role_for_package(package) else {
            return Ok(false);
        };
        let selected = self.selected_package(role_name);
        if selected == Some(package) {
            self.select(registry, role_name, None)?;
        } else {
            self.select(registry, role_name, Some(package))?;
        }
        Ok(true)
    }

    pub fn cycle(&mut self, registry: &PackagesRoot, role_name: &str, delta: i32) -> Result<()> {
        let role = registry
            .roles
            .get(role_name)
            .with_context(|| format!("unknown role {role_name}"))?;
        let len = role.options.len();
        if len == 0 {
            bail!("role {role_name} has no options");
        }
        let Some(current) = self.selected_package(role_name).and_then(|package| {
            role.options
                .iter()
                .position(|option| option.package == package)
        }) else {
            return self.select(registry, role_name, Some(&role.default));
        };
        let next = (current as i32 + delta).rem_euclid(len as i32) as usize;
        self.select(registry, role_name, Some(&role.options[next].package))
    }

    pub fn missing_roles<'a>(&'a self, registry: &'a PackagesRoot) -> Vec<&'a str> {
        ROLE_ORDER
            .into_iter()
            .filter(|role_name| self.selected_package(role_name).is_none())
            .map(|role_name| registry.roles[role_name].label.as_str())
            .collect()
    }

    pub fn export_env(&self, registry: &PackagesRoot) -> Result<BTreeMap<String, String>> {
        let missing = self.missing_roles(registry);
        if !missing.is_empty() {
            bail!("roles without a selection: {}", missing.join(", "));
        }
        Ok(ROLE_ORDER
            .into_iter()
            .map(|role_name| {
                (
                    format!("ROLE_{}", role_name.to_ascii_uppercase()),
                    self.selected_package(role_name)
                        .expect("missing roles were checked")
                        .to_string(),
                )
            })
            .collect())
    }
}

fn validate_option(role_name: &str, option: &RoleOption) -> Result<()> {
    validate_package_name(&option.package)?;
    validate_executable(&option.executable, "executable")?;
    validate_args(&option.args)?;
    if option.args.iter().any(|arg| has_control(arg)) {
        bail!(
            "{} has an argument containing control characters",
            option.package
        );
    }

    match role_name {
        "browser" | "terminal" => {
            require_token(&option.class, "class", &option.package)?;
            reject_fields(option, &["shell_path", "editor_bin", "dmenu"])?;
        }
        "shell" => {
            let shell_path = option.shell_path.as_deref().with_context(|| {
                format!("shell option {} is missing shell_path", option.package)
            })?;
            if !shell_path.starts_with('/') {
                bail!("shell path for {} must be absolute", option.package);
            }
            validate_executable(shell_path, "shell_path")?;
            reject_fields(option, &["class", "editor_bin", "dmenu"])?;
        }
        "gui_editor" | "tui_editor" => {
            require_token(&option.editor_bin, "editor_bin", &option.package)?;
            reject_fields(option, &["class", "shell_path", "dmenu"])?;
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
            reject_fields(option, &["class", "shell_path", "editor_bin"])?;
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
    fn shipped_schema_parses_and_validates() {
        let registry = shipped_registry();
        assert_eq!(registry.roles.len(), ROLE_ORDER.len());
        assert_eq!(
            registry
                .roles
                .values()
                .map(|role| role.options.len())
                .sum::<usize>(),
            22
        );
    }

    #[test]
    fn selecting_role_option_replaces_its_sibling() {
        let registry = shipped_registry();
        let mut selection = RoleSelection::defaults(&registry);
        selection
            .select(&registry, "terminal", Some("alacritty"))
            .unwrap();
        assert_eq!(selection.selected_package("terminal"), Some("alacritty"));
        assert_ne!(selection.selected_package("terminal"), Some("kitty"));
    }

    #[test]
    fn toggling_selected_role_option_leaves_role_missing() {
        let registry = shipped_registry();
        let mut selection = RoleSelection::defaults(&registry);
        assert!(selection.toggle_package(&registry, "kitty").unwrap());
        assert_eq!(selection.selected_package("terminal"), None);
        assert_eq!(selection.missing_roles(&registry), vec!["Terminal"]);
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

        toggle_with_required(&required, &mut selections, "hyprland");
        assert!(selections["hyprland"]);
        toggle_with_required(&required, &mut selections, "dolphin");
        assert!(selections["dolphin"]);
    }

    #[test]
    fn exported_env_contains_every_role() {
        let registry = shipped_registry();
        let env = RoleSelection::defaults(&registry)
            .export_env(&registry)
            .unwrap();
        assert_eq!(env.len(), ROLE_ORDER.len());
        for role_name in ROLE_ORDER {
            assert!(env.contains_key(&format!("ROLE_{}", role_name.to_ascii_uppercase())));
        }
    }

    #[test]
    fn zero_selected_role_blocks_export() {
        let registry = shipped_registry();
        let selection = RoleSelection::empty();
        let error = selection.export_env(&registry).unwrap_err().to_string();
        assert!(error.contains("Browser"));
        assert!(error.contains("Launcher"));
    }
}
