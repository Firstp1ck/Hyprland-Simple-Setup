mod packages;

use std::io::{self};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::mpsc::{self, Receiver, Sender};
use std::thread;
use std::time::{Duration, Instant};

use anyhow::{Context, Result, bail};
use chrono::Local;
use crossterm::event::{
    self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode, KeyEvent, KeyEventKind,
    MouseButton, MouseEvent, MouseEventKind,
};
use crossterm::execute;
use crossterm::terminal::{
    EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode,
};
use ratatui::Terminal;
use ratatui::backend::CrosstermBackend;
use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span, Text};
use ratatui::widgets::{
    Block, Borders, Cell, Clear, List, ListItem, ListState, Paragraph, Row, Table, TableState, Wrap,
};
use std::collections::{BTreeMap, BTreeSet, HashMap, HashSet};

use packages::{
    PackageSource, PackagesRoot, ROLE_ORDER, RoleSelection, SelectionKind, enforce_required,
    set_all_with_required, toggle_with_required,
};
use std::fs;
use std::fs::OpenOptions;
use std::io::Read as IoRead;
use std::io::Write as IoWrite;

// MenuAction/MenuItem and process tracking removed to simplify and avoid warnings

// Catppuccin Mocha theme
#[derive(Clone, Copy, Debug)]
struct Theme {
    base: Color,
    surface0: Color,
    surface1: Color,
    text: Color,
    subtext0: Color,
    yellow: Color,
    mauve: Color,
    blue: Color,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum StepSeverity {
    None,
    Warning,
    Error,
}

#[derive(Clone, Debug)]
struct SetupSection {
    title: String,
    done: bool,
    severity: StepSeverity,
}

impl Theme {
    fn catppuccin_mocha() -> Self {
        Self {
            base: Color::Rgb(30, 30, 46),        // #1e1e2e
            surface0: Color::Rgb(49, 50, 68),    // #313244
            surface1: Color::Rgb(69, 71, 90),    // #45475a
            text: Color::Rgb(205, 214, 244),     // #cdd6f4
            subtext0: Color::Rgb(166, 173, 200), // #a6adc8
            yellow: Color::Rgb(249, 226, 175),   // #f9e2af
            mauve: Color::Rgb(203, 166, 247),    // #cba6f7
            blue: Color::Rgb(137, 180, 250),     // #89b4fa
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum UiMode {
    Menu,
    Preflight,
}

#[derive(Clone, Debug)]
struct PreflightConfig {
    prompt_default_yes: bool,
    fish_language_choice: u8, // 1,2,3
    wallpaper_dir: String,
    monitor_setup_enabled: bool,
    monitor_config: String,
    auto_continue_on_warnings: bool,
    dry_run: bool,
    password: String,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum PreflightField {
    EnvPromptDefaultYn,
    EnvFishLanguageChoiceOverride,
    Applications,
    EnvWallpaperDirOverride,
    EnvMonitorSetupEnabled,
    EnvMonitorConfig,
    EnvAutoContinueOnWarnings,
    EnvDryRun,
    Password,
    SelectPacman,
    SelectAur,
    AddPackages,
    Start,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum EditKind {
    None,
    Text,
    MonitorWizard,
    Info,
    AddPackagesWarning,
    ConfirmReboot,
    ConfirmEnableMonitorSetup,
    ConfirmStartInstall,
    SelectApplications,
    SelectRole,
    SelectPacman,
    SelectAur,
}

#[derive(Clone, Debug, Default)]
struct MonitorInfo {
    name: String,
    modes: Vec<String>,
}

const OUTPUT_HISTORY_LIMIT: usize = 5000;

#[derive(Default)]
struct OutputLog {
    detailed: Vec<String>,
    compact: Vec<String>,
    show_details: bool,
    in_summary: bool,
}

impl OutputLog {
    fn lines(&self) -> &[String] {
        if self.show_details {
            &self.detailed
        } else {
            &self.compact
        }
    }

    fn len(&self) -> usize {
        self.lines().len()
    }

    fn clear(&mut self) {
        self.detailed.clear();
        self.compact.clear();
    }

    // Keep separate histories so build chatter cannot evict compact status messages.
    fn push(&mut self, stored: String, raw: &str) -> usize {
        if raw == "Install started" {
            self.in_summary = false;
        }
        if raw.contains("========= Installation Summary =========")
            || raw.contains("Final Setup Report")
            || raw.starts_with("[DRY-RUN SUMMARY]")
        {
            self.in_summary = true;
        }
        let compact = self.in_summary || is_compact_output(raw);
        self.detailed.push(stored.clone());
        if compact {
            self.compact.push(stored);
        }
        let detailed_drop = self.detailed.len().saturating_sub(OUTPUT_HISTORY_LIMIT);
        let compact_drop = self.compact.len().saturating_sub(OUTPUT_HISTORY_LIMIT);
        self.detailed.drain(..detailed_drop);
        self.compact.drain(..compact_drop);
        if self.show_details {
            detailed_drop
        } else {
            compact_drop
        }
    }
}

fn is_compact_output(raw: &str) -> bool {
    let message = raw.trim();
    output_line_severity(message) != StepSeverity::None
        || (message.starts_with("===") && message.ends_with("==="))
        || [
            "[*]",
            "[DRY-RUN]",
            "$ ",
            "Install started",
            "Install aborted",
            "setup.sh ",
            "Hyprland Setup TUI",
            "Keys:",
            "Use Arrow",
        ]
        .iter()
        .any(|prefix| message.starts_with(prefix))
}

#[derive(Default)]
struct OutputViewport {
    area: Rect,
    body: Rect,
    scrollbar: Rect,
    follow_button: Rect,
    mode_button: Rect,
    total_rows: usize,
    focused: bool,
    dragging: bool,
}

struct AppState {
    list_state: ListState,
    logs: OutputLog,
    last_tick: Instant,
    scroll: usize,
    follow_tail: bool,
    log_viewport_lines: usize,
    output: OutputViewport,
    rx: Receiver<String>,
    tx: Sender<String>,
    setup_script: Option<PathBuf>,
    logfile_path: PathBuf,
    ui_mode: UiMode,
    preflight: PreflightConfig,
    preflight_focus: PreflightField,
    editing: bool,
    edit_buffer: String,
    edit_kind: EditKind,
    // Monitor wizard state
    mw_monitors: Vec<MonitorInfo>,
    mw_selected_monitor: usize,
    mw_selected_mode: usize,
    mw_selected_scale: usize,
    mw_active_col: u8,
    mw_buffer: String,
    theme: Theme,
    child: Option<std::process::Child>,
    install_started_at: Option<Instant>,
    // Live sections parsed from setup.sh output
    sections: Vec<SetupSection>,
    planned_section_count: usize,
    current_section: Option<usize>,
    // Packages data and selections
    pacman_cats: Vec<(String, Vec<String>)>,
    aur_cats: Vec<(String, Vec<String>)>,
    pacman_sel_map: BTreeMap<String, bool>,
    aur_sel_map: BTreeMap<String, bool>,
    ms_cursor: usize,
    // Right-pane focus and cursor for live category filter in package selector
    ms_focus_right: bool,
    ms_cursor_filter: usize,
    // Optional category filters (None = all). When Some, only listed categories are shown. (kept for backward-compat / future persistence)
    #[allow(dead_code)]
    pacman_filter_cats: Option<HashSet<String>>,
    #[allow(dead_code)]
    aur_filter_cats: Option<HashSet<String>>,
    // Working sets for live category filter in package selector
    pacman_filter_working: HashSet<String>,
    aur_filter_working: HashSet<String>,
    // User-added packages and their resolved source
    user_added: Vec<String>,
    user_added_src: HashMap<String, String>, // name -> "pacman" | "aur"
    // Package registry and derived selection state
    package_registry: Option<PackagesRoot>,
    package_load_error: Option<String>,
    role_selection: Option<RoleSelection>,
    application_cursor: usize,
    role_cursor: usize,
    required_pacman: BTreeSet<String>,
    required_aur: BTreeSet<String>,
    // Package descriptions loaded from packages.json
    pkg_descs: HashMap<String, String>,
    // Generic lines for warning popups (e.g., Add Packages validation)
    warning_lines: Vec<String>,
    // Generic info popup content
    info_title: String,
    info_lines: Vec<String>,
    // Monitor wizard availability (based on installed tools / sysfs)
    monitor_setup_available: bool,
    // If true, Add Packages editor acts as append-only (opened via Enter)
    add_packages_append_mode: bool,
}

impl AppState {
    fn new(rx: Receiver<String>, tx: Sender<String>, setup_script: Option<PathBuf>) -> Self {
        let mut list_state = ListState::default();
        list_state.select(Some(0));
        let default_wallpaper = guess_default_wallpaper_dir(&setup_script)
            .and_then(|p| {
                std::fs::canonicalize(&p)
                    .ok()
                    .map(|abs| abs.display().to_string())
            })
            .unwrap_or_else(|| "./Wallpaper".to_string());
        let logfile_path = std::env::var("HYPRLAND_SETUP_LOG")
            .map(PathBuf::from)
            .unwrap_or_else(|_| {
                let mut p = dirs::home_dir().unwrap_or_else(|| PathBuf::from("."));
                p.push("Hyprland-Setup.log");
                p
            });
        // Preload sections so they are visible from the start
        let sections_init: Vec<SetupSection> = if let Some(p) = &setup_script {
            preload_sections_from_script(p)
        } else if let Some(p) = resolve_setup_script_path() {
            preload_sections_from_script(&p)
        } else {
            Vec::new()
        };

        let planned_section_count = sections_init.len();

        let mut s = Self {
            list_state,
            logs: OutputLog::default(),
            last_tick: Instant::now(),
            scroll: 0,
            follow_tail: true,
            log_viewport_lines: 1,
            output: OutputViewport::default(),
            rx,
            tx,
            setup_script,
            logfile_path,
            ui_mode: UiMode::Preflight,
            preflight: PreflightConfig {
                prompt_default_yes: true,
                fish_language_choice: 1,
                wallpaper_dir: default_wallpaper,
                monitor_setup_enabled: false,
                monitor_config: String::new(),
                auto_continue_on_warnings: true,
                dry_run: false,
                password: String::new(),
            },
            preflight_focus: PreflightField::EnvPromptDefaultYn,
            editing: false,
            edit_buffer: String::new(),
            edit_kind: EditKind::None,
            mw_monitors: Vec::new(),
            mw_selected_monitor: 0,
            mw_selected_mode: 0,
            mw_selected_scale: 1, // default 1.0
            mw_active_col: 0,
            mw_buffer: String::new(),
            theme: Theme::catppuccin_mocha(),
            child: None,
            install_started_at: None,
            sections: sections_init,
            planned_section_count,
            current_section: None,
            pacman_cats: Vec::new(),
            aur_cats: Vec::new(),
            pacman_sel_map: BTreeMap::new(),
            aur_sel_map: BTreeMap::new(),
            ms_cursor: 0,
            ms_focus_right: false,
            ms_cursor_filter: 0,
            pacman_filter_cats: None,
            aur_filter_cats: None,
            pacman_filter_working: HashSet::new(),
            aur_filter_working: HashSet::new(),
            user_added: Vec::new(),
            user_added_src: HashMap::new(),
            package_registry: None,
            package_load_error: None,
            role_selection: None,
            application_cursor: 0,
            role_cursor: 0,
            required_pacman: BTreeSet::new(),
            required_aur: BTreeSet::new(),
            pkg_descs: HashMap::new(),
            warning_lines: Vec::new(),
            info_title: "Info".to_string(),
            info_lines: Vec::new(),
            monitor_setup_available: true,
            add_packages_append_mode: false,
        };
        match load_package_registry(s.setup_script.as_deref()) {
            Ok(registry) => {
                s.pacman_cats = registry.categorized(PackageSource::Pacman);
                s.aur_cats = registry.categorized(PackageSource::Aur);
                s.pkg_descs = registry.package_descriptions.clone().into_iter().collect();
                s.required_pacman = registry
                    .required_set(PackageSource::Pacman)
                    .into_iter()
                    .collect();
                s.required_aur = registry
                    .required_set(PackageSource::Aur)
                    .into_iter()
                    .collect();
                for (_, packages) in &s.pacman_cats {
                    for package in packages {
                        s.pacman_sel_map.insert(package.clone(), true);
                    }
                }
                for (_, packages) in &s.aur_cats {
                    for package in packages {
                        s.aur_sel_map.insert(package.clone(), true);
                    }
                }
                s.role_selection = Some(RoleSelection::defaults(&registry));
                s.package_registry = Some(registry);
                sync_role_package_selection(&mut s);
                force_required_selected(&mut s);
            }
            Err(error) => {
                s.package_load_error = Some(format!("{error:#}"));
            }
        }
        // Check monitor setup availability early (before Hyprland is installed/running).
        let mut startup_warnings: Vec<String> = Vec::new();

        // General TUI/setup prerequisites
        startup_warnings.extend(startup_prereq_warnings(&s));

        // Monitor wizard prerequisites
        let (avail, mon_lines) = monitor_setup_availability();
        s.monitor_setup_available = avail;
        if !avail {
            s.preflight.monitor_setup_enabled = false;
            startup_warnings.extend(mon_lines);
        }

        if !startup_warnings.is_empty() {
            show_info(&mut s, "Startup checks", startup_warnings);
        }
        s
    }

    #[allow(dead_code)]
    fn selected_index(&self) -> usize {
        self.list_state.selected().unwrap_or(0)
    }

    fn push_log_line(&mut self, line: impl Into<String>) {
        let raw = strip_ansi_sequences(&line.into());
        if raw.trim().is_empty() {
            return;
        }
        // Update live section tracking based on raw (pre-timestamp) line
        update_sections_from_line(self, &raw);
        let ts = Local::now().format("%Y-%m-%d %H:%M:%S");
        let s = format!("[{}] {}", ts, raw);
        let evicted_rows = if !self.follow_tail && self.logs.len() == OUTPUT_HISTORY_LIMIT {
            self.logs.lines().first().map_or(0, |line| {
                wrap_output_line(
                    live_output_line(self.theme, line, self.logs.show_details),
                    self.output.body.width,
                )
                .len()
            })
        } else {
            0
        };
        let dropped = self.logs.push(s.clone(), &raw);
        // Append all output, independent of the selected display mode.
        if let Ok(mut f) = OpenOptions::new()
            .create(true)
            .append(true)
            .open(&self.logfile_path)
        {
            let _ = writeln!(f, "{}", s);
        }
        if !self.follow_tail && dropped > 0 {
            self.scroll = self.scroll.saturating_sub(evicted_rows);
        }
        // The next render computes visual-row offsets using the current viewport width.
    }
}

const OUTPUT_SCROLL_STEP: usize = 8;
const OUTPUT_MESSAGES_PER_TICK: usize = 128;

fn output_tail_start(total_lines: usize, visible_lines: usize) -> usize {
    total_lines.saturating_sub(visible_lines)
}

fn scroll_output_up(
    scroll: &mut usize,
    follow_tail: &mut bool,
    total_lines: usize,
    visible_lines: usize,
) {
    if *follow_tail {
        *scroll = output_tail_start(total_lines, visible_lines);
    }
    *follow_tail = false;
    *scroll = scroll.saturating_sub(OUTPUT_SCROLL_STEP);
}

fn scroll_output_down(scroll: &mut usize, total_lines: usize, visible_lines: usize) {
    let max_scroll = output_tail_start(total_lines, visible_lines);
    *scroll = scroll.saturating_add(OUTPUT_SCROLL_STEP).min(max_scroll);
}

fn resume_output_follow(
    scroll: &mut usize,
    follow_tail: &mut bool,
    total_lines: usize,
    visible_lines: usize,
) {
    *follow_tail = true;
    *scroll = output_tail_start(total_lines, visible_lines);
}

fn sync_output_scroll_after_append(
    scroll: &mut usize,
    follow_tail: bool,
    total_lines: usize,
    visible_lines: usize,
) {
    if follow_tail {
        *scroll = output_tail_start(total_lines, visible_lines);
    }
}

fn scroll_live_output(app: &mut AppState, delta: isize) {
    let end = output_tail_start(app.output.total_rows, app.log_viewport_lines);
    if app.follow_tail {
        app.scroll = end;
    }
    app.follow_tail = false;
    app.output.focused = true;
    app.scroll = app.scroll.saturating_add_signed(delta).min(end);
}

fn follow_live_output(app: &mut AppState) {
    resume_output_follow(
        &mut app.scroll,
        &mut app.follow_tail,
        app.output.total_rows,
        app.log_viewport_lines,
    );
    app.output.dragging = false;
}

fn toggle_live_output_mode(app: &mut AppState) {
    app.logs.show_details = !app.logs.show_details;
    follow_live_output(app);
}

fn mouse_inside(area: Rect, mouse: MouseEvent) -> bool {
    mouse.column >= area.x
        && mouse.column < area.right()
        && mouse.row >= area.y
        && mouse.row < area.bottom()
}

fn seek_output_scrollbar(app: &mut AppState, row: u16) {
    let bar = app.output.scrollbar;
    let track = usize::from(bar.height.saturating_sub(1));
    let position = usize::from(row.saturating_sub(bar.y)).min(track);
    let end = output_tail_start(app.output.total_rows, app.log_viewport_lines);
    app.scroll = position.saturating_mul(end).checked_div(track).unwrap_or(0);
    app.follow_tail = false;
}

fn handle_mouse_event(app: &mut AppState, mouse: MouseEvent) {
    if app.ui_mode != UiMode::Menu || app.editing {
        app.output.dragging = false;
        return;
    }
    match mouse.kind {
        MouseEventKind::Up(_) => app.output.dragging = false,
        MouseEventKind::Drag(MouseButton::Left) if app.output.dragging => {
            seek_output_scrollbar(app, mouse.row);
        }
        MouseEventKind::Down(MouseButton::Left) => {
            app.output.focused = mouse_inside(app.output.area, mouse);
            app.output.dragging = false;
            if mouse_inside(app.output.follow_button, mouse) {
                follow_live_output(app);
            } else if mouse_inside(app.output.mode_button, mouse) {
                toggle_live_output_mode(app);
            } else if mouse_inside(app.output.scrollbar, mouse) {
                app.output.dragging = true;
                seek_output_scrollbar(app, mouse.row);
            }
        }
        MouseEventKind::ScrollUp if mouse_inside(app.output.area, mouse) => {
            scroll_live_output(app, -3)
        }
        MouseEventKind::ScrollDown if mouse_inside(app.output.area, mouse) => {
            scroll_live_output(app, 3)
        }
        _ => {}
    }
}

fn drain_output_events(app: &mut AppState) -> usize {
    for count in 0..OUTPUT_MESSAGES_PER_TICK {
        match app.rx.try_recv() {
            Ok(line) => app.push_log_line(line),
            Err(_) => return count,
        }
    }
    OUTPUT_MESSAGES_PER_TICK
}

struct TerminalSession;

impl Drop for TerminalSession {
    fn drop(&mut self) {
        restore_terminal();
    }
}

fn restore_terminal() {
    let _ = disable_raw_mode();
    let _ = execute!(
        io::stdout(),
        DisableMouseCapture,
        LeaveAlternateScreen,
        crossterm::cursor::Show
    );
}

fn main() -> Result<()> {
    let setup_script = resolve_setup_script_path();

    let (tx, rx) = mpsc::channel::<String>();
    let app_tx = tx.clone();

    install_panic_hook();
    enable_raw_mode().context("enable raw mode")?;
    let terminal_session = TerminalSession;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)
        .context("enter interactive terminal")?;
    // (Windows) Avoid duplicate raw mode enabling
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend).context("create terminal")?;

    let mut app = AppState::new(rx, app_tx, setup_script);
    app.push_log_line("Hyprland Setup TUI - ratatui + crossterm");
    app.push_log_line("Use Arrow Up/Down to select, Enter to run");
    app.push_log_line(
        "Keys: click/wheel=scroll output, v=compact/details, PgUp/PgDn=scroll, Home=oldest, End=follow, q=quit",
    );
    if app.setup_script.is_none() {
        app.push_log_line(
            "setup.sh not found automatically. Set $HYPR_SETUP_PATH or run from repo root.",
        );
    }

    let tick_rate = Duration::from_millis(100);

    let res = run_app(&mut terminal, &mut app, tick_rate);

    drop(terminal_session);

    if let Err(e) = res {
        eprintln!("Error: {e:#}");
        std::process::exit(1);
    }
    Ok(())
}

fn run_app<B: ratatui::backend::Backend>(
    terminal: &mut Terminal<B>,
    app: &mut AppState,
    tick_rate: Duration,
) -> Result<()> {
    loop {
        let drained = drain_output_events(app);

        // Keep input responsive between batches and drain queued output before reporting completion.
        if drained < OUTPUT_MESSAGES_PER_TICK
            && let Some(child) = app.child.as_mut()
            && let Ok(Some(status)) = child.try_wait()
        {
            let code = status.code().unwrap_or(-1);
            // Compute elapsed time if timer was started
            let elapsed_msg = if let Some(start) = app.install_started_at.take() {
                let d = start.elapsed();
                format!(" in {}", format_duration(d))
            } else {
                String::new()
            };
            let setup_succeeded = status.success();
            if setup_succeeded {
                app.push_log_line(format!(
                    "setup.sh finished successfully (exit {code}){}",
                    elapsed_msg
                ));
            } else {
                app.push_log_line(format!("setup.sh exited with status {code}{}", elapsed_msg));
            }
            // Preserve a user-selected scroll position when the process ends.
            // Mark the final section as done when the process ends
            if let Some(idx) = app.current_section.take()
                && let Some(sec) = app.sections.get_mut(idx)
            {
                sec.done = true;
            }
            app.child = None;
            app.ui_mode = UiMode::Menu;
            if setup_succeeded {
                app.editing = true;
                app.edit_kind = EditKind::ConfirmReboot;
            } else {
                app.editing = false;
                app.edit_kind = EditKind::None;
            }
        }

        terminal.draw(|f| draw_ui(f, app)).context("draw ui")?;

        let timeout = if drained == OUTPUT_MESSAGES_PER_TICK {
            Duration::ZERO
        } else {
            tick_rate.saturating_sub(app.last_tick.elapsed())
        };
        if event::poll(timeout).context("poll events")? {
            match event::read().context("read event")? {
                Event::Key(key) => {
                    // Process only on Press to avoid duplicate triggers from Release/Repeat (Windows)
                    if matches!(key.kind, KeyEventKind::Press) && handle_key_event(app, key)? {
                        break;
                    }
                }
                Event::Mouse(mouse) => handle_mouse_event(app, mouse),
                Event::FocusLost => app.output.dragging = false,
                Event::Resize(_, _) | Event::FocusGained | Event::Paste(_) => {}
            }
        }

        if app.last_tick.elapsed() >= tick_rate {
            app.last_tick = Instant::now();
        }
    }
    Ok(())
}

fn draw_ui(f: &mut ratatui::Frame, app: &mut AppState) {
    let area = f.area();

    // Background fill
    let bg = Block::default()
        .borders(Borders::NONE)
        .style(Style::default().bg(app.theme.base));
    f.render_widget(bg, area);

    match app.ui_mode {
        UiMode::Menu => draw_menu_ui(f, app, area),
        UiMode::Preflight => {
            app.output = OutputViewport::default();
            draw_preflight_ui(f, app, area);
        }
    }
    draw_completion_popup(f, app, area);
}

const SPINNER_FRAME_MS: u128 = 150;
const SPINNER_FRAMES: [&str; 4] = ["|", "/", "-", "\\"];

fn spinner_frame(elapsed: Duration) -> &'static str {
    let index = (elapsed.as_millis() / SPINNER_FRAME_MS) as usize % SPINNER_FRAMES.len();
    SPINNER_FRAMES[index]
}

fn installation_step_progress(
    sections: &[SetupSection],
    planned_section_count: usize,
) -> (usize, usize) {
    let completed = sections
        .iter()
        .take(planned_section_count)
        .filter(|section| section.done)
        .count();
    (completed, planned_section_count)
}

fn installation_percent(completed: usize, total: usize) -> u16 {
    completed
        .min(total)
        .saturating_mul(100)
        .checked_div(total)
        .unwrap_or(0) as u16
}

fn ascii_progress_bar(completed: usize, total: usize, width: usize) -> String {
    if width == 0 {
        return "[]".to_string();
    }

    let filled = completed
        .min(total)
        .saturating_mul(width)
        .checked_div(total)
        .unwrap_or(0);
    let complete = total > 0 && completed >= total;
    let mut bar = String::with_capacity(width + 2);
    bar.push('[');
    for index in 0..width {
        let symbol = if index < filled {
            '='
        } else if !complete && index == filled {
            '>'
        } else {
            '-'
        };
        bar.push(symbol);
    }
    bar.push(']');
    bar
}

fn setup_section_style(theme: Theme, section: &SetupSection, is_current: bool) -> Style {
    let color = match section.severity {
        StepSeverity::Error => Color::Red,
        // Use terminal palette colors here: Linux virtual consoles may ignore RGB colors.
        StepSeverity::Warning => Color::Yellow,
        StepSeverity::None if is_current => Color::Blue,
        StepSeverity::None if section.done => Color::Green,
        StepSeverity::None => theme.text,
    };
    let style = Style::default().fg(color);
    if is_current {
        style.add_modifier(Modifier::BOLD)
    } else {
        style
    }
}

fn setup_section_marker(section: &SetupSection, is_current: bool) -> &'static str {
    if is_current {
        ">"
    } else if !section.done {
        " "
    } else {
        match section.severity {
            StepSeverity::None => "x",
            StepSeverity::Warning => "!",
            StepSeverity::Error => "X",
        }
    }
}

fn timestamp_prefix_end(line: &str) -> Option<usize> {
    let bytes = line.as_bytes();
    if bytes.len() >= 22
        && bytes[0] == b'['
        && bytes[5] == b'-'
        && bytes[8] == b'-'
        && bytes[11] == b' '
        && bytes[14] == b':'
        && bytes[17] == b':'
        && bytes[20] == b']'
        && bytes[21] == b' '
    {
        Some(22)
    } else {
        None
    }
}

fn output_line_severity(line: &str) -> StepSeverity {
    let clean = strip_ansi_sequences(line);
    let message = timestamp_prefix_end(&clean)
        .and_then(|end| clean.get(end..))
        .unwrap_or(&clean)
        .trim();
    let lower = message.to_lowercase();

    if lower.contains("[error]")
        || lower.contains("error:")
        || lower.contains("fehler:")
        || lower.starts_with("failed ")
        || lower.starts_with("failed:")
        || lower.contains("fehlgeschlagen")
        || lower.starts_with("fatal:")
        || lower.starts_with("x [")
        || lower.starts_with("✗ [")
        || lower.starts_with("hard failures (")
        || lower.starts_with("setup.sh exited with status")
    {
        StepSeverity::Error
    } else if lower.contains("[!]")
        || lower.contains("[warning]")
        || lower.contains("warning:")
        || lower.contains("warnung:")
        || lower.starts_with("! [")
        || lower.starts_with("○ [")
        || lower.starts_with("o [")
        || lower.starts_with("soft errors (")
        || lower.starts_with("skipped steps (")
    {
        StepSeverity::Warning
    } else {
        StepSeverity::None
    }
}

fn live_output_line(theme: Theme, stored_line: &str, show_details: bool) -> Line<'static> {
    let clean = strip_ansi_sequences(stored_line);
    let severity = output_line_severity(&clean);
    let message_style = match severity {
        StepSeverity::Error => Style::default().fg(Color::Red).add_modifier(Modifier::BOLD),
        StepSeverity::Warning => Style::default()
            .fg(Color::Yellow)
            .add_modifier(Modifier::BOLD),
        StepSeverity::None => Style::default().fg(theme.subtext0),
    };

    if let Some(end) = timestamp_prefix_end(&clean) {
        if !show_details {
            let message = clean[end..].trim();
            let message = if message.starts_with("===") && message.ends_with("===") {
                message.trim_matches('=').trim()
            } else {
                message
            };
            return Line::from(Span::styled(message.to_string(), message_style));
        }
        Line::from(vec![
            Span::styled(
                clean[..end].to_string(),
                Style::default().fg(Color::DarkGray),
            ),
            Span::styled(clean[end..].to_string(), message_style),
        ])
    } else {
        Line::from(Span::styled(clean, message_style))
    }
}

fn wrap_output_line(line: Line<'static>, width: u16) -> Vec<Line<'static>> {
    if width == 0 {
        return Vec::new();
    }
    let style = line.style;
    let mut rows = Vec::new();
    let mut row = Line::default().style(style);
    let mut row_width = 0;
    for span in line.spans {
        let content = span.content.as_ref();
        let mut start = 0;
        for (index, ch) in content.char_indices() {
            let glyph_width = Span::raw(&content[index..index + ch.len_utf8()]).width();
            let newline = ch == '\n';
            if newline || (row_width > 0 && row_width + glyph_width > usize::from(width)) {
                if start < index {
                    row.spans
                        .push(Span::styled(content[start..index].to_string(), span.style));
                }
                rows.push(std::mem::replace(&mut row, Line::default().style(style)));
                row_width = 0;
                start = if newline {
                    index + ch.len_utf8()
                } else {
                    index
                };
            }
            if !newline {
                row_width += glyph_width;
            }
        }
        if start < content.len() {
            row.spans
                .push(Span::styled(content[start..].to_string(), span.style));
        }
    }
    rows.push(row);
    rows
}

fn output_scrollbar_thumb(total: usize, visible: usize, height: u16, scroll: usize) -> (u16, u16) {
    if height == 0 {
        return (0, 0);
    }
    let length = if total <= visible {
        usize::from(height)
    } else {
        (usize::from(height).saturating_mul(visible) / total).max(1)
    }
    .min(usize::from(height));
    let end = output_tail_start(total, visible);
    let offset = scroll
        .min(end)
        .saturating_mul(usize::from(height) - length)
        .checked_div(end)
        .unwrap_or(0);
    (offset as u16, length as u16)
}

fn draw_output_panel(f: &mut ratatui::Frame, app: &mut AppState, area: Rect) {
    let mode = if app.logs.show_details {
        "detailed"
    } else {
        "compact"
    };
    let focus = if app.output.focused { " [focused]" } else { "" };
    let block = Block::default()
        .title(format!("Output: {mode}{focus}"))
        .borders(Borders::ALL)
        .style(
            Style::default()
                .bg(app.theme.surface0)
                .fg(app.theme.subtext0),
        )
        .border_style(Style::default().fg(if app.output.focused {
            app.theme.blue
        } else {
            app.theme.surface1
        }));
    let inner = block.inner(area);
    f.render_widget(block, area);
    let toolbar_height = inner.height.min(1);
    let toolbar = Rect {
        height: toolbar_height,
        ..inner
    };
    let body = Rect {
        x: inner.x,
        y: inner.y + toolbar_height,
        width: inner.width.saturating_sub(1),
        height: inner.height.saturating_sub(toolbar_height),
    };
    app.output.area = area;
    app.output.body = body;
    app.output.scrollbar = Rect {
        x: body.right(),
        width: inner.width.min(1),
        ..body
    };
    app.output.follow_button = Rect {
        width: inner.width.min(8),
        ..toolbar
    };
    let mode_offset = inner.width.min(9);
    app.output.mode_button = Rect {
        x: inner.x + mode_offset,
        width: inner.width.saturating_sub(mode_offset).min(9),
        ..toolbar
    };

    let rendered: Vec<Line> = app
        .logs
        .lines()
        .iter()
        .flat_map(|line| {
            wrap_output_line(
                live_output_line(app.theme, line, app.logs.show_details),
                body.width,
            )
        })
        .collect();
    app.output.total_rows = rendered.len();
    app.log_viewport_lines = usize::from(body.height);
    sync_output_scroll_after_append(
        &mut app.scroll,
        app.follow_tail,
        rendered.len(),
        app.log_viewport_lines,
    );
    app.scroll = app
        .scroll
        .min(output_tail_start(rendered.len(), app.log_viewport_lines));
    let end = app
        .scroll
        .saturating_add(app.log_viewport_lines)
        .min(rendered.len());
    f.render_widget(Paragraph::new(rendered[app.scroll..end].to_vec()), body);

    let button_style = Style::default()
        .fg(app.theme.blue)
        .add_modifier(Modifier::BOLD);
    f.render_widget(
        Paragraph::new(Line::from(vec![
            Span::styled(
                "[Follow]",
                if app.follow_tail {
                    button_style.add_modifier(Modifier::REVERSED)
                } else {
                    button_style
                },
            ),
            Span::raw(" "),
            Span::styled(
                if app.logs.show_details {
                    "[Compact]"
                } else {
                    "[Details]"
                },
                button_style,
            ),
            Span::raw(format!(
                "  {} {end}/{}",
                if app.follow_tail { "Live" } else { "Paused" },
                rendered.len()
            )),
        ])),
        toolbar,
    );

    let (thumb_start, thumb_length) = output_scrollbar_thumb(
        rendered.len(),
        app.log_viewport_lines,
        body.height,
        app.scroll,
    );
    let track: Vec<Line> = (0..body.height)
        .map(|index| {
            let in_thumb = index >= thumb_start && index < thumb_start + thumb_length;
            Line::from(Span::styled(
                if in_thumb { "█" } else { "│" },
                Style::default().fg(if in_thumb {
                    app.theme.blue
                } else {
                    app.theme.surface1
                }),
            ))
        })
        .collect();
    f.render_widget(Paragraph::new(track), app.output.scrollbar);
}

fn draw_menu_ui(f: &mut ratatui::Frame, app: &mut AppState, area: Rect) {
    // Split vertically to create a footer for keybind help
    let vchunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Min(1), Constraint::Length(5)])
        .split(area);

    let chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(35), Constraint::Percentage(65)])
        .split(vchunks[0]);

    // Left pane shows either action or live sections when running
    let left_block = Block::default()
        .title("Hyprland Setup Actions")
        .borders(Borders::ALL)
        .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
        .border_style(Style::default().fg(app.theme.mauve));
    // Draw outer block first
    f.render_widget(left_block, chunks[0]);
    // Compute inner area (inside the border) and split to reserve a legend row at the bottom
    let left_inner = Rect {
        x: chunks[0].x + 1,
        y: chunks[0].y + 1,
        width: chunks[0].width.saturating_sub(2),
        height: chunks[0].height.saturating_sub(2),
    };
    let left_chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Min(1), Constraint::Length(2)])
        .split(left_inner);

    if !app.sections.is_empty() {
        let mut lines: Vec<Line> = Vec::new();
        for (idx, section) in app.sections.iter().enumerate() {
            let is_current = Some(idx) == app.current_section;
            let style = setup_section_style(app.theme, section, is_current);
            let marker = setup_section_marker(section, is_current);
            lines.push(Line::from(Span::styled(
                format!("[{marker}] {}", section.title),
                style,
            )));
        }
        let left_widget = Paragraph::new(Text::from(lines));
        f.render_widget(left_widget, left_chunks[0]);
    } else {
        let items: Vec<ListItem> = vec![ListItem::new(Line::from(Span::styled(
            "Run Hyprland setup",
            Style::default().fg(app.theme.text),
        )))];
        let menu = List::new(items)
            .highlight_style(
                Style::default()
                    .fg(app.theme.blue)
                    .add_modifier(Modifier::BOLD),
            )
            .highlight_symbol("▶ ");
        // Use List for selection when idle
        f.render_stateful_widget(menu, left_chunks[0], &mut app.list_state);
    }
    // Legend row at bottom of the Actions pane
    let legend = Paragraph::new(Text::from(vec![Line::from(vec![
        Span::styled("Legend: ", Style::default().fg(app.theme.subtext0)),
        Span::styled("> Current", Style::default().fg(Color::Blue)),
        Span::raw("  "),
        Span::styled("x Done", Style::default().fg(Color::Green)),
        Span::raw("  "),
        Span::styled("! Warning", Style::default().fg(Color::Yellow)),
        Span::raw("  "),
        Span::styled("X Error", Style::default().fg(Color::Red)),
    ])]))
    .style(Style::default().fg(app.theme.subtext0));
    f.render_widget(legend, left_chunks[1]);

    let install_running = app.child.is_some();
    let right_constraints = if install_running {
        vec![
            Constraint::Length(3),
            Constraint::Min(1),
            Constraint::Length(3),
        ]
    } else {
        vec![Constraint::Length(3), Constraint::Min(1)]
    };
    let right_chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints(right_constraints)
        .split(chunks[1]);

    let header = Paragraph::new(Line::from(vec![
        Span::styled("Full log: ", Style::default().fg(app.theme.yellow)),
        Span::raw(app.logfile_path.display().to_string()),
    ]))
    .block(
        Block::default()
            .title("Info")
            .borders(Borders::ALL)
            .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
            .border_style(Style::default().fg(app.theme.mauve)),
    )
    .wrap(Wrap { trim: false });
    f.render_widget(header, right_chunks[0]);

    draw_output_panel(f, app, right_chunks[1]);

    if install_running {
        let progress_area = right_chunks[2];
        let elapsed = app
            .install_started_at
            .as_ref()
            .map(Instant::elapsed)
            .unwrap_or_default();
        let (completed, total) =
            installation_step_progress(&app.sections, app.planned_section_count);
        let percent = installation_percent(completed, total);
        // The ASCII bar and reverse-video status remain visible on a 16-color Linux TTY.
        let bar_width = usize::from(progress_area.width)
            .saturating_sub(48)
            .clamp(8, 32);
        let bar = ascii_progress_bar(completed, total, bar_width);
        let progress_label = if total == 0 {
            format!(
                "{bar} progress unavailable  elapsed {}",
                format_duration(elapsed)
            )
        } else {
            format!(
                "{bar} {percent:>3}% ({completed}/{total} steps)  elapsed {}",
                format_duration(elapsed)
            )
        };
        let progress = Paragraph::new(Line::from(vec![
            Span::styled(
                format!(" RUNNING {} ", spinner_frame(elapsed)),
                Style::default()
                    .fg(app.theme.text)
                    .add_modifier(Modifier::BOLD)
                    .add_modifier(Modifier::REVERSED),
            ),
            Span::raw(" "),
            Span::styled(progress_label, Style::default().fg(app.theme.text)),
        ]))
        .block(
            Block::default()
                .title("Installation progress")
                .borders(Borders::ALL)
                .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
                .border_style(Style::default().fg(app.theme.mauve)),
        );
        f.render_widget(progress, progress_area);
    }

    // Footer with keybind help
    let footer = Paragraph::new(Text::from(vec![
        Line::from("Click output: focus   Wheel: scroll   Drag right scrollbar: seek   ↑/↓: scroll focused output"),
        Line::from("PgUp/PgDn: scroll   Home: oldest   End/[Follow]: live   v/[Details]: change view"),
        Line::from("Esc: unfocus   Enter: preflight when unfocused   c: clear   k: kill   q: quit"),
    ]))
    .block(
        Block::default()
            .borders(Borders::ALL)
            .style(
                Style::default()
                    .bg(app.theme.surface0)
                    .fg(app.theme.subtext0),
            )
            .border_style(Style::default().fg(app.theme.surface1)),
    );
    f.render_widget(footer, vchunks[1]);
}

fn preflight_row_style(theme: Theme, selected: bool) -> Style {
    if selected {
        // Reverse video remains visible when the Linux console ignores RGB colors.
        Style::default()
            .fg(theme.blue)
            .add_modifier(Modifier::BOLD)
            .add_modifier(Modifier::REVERSED)
    } else {
        Style::default().fg(theme.text)
    }
}

fn role_selection_summary(app: &AppState, role_name: &str) -> String {
    let Some(selection) = app.role_selection.as_ref() else {
        return "[!] unavailable".to_string();
    };
    let Some(members) = selection.selected_packages(role_name) else {
        return "[!] unavailable".to_string();
    };
    if members.is_empty() {
        return "<none>".to_string();
    }
    let primary = selection.selected_package(role_name);
    members
        .iter()
        .map(|package| {
            if primary == Some(package.as_str()) {
                format!("{package} (primary)")
            } else {
                package.clone()
            }
        })
        .collect::<Vec<_>>()
        .join(", ")
}

fn application_type_description(role: &str) -> &'static str {
    match role {
        "browser" => {
            "Opens websites and web apps. The primary browser is used by this setup's shortcuts."
        }
        "shell" => {
            "Interprets commands inside a terminal. The primary choice becomes your login shell."
        }
        "terminal" => {
            "Provides the window for shells and text-based apps; separate from the shell itself."
        }
        "notifications" => {
            "Displays desktop alerts. Some providers also offer history and do-not-disturb controls."
        }
        "tui_editor" => {
            "Edits text and code inside a terminal. The primary choice supplies EDITOR and VISUAL."
        }
        "gui_editor" => {
            "Edits text and code in a graphical window. Optional; None uses the terminal editor for editor shortcuts."
        }
        "bar" => "Displays desktop status, workspaces and controls, usually along a screen edge.",
        "dock" => {
            "Provides an optional strip of pinned or running apps for launching and switching windows."
        }
        "calendar" => {
            "Views and manages dates, appointments and tasks through the desktop calendar action."
        }
        "bluetooth" => {
            "Pairs and manages Bluetooth devices. GUI and terminal choices use the same BlueZ backend."
        }
        "network" => "Connects to networks and edits connection settings through NetworkManager.",
        "audio" => {
            "Controls sound volume and devices. Stream mixers manage apps; ALSA mixers manage hardware."
        }
        "launcher" => {
            "Searches for and starts apps from a keyboard menu, without opening a terminal first."
        }
        "agent" => {
            "Installs optional terminal coding agents from approved official scripts. Choose one primary for troubleshooting integration."
        }
        _ => "Select the applications used for this desktop role.",
    }
}

fn wrap_choice_description(text: &str, width: u16) -> Vec<String> {
    if width == 0 {
        return Vec::new();
    }
    let mut lines = Vec::new();
    let mut line = String::new();
    for word in text.split_whitespace() {
        if !line.is_empty()
            && Line::from(line.as_str()).width() + 1 + Line::from(word).width() > width as usize
        {
            lines.push(std::mem::take(&mut line));
        }
        if !line.is_empty() {
            line.push(' ');
        }
        for ch in word.chars() {
            if !line.is_empty()
                && Line::from(line.as_str()).width() + Line::from(ch.to_string()).width()
                    > width as usize
            {
                lines.push(std::mem::take(&mut line));
            }
            line.push(ch);
        }
    }
    if !line.is_empty() {
        lines.push(line);
    }
    lines
}

fn choice_popup_width(area: Rect) -> u16 {
    area.width.saturating_sub(4).max(50).min(area.width)
}

fn choice_popup_layout(area: Rect, row_counts: [usize; 3], tallest_item: u16) -> (Rect, [Rect; 3]) {
    let width = choice_popup_width(area);
    let height = (row_counts.iter().sum::<usize>() + 2).min(area.height as usize) as u16;
    let popup = Rect {
        x: area.x + area.width.saturating_sub(width) / 2,
        y: area.y + area.height.saturating_sub(height) / 2,
        width,
        height,
    };
    let inner = Block::default().borders(Borders::ALL).inner(popup);
    // On short screens, keep a complete highlighted item before allocating help rows.
    let list_min = tallest_item.min(inner.height);
    let spare = inner.height.saturating_sub(list_min) as usize;
    let footer_height = row_counts[2].min(spare);
    let intro_height = row_counts[0].min(spare.saturating_sub(footer_height));
    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(intro_height as u16),
            Constraint::Min(list_min),
            Constraint::Length(footer_height as u16),
        ])
        .split(inner);
    (popup, [rows[0], rows[1], rows[2]])
}

fn draw_applications_menu(f: &mut ratatui::Frame, app: &AppState, area: Rect) {
    let width = choice_popup_width(area).saturating_sub(2);
    let role_name = selected_application_role(app).unwrap_or("browser");
    let detail_lines = wrap_choice_description(application_type_description(role_name), width);
    let detail_height = ROLE_ORDER
        .iter()
        .map(|role| wrap_choice_description(application_type_description(role), width).len())
        .max()
        .unwrap_or(0);
    let (popup, rows) = choice_popup_layout(area, [1, ROLE_ORDER.len(), detail_height + 1], 1);
    let block = Block::default()
        .title("Applications")
        .borders(Borders::ALL)
        .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
        .border_style(Style::default().fg(app.theme.mauve));
    f.render_widget(Clear, popup);
    f.render_widget(block, popup);
    f.render_widget(
        Paragraph::new("↑/↓: select group   Enter: open   Esc/q: back")
            .style(Style::default().fg(app.theme.subtext0)),
        rows[0],
    );
    let items: Vec<ListItem> = ROLE_ORDER
        .iter()
        .map(|role_name| {
            let label = app
                .package_registry
                .as_ref()
                .and_then(|registry| registry.roles.get(*role_name))
                .map(|role| role.label.as_str())
                .unwrap_or(role_name);
            ListItem::new(format!(
                "{label:<16} {}",
                role_selection_summary(app, role_name)
            ))
        })
        .collect();
    let mut state = ListState::default();
    state.select(Some(app.application_cursor));
    f.render_stateful_widget(
        List::new(items)
            .highlight_style(
                Style::default()
                    .fg(app.theme.blue)
                    .add_modifier(Modifier::BOLD),
            )
            .highlight_symbol("▶ "),
        rows[1],
        &mut state,
    );
    let mut details = vec![Line::from(format!(
        "Group {}/{} | ↑/↓ scroll",
        app.application_cursor + 1,
        ROLE_ORDER.len()
    ))];
    details.extend(detail_lines.into_iter().map(Line::from));
    f.render_widget(
        Paragraph::new(details).style(Style::default().fg(app.theme.subtext0)),
        rows[2],
    );
}

fn role_choice_column_widths(area: Rect) -> [u16; 2] {
    // Account for both frames, the selection marker and the column gap.
    let available = choice_popup_width(area).saturating_sub(8);
    let name = (available / 3).clamp(22, 36).min(available / 2);
    [name, available.saturating_sub(name)]
}

fn draw_role_menu(f: &mut ratatui::Frame, app: &AppState, area: Rect) {
    let Some(role_name) = selected_application_role(app) else {
        return;
    };
    let Some(registry) = app.package_registry.as_ref() else {
        return;
    };
    let role = &registry.roles[role_name];
    let selected = app
        .role_selection
        .as_ref()
        .and_then(|s| s.selected_packages(role_name));
    let primary = app
        .role_selection
        .as_ref()
        .and_then(|s| s.selected_package(role_name));
    let inner_width = choice_popup_width(area).saturating_sub(2);
    let intro = wrap_choice_description(
        application_type_description(role_name),
        inner_width.saturating_sub(4),
    );
    let [name_width, description_width] = role_choice_column_widths(area);
    let mut items = Vec::new();
    let mut total_rows = 0;
    let mut tallest_item = 1;
    let mut add_choice = |name: String, description: &str| {
        let name_lines = wrap_choice_description(&name, name_width);
        let description_lines = wrap_choice_description(description, description_width);
        let height = name_lines.len().max(description_lines.len()).max(1);
        total_rows += height;
        tallest_item = tallest_item.max(height as u16);
        items.push(
            Row::new(vec![
                Cell::from(Text::from(
                    name_lines.into_iter().map(Line::from).collect::<Vec<_>>(),
                )),
                Cell::from(Text::from(
                    description_lines
                        .into_iter()
                        .map(Line::from)
                        .collect::<Vec<_>>(),
                )),
            ])
            .height(height as u16),
        );
    };
    if !role.required {
        let marker = if selected.is_some_and(BTreeSet::is_empty) {
            "[*]"
        } else {
            "[ ]"
        };
        let description = match role_name {
            "gui_editor" => {
                "Skip GUI editors; editor shortcuts use the primary terminal editor. No editor is autostarted."
            }
            "agent" => {
                "Do not install or integrate a coding agent. Existing agent installations are not removed."
            }
            _ => "Do not start a dock. The selected bar remains enabled.",
        };
        add_choice(format!("{marker} None"), description);
    }
    for option in &role.options {
        let marker = if primary == Some(option.package.as_str()) {
            "[*]"
        } else if selected.is_some_and(|members| members.contains(&option.package)) {
            "[x]"
        } else {
            "[ ]"
        };
        let terminal = if option.terminal { " [TUI]" } else { "" };
        let name = format!(
            "{marker} {} [{}]{terminal}",
            option.package,
            option.source.as_str()
        );
        add_choice(
            name,
            app.pkg_descs
                .get(&option.package)
                .map(String::as_str)
                .unwrap_or("No description available."),
        );
    }
    let count = items.len();
    let available_height = area.height.saturating_sub(2);
    // A short terminal may need an unframed table to keep one complete row readable.
    let framed_table = available_height >= tallest_item.saturating_add(4);
    let table_overhead = if framed_table { 3 } else { 1 };
    let minimum_table_height = tallest_item.saturating_add(table_overhead);
    let framed_intro_height = intro.len() + 3; // two borders and a blank separator row
    let intro_height = if available_height.saturating_sub(minimum_table_height + 2) as usize
        >= framed_intro_height
    {
        framed_intro_height
    } else {
        0
    };
    let (popup, rows) = choice_popup_layout(
        area,
        [intro_height, total_rows + table_overhead as usize, 2],
        minimum_table_height,
    );
    let cardinality = match role.selection {
        SelectionKind::Single => "single choice",
        SelectionKind::Multiple => "multiple choices",
    };
    let optional = if role.required {
        "required"
    } else {
        "optional"
    };
    let block = Block::default()
        .title(format!("{} — {cardinality}, {optional}", role.label))
        .borders(Borders::ALL)
        .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
        .border_style(Style::default().fg(app.theme.mauve));
    f.render_widget(Clear, popup);
    f.render_widget(block, popup);
    if intro_height > 0 {
        let about = Rect {
            height: rows[0].height.saturating_sub(1),
            ..rows[0]
        };
        let description = Paragraph::new(
            intro
                .into_iter()
                .map(|line| Line::from(format!(" {line}")))
                .collect::<Vec<_>>(),
        )
        .style(Style::default().fg(app.theme.subtext0))
        .block(
            Block::default()
                .title(format!("About {}", role.label))
                .borders(Borders::ALL)
                .border_style(Style::default().fg(app.theme.surface1)),
        );
        f.render_widget(description, about);
    }
    let table_block = if framed_table {
        Block::default().title("Choices").borders(Borders::ALL)
    } else {
        Block::default()
    };
    let mut state = TableState::default();
    state.select(Some(app.role_cursor.min(count.saturating_sub(1))));
    f.render_stateful_widget(
        Table::new(
            items,
            [
                Constraint::Length(name_width),
                Constraint::Length(description_width),
            ],
        )
        .header(
            Row::new(["App", "Description"]).style(
                Style::default()
                    .fg(app.theme.mauve)
                    .add_modifier(Modifier::BOLD),
            ),
        )
        .column_spacing(2)
        .row_highlight_style(
            Style::default()
                .fg(app.theme.blue)
                .add_modifier(Modifier::BOLD),
        )
        .highlight_symbol("▶ ")
        .block(table_block.border_style(Style::default().fg(app.theme.surface1))),
        rows[1],
        &mut state,
    );
    let keys = if role.selection == SelectionKind::Multiple {
        "Space: toggle   p: primary   [*]: primary"
    } else {
        "Space: choose/clear   [*]: selected"
    };
    f.render_widget(
        Paragraph::new(vec![
            Line::from(format!(
                "{}/{} | ↑/↓ scroll | Enter/Esc: back",
                app.role_cursor + 1,
                count
            )),
            Line::from(keys),
        ])
        .style(Style::default().fg(app.theme.subtext0)),
        rows[2],
    );
}

fn draw_preflight_ui(f: &mut ratatui::Frame, app: &mut AppState, area: Rect) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),
            Constraint::Min(5),
            Constraint::Length(3),
        ])
        .split(area);

    let header = Paragraph::new(Text::from(vec![
        Line::from("Preflight – set values, Enter to start"),
        Line::from("Tab/Shift-Tab move  ←/→ change  Space toggle  e edit  q back"),
    ]))
    .block(
        Block::default()
            .title("Preflight")
            .borders(Borders::ALL)
            .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
            .border_style(Style::default().fg(app.theme.mauve)),
    );
    f.render_widget(header, chunks[0]);

    let pf = &app.preflight;
    let mut rows: Vec<Row> = Vec::new();
    let sel = |field: PreflightField| app.preflight_focus == field;
    let mk = |action: &str, name: &str, value: String, selected: bool| {
        let base = preflight_row_style(app.theme, selected);
        let name = if selected {
            format!("> {name}")
        } else {
            format!("  {name}")
        };
        Row::new(vec![
            Cell::from(name).style(base),
            Cell::from(action.to_string()).style(base),
            Cell::from(value).style(base),
        ])
    };

    rows.push(mk(
        "Toggle",
        "Default prompt answer (y/n)",
        if pf.prompt_default_yes { "y" } else { "n" }.to_string(),
        sel(PreflightField::EnvPromptDefaultYn),
    ));
    rows.push(mk(
        "1/2/3",
        "Fish language",
        format!("{} (1=de_CH,2=de_DE,3=en_US)", pf.fish_language_choice),
        sel(PreflightField::EnvFishLanguageChoiceOverride),
    ));
    rows.push(mk(
        "Enter",
        "Applications",
        format!("{} groups", ROLE_ORDER.len()),
        sel(PreflightField::Applications),
    ));
    rows.push(mk(
        "Edit",
        "Wallpaper directory",
        pf.wallpaper_dir.clone(),
        sel(PreflightField::EnvWallpaperDirOverride),
    ));
    rows.push(mk(
        "Toggle",
        "Enable monitor setup",
        if pf.monitor_setup_enabled {
            "true"
        } else {
            "false"
        }
        .to_string(),
        sel(PreflightField::EnvMonitorSetupEnabled),
    ));
    rows.push(mk(
        "Edit",
        "Monitor configuration",
        if pf.monitor_config.is_empty() {
            "<empty>".to_string()
        } else {
            pf.monitor_config.clone()
        },
        sel(PreflightField::EnvMonitorConfig),
    ));
    rows.push(mk(
        "Toggle",
        "Auto-continue on warnings",
        if pf.auto_continue_on_warnings {
            "true"
        } else {
            "false"
        }
        .to_string(),
        sel(PreflightField::EnvAutoContinueOnWarnings),
    ));
    rows.push(mk(
        "Edit/required",
        "Password",
        if pf.password.is_empty() {
            "<empty>".to_string()
        } else {
            "******".to_string()
        },
        sel(PreflightField::Password),
    ));
    // (moved DRY_RUN to the end, right before Start)
    // Buttons to open package selectors
    rows.push(mk(
        "Enter",
        "Select pacman packages",
        format!(
            "{} selected",
            app.pacman_sel_map.values().filter(|v| **v).count()
        ),
        sel(PreflightField::SelectPacman),
    ));
    rows.push(mk(
        "Enter",
        "Select AUR packages",
        format!(
            "{} selected",
            app.aur_sel_map.values().filter(|v| **v).count()
        ),
        sel(PreflightField::SelectAur),
    ));
    rows.push(mk(
        "Edit",
        "Add packages (comma-separated)",
        if app.user_added.is_empty() {
            "<none>".to_string()
        } else {
            app.user_added.join(", ")
        },
        sel(PreflightField::AddPackages),
    ));
    rows.push(mk(
        "Toggle",
        "DRY_RUN (--dry-run)",
        if pf.dry_run { "true" } else { "false" }.to_string(),
        sel(PreflightField::EnvDryRun),
    ));
    rows.push(mk(
        "Enter",
        "Start unattended install",
        package_start_blocker(app)
            .map(|reason| format!("disabled: {reason}"))
            .unwrap_or_default(),
        sel(PreflightField::Start),
    ));

    let table = Table::new(
        rows,
        [
            Constraint::Length(34),
            Constraint::Length(14),
            Constraint::Min(10),
        ],
    )
    .header(Row::new(vec![
        Cell::from("Name").style(Style::default().fg(app.theme.mauve)),
        Cell::from("Action").style(Style::default().fg(app.theme.mauve)),
        Cell::from("Value").style(Style::default().fg(app.theme.mauve)),
    ]))
    .column_spacing(2)
    .block(
        Block::default()
            .title("Values")
            .borders(Borders::ALL)
            .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
            .border_style(Style::default().fg(app.theme.surface1)),
    );
    f.render_widget(table, chunks[1]);

    // Bottom help (when not editing)
    let help_lines: Vec<Line> = vec![
        Line::from(
            "Keys: Tab/Shift-Tab or j/k or ↑/↓ move  ←/→ change  Space toggle  e edit  Enter start  q back",
        ),
        Line::from("MONITOR_CONFIG: name:1920x1080@60:1.0;name2:2560x1440@144:1.25"),
    ];
    let help = Paragraph::new(Text::from(help_lines)).block(
        Block::default()
            .borders(Borders::ALL)
            .style(
                Style::default()
                    .bg(app.theme.surface0)
                    .fg(app.theme.subtext0),
            )
            .border_style(Style::default().fg(app.theme.surface1)),
    );
    f.render_widget(help, chunks[2]);

    // Center popup for editing
    if app.editing && app.edit_kind == EditKind::Text {
        let area_w = area.width as i32;
        let popup_w = (area_w * 3 / 4).max(30) as u16; // 75% width, min 30
        let popup_h = 7u16; // title + input + help
        let popup_x = area.x + (area.width.saturating_sub(popup_w)) / 2;
        let popup_y = area.y + (area.height.saturating_sub(popup_h)) / 2;
        let popup_rect = Rect {
            x: popup_x,
            y: popup_y,
            width: popup_w,
            height: popup_h,
        };

        let field = match app.preflight_focus {
            PreflightField::EnvWallpaperDirOverride => "WALLPAPER_DIR_OVERRIDE",
            PreflightField::EnvMonitorConfig => "MONITOR_CONFIG",
            PreflightField::Password => "PASSWORD",
            PreflightField::AddPackages => "ADD PACKAGES (comma-separated)",
            _ => "",
        };
        let caret = "▏";
        let is_password = matches!(app.preflight_focus, PreflightField::Password);
        let display_value = if is_password {
            "•".repeat(app.edit_buffer.chars().count())
        } else {
            app.edit_buffer.clone()
        };
        let buffer_with_caret = format!("{}{}", display_value, caret);

        // Clear area under popup
        f.render_widget(Clear, popup_rect);

        // Draw popup content
        let popup_block = Block::default()
            .title("Edit value")
            .borders(Borders::ALL)
            .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
            .border_style(Style::default().fg(app.theme.mauve));
        f.render_widget(popup_block, popup_rect);

        // Split popup into lines
        let inner = Rect {
            x: popup_rect.x + 1,
            y: popup_rect.y + 1,
            width: popup_rect.width - 2,
            height: popup_rect.height - 2,
        };
        let inner_chunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints([
                Constraint::Length(1),
                Constraint::Length(3),
                Constraint::Length(1),
            ])
            .split(inner);

        let title = Paragraph::new(Text::from(vec![Line::from(field.to_string())]));
        f.render_widget(title, inner_chunks[0]);

        let input_title = if matches!(app.preflight_focus, PreflightField::Password) {
            "Input (hidden)"
        } else {
            "Input"
        };
        let input = Paragraph::new(Text::from(vec![Line::from(buffer_with_caret)])).block(
            Block::default()
                .title(input_title)
                .borders(Borders::ALL)
                .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
                .border_style(Style::default().fg(app.theme.surface1)),
        );
        f.render_widget(input, inner_chunks[1]);

        let tip = Paragraph::new(Text::from(vec![Line::from(
            "Enter save  Esc cancel  (type to edit, Backspace deletes)",
        )]));
        f.render_widget(tip, inner_chunks[2]);
    } else if app.editing && app.edit_kind == EditKind::MonitorWizard {
        // Dropdown-like wizard to compose MONITOR_CONFIG
        let area_w = area.width as i32;
        let popup_w = (area_w * 4 / 5).max(50) as u16;
        let popup_h = (area.height.saturating_sub(6)).max(12);
        let popup_x = area.x + (area.width.saturating_sub(popup_w)) / 2;
        let popup_y = area.y + (area.height.saturating_sub(popup_h)) / 2;
        let popup_rect = Rect {
            x: popup_x,
            y: popup_y,
            width: popup_w,
            height: popup_h,
        };

        f.render_widget(Clear, popup_rect);
        let popup_block = Block::default()
            .title("Monitor Config Wizard")
            .borders(Borders::ALL)
            .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
            .border_style(Style::default().fg(app.theme.mauve));
        f.render_widget(popup_block, popup_rect);

        let inner = Rect {
            x: popup_rect.x + 1,
            y: popup_rect.y + 1,
            width: popup_rect.width - 2,
            height: popup_rect.height - 2,
        };
        let rows = Layout::default()
            .direction(Direction::Vertical)
            .constraints([
                Constraint::Length(1),
                Constraint::Min(5),
                Constraint::Length(3),
                Constraint::Length(2),
            ])
            .split(inner);

        // Title/help
        let active = match app.mw_active_col {
            0 => "Monitors",
            1 => "Modes",
            _ => "Scale",
        };
        let help_top = Paragraph::new(Text::from(vec![Line::from(format!(
            "Active: {}   Tab switch column  j/k/↑/↓ move  Enter add selection  x remove last  s save  q/Esc cancel",
            active
        ))]));
        f.render_widget(help_top, rows[0]);

        // 3 columns: monitors, modes, scales
        let cols = Layout::default()
            .direction(Direction::Horizontal)
            .constraints([
                Constraint::Percentage(35),
                Constraint::Percentage(45),
                Constraint::Percentage(20),
            ])
            .split(rows[1]);

        // Monitors list
        let mon_items: Vec<ListItem> = app
            .mw_monitors
            .iter()
            .map(|m| ListItem::new(Line::from(m.name.clone())))
            .collect();
        let mut mon_state = ListState::default();
        mon_state.select(Some(
            app.mw_selected_monitor
                .min(app.mw_monitors.len().saturating_sub(1)),
        ));
        let mon_list = List::new(mon_items)
            .highlight_style(
                Style::default()
                    .fg(app.theme.blue)
                    .add_modifier(Modifier::BOLD),
            )
            .highlight_symbol("▶ ")
            .block(
                Block::default()
                    .title("Monitors")
                    .borders(Borders::ALL)
                    .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
                    .border_style(if app.mw_active_col == 0 {
                        Style::default().fg(app.theme.yellow)
                    } else {
                        Style::default().fg(app.theme.surface1)
                    }),
            );
        f.render_stateful_widget(mon_list, cols[0], &mut mon_state);

        // Modes for selected monitor
        let modes: Vec<String> = app
            .mw_monitors
            .get(app.mw_selected_monitor)
            .map(|m| m.modes.clone())
            .unwrap_or_default();
        let mode_items: Vec<ListItem> = modes
            .iter()
            .map(|s| {
                let label = match aspect_ratio_label(s) {
                    Some(r) => format!("{} ({})", s, r),
                    None => s.clone(),
                };
                ListItem::new(Line::from(label))
            })
            .collect();
        let mut mode_state = ListState::default();
        mode_state.select(Some(
            app.mw_selected_mode.min(modes.len().saturating_sub(1)),
        ));
        let mode_list = List::new(mode_items)
            .highlight_style(
                Style::default()
                    .fg(app.theme.blue)
                    .add_modifier(Modifier::BOLD),
            )
            .highlight_symbol("▶ ")
            .block(
                Block::default()
                    .title("Modes")
                    .borders(Borders::ALL)
                    .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
                    .border_style(if app.mw_active_col == 1 {
                        Style::default().fg(app.theme.yellow)
                    } else {
                        Style::default().fg(app.theme.surface1)
                    }),
            );
        f.render_stateful_widget(mode_list, cols[1], &mut mode_state);

        // Scales
        let scale_opts = ["0.75", "1.0", "1.25", "1.5", "2.0"];
        let scale_items: Vec<ListItem> = scale_opts
            .iter()
            .map(|s| ListItem::new(Line::from((*s).to_string())))
            .collect();
        let mut scale_state = ListState::default();
        scale_state.select(Some(
            app.mw_selected_scale
                .min(scale_opts.len().saturating_sub(1)),
        ));
        let scale_list = List::new(scale_items)
            .highlight_style(
                Style::default()
                    .fg(app.theme.blue)
                    .add_modifier(Modifier::BOLD),
            )
            .highlight_symbol("▶ ")
            .block(
                Block::default()
                    .title("Scale")
                    .borders(Borders::ALL)
                    .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
                    .border_style(if app.mw_active_col == 2 {
                        Style::default().fg(app.theme.yellow)
                    } else {
                        Style::default().fg(app.theme.surface1)
                    }),
            );
        f.render_stateful_widget(scale_list, cols[2], &mut scale_state);

        // Current buffer and tips
        let current = Paragraph::new(Text::from(vec![Line::from(format!(
            "Current: {}",
            app.mw_buffer
        ))]))
        .block(
            Block::default()
                .title("Selection")
                .borders(Borders::ALL)
                .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
                .border_style(Style::default().fg(app.theme.surface1)),
        );
        f.render_widget(current, rows[2]);

        let bottom_help = Paragraph::new(Text::from(vec![Line::from(
            "Enter add   s save   x remove last",
        )]))
        .block(
            Block::default().style(
                Style::default()
                    .bg(app.theme.surface0)
                    .fg(app.theme.subtext0),
            ),
        );
        f.render_widget(bottom_help, rows[3]);
    }
    if app.editing
        && matches!(
            app.edit_kind,
            EditKind::SelectApplications | EditKind::SelectRole
        )
    {
        draw_applications_menu(f, app, area);
    }
    if app.editing && app.edit_kind == EditKind::SelectRole {
        draw_role_menu(f, app, area);
    }

    // Package multiselect popups (categorized)
    if app.editing
        && (app.edit_kind == EditKind::SelectPacman || app.edit_kind == EditKind::SelectAur)
    {
        let is_pacman = app.edit_kind == EditKind::SelectPacman;
        let area_w = area.width as i32;
        let popup_w = (area_w * 4 / 5).max(50) as u16;
        let popup_h = (area.height.saturating_sub(6)).max(12);
        let popup_x = area.x + (area.width.saturating_sub(popup_w)) / 2;
        let popup_y = area.y + (area.height.saturating_sub(popup_h)) / 2;
        let popup_rect = Rect {
            x: popup_x,
            y: popup_y,
            width: popup_w,
            height: popup_h,
        };
        f.render_widget(Clear, popup_rect);
        let title = if app.edit_kind == EditKind::SelectPacman {
            "Select pacman packages"
        } else {
            "Select AUR packages"
        };
        let popup_block = Block::default()
            .title(title)
            .borders(Borders::ALL)
            .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
            .border_style(Style::default().fg(app.theme.mauve));
        f.render_widget(popup_block, popup_rect);

        let inner = Rect {
            x: popup_rect.x + 1,
            y: popup_rect.y + 1,
            width: popup_rect.width - 2,
            height: popup_rect.height - 2,
        };
        // Split vertically into help + main + footer
        let rows = Layout::default()
            .direction(Direction::Vertical)
            .constraints([
                Constraint::Length(1),
                Constraint::Min(5),
                Constraint::Length(2),
            ])
            .split(inner);
        // Split main horizontally: left packages, right live category filter
        let cols = Layout::default()
            .direction(Direction::Horizontal)
            .constraints([Constraint::Percentage(60), Constraint::Percentage(40)])
            .split(rows[1]);

        let help = Paragraph::new(Text::from(vec![Line::from("[!] required/locked   Space toggle   a all   n none   Tab switch pane   changes apply live   Enter save   Esc cancel   j/k/↑/↓ move")]))
            .style(Style::default().fg(app.theme.subtext0));
        f.render_widget(help, rows[0]);

        // Prepare right pane: live category filter data and ensure working set initialized
        let mut cats: Vec<String> = if is_pacman {
            app.pacman_cats.iter().map(|(c, _)| c.clone()).collect()
        } else {
            app.aur_cats.iter().map(|(c, _)| c.clone()).collect()
        };
        cats.sort();

        // Build categorized lines into a flat list of (is_header, label, key_opt)
        // label includes package name and a description column
        let mut flat: Vec<(bool, String, Option<String>)> = Vec::new();
        if is_pacman {
            let cat_filter = if app.pacman_filter_working.is_empty() {
                None
            } else {
                Some(&app.pacman_filter_working)
            };
            for (cat, pkgs) in &app.pacman_cats {
                if let Some(cf) = cat_filter
                    && !cf.contains(cat)
                {
                    continue;
                }
                flat.push((true, format!("[{}]", cat), None));
                for p in pkgs {
                    let chosen = *app.pacman_sel_map.get(p).unwrap_or(&false);
                    let mark = if app.required_pacman.contains(p) {
                        "[!]"
                    } else if chosen {
                        "[x]"
                    } else {
                        "[ ]"
                    };
                    let desc = app
                        .pkg_descs
                        .get(p)
                        .cloned()
                        .unwrap_or_else(|| "".to_string());
                    // Two-column layout: name left, desc right; pad name to fixed width
                    let name_col = format!("{} {}", mark, p);
                    let name_width = (popup_rect.width as usize).saturating_sub(6).min(40); // cap name width
                    let padded = if name_col.len() < name_width {
                        format!("{:<width$}", name_col, width = name_width)
                    } else {
                        name_col
                    };
                    flat.push((false, format!("{}  {}", padded, desc), Some(p.clone())));
                }
            }
        } else {
            let cat_filter = if app.aur_filter_working.is_empty() {
                None
            } else {
                Some(&app.aur_filter_working)
            };
            for (cat, pkgs) in &app.aur_cats {
                if let Some(cf) = cat_filter
                    && !cf.contains(cat)
                {
                    continue;
                }
                flat.push((true, format!("[{}]", cat), None));
                for p in pkgs {
                    let chosen = *app.aur_sel_map.get(p).unwrap_or(&false);
                    let mark = if app.required_aur.contains(p) {
                        "[!]"
                    } else if chosen {
                        "[x]"
                    } else {
                        "[ ]"
                    };
                    let desc = app
                        .pkg_descs
                        .get(p)
                        .cloned()
                        .unwrap_or_else(|| "".to_string());
                    let name_col = format!("{} {}", mark, p);
                    let name_width = (popup_rect.width as usize).saturating_sub(6).min(40);
                    let padded = if name_col.len() < name_width {
                        format!("{:<width$}", name_col, width = name_width)
                    } else {
                        name_col
                    };
                    flat.push((false, format!("{}  {}", padded, desc), Some(p.clone())));
                }
            }
        }

        // Create items; highlight only non-headers
        let mut items: Vec<ListItem> = Vec::with_capacity(flat.len());
        for (is_header, label, _) in &flat {
            if *is_header {
                items.push(
                    ListItem::new(Line::from(label.clone()))
                        .style(Style::default().fg(app.theme.yellow)),
                );
            } else {
                items.push(ListItem::new(Line::from(label.clone())));
            }
        }
        let mut state = ListState::default();
        state.select(Some(app.ms_cursor.min(items.len().saturating_sub(1))));
        let list = List::new(items)
            .highlight_style(
                Style::default()
                    .fg(app.theme.blue)
                    .add_modifier(Modifier::BOLD),
            )
            .highlight_symbol("▶ ")
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
                    .border_style(Style::default().fg(if !app.ms_focus_right {
                        app.theme.mauve
                    } else {
                        app.theme.surface1
                    })),
            );
        f.render_stateful_widget(list, cols[0], &mut state);

        // Right pane: live category filter
        let mut filter_items: Vec<ListItem> = Vec::new();
        for c in &cats {
            let mark = if (if is_pacman {
                &app.pacman_filter_working
            } else {
                &app.aur_filter_working
            })
            .contains(c)
            {
                "[x]"
            } else {
                "[ ]"
            };
            filter_items.push(ListItem::new(Line::from(format!("{} {}", mark, c))));
        }
        let mut filter_state = ListState::default();
        filter_state.select(Some(app.ms_cursor_filter.min(cats.len().saturating_sub(1))));
        let filter_title = if is_pacman {
            "Filter pacman categories"
        } else {
            "Filter AUR categories"
        };
        let filter_list = List::new(filter_items)
            .highlight_style(
                Style::default()
                    .fg(app.theme.mauve)
                    .add_modifier(Modifier::BOLD),
            )
            .highlight_symbol("▶ ")
            .block(
                Block::default()
                    .title(filter_title)
                    .borders(Borders::ALL)
                    .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
                    .border_style(Style::default().fg(if app.ms_focus_right {
                        app.theme.mauve
                    } else {
                        app.theme.surface1
                    })),
            );
        f.render_stateful_widget(filter_list, cols[1], &mut filter_state);

        // Footer counts
        let (selected_count, total_count) = if is_pacman {
            let total = app.pacman_sel_map.len();
            let selc = app.pacman_sel_map.values().filter(|v| **v).count();
            (selc, total)
        } else {
            let total = app.aur_sel_map.len();
            let selc = app.aur_sel_map.values().filter(|v| **v).count();
            (selc, total)
        };
        let bottom = Paragraph::new(Text::from(vec![Line::from(format!(
            "Selected: {} / {}",
            selected_count, total_count
        ))]))
        .style(Style::default().fg(app.theme.subtext0));
        f.render_widget(bottom, rows[2]);
    }

    // Category filter popup removed (now part of split-pane in package selector)

    // Simple info popup (dismiss with Enter/Esc)
    if app.editing && app.edit_kind == EditKind::Info {
        let area_w = area.width as i32;
        // Clamp to avoid underflow in `popup_rect.{width,height} - 2` on tiny terminals.
        let desired_w = (area_w * 3 / 5).max(40) as u16;
        let popup_w = if area.width < 4 {
            area.width
        } else {
            desired_w.min(area.width)
        };
        let msg_lines = app.info_lines.len().max(1) as u16;
        let desired_h = msg_lines.saturating_add(4); // title + msg + tip
        let popup_h = if area.height < 4 {
            area.height
        } else {
            desired_h.min(area.height)
        };
        let popup_x = area.x + (area.width.saturating_sub(popup_w)) / 2;
        let popup_y = area.y + (area.height.saturating_sub(popup_h)) / 2;
        let popup_rect = Rect {
            x: popup_x,
            y: popup_y,
            width: popup_w,
            height: popup_h,
        };

        f.render_widget(Clear, popup_rect);
        let popup_block = Block::default()
            .title(app.info_title.clone())
            .borders(Borders::ALL)
            .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
            .border_style(Style::default().fg(app.theme.mauve));
        f.render_widget(popup_block, popup_rect);

        let inner = Rect {
            x: popup_rect.x + 1,
            y: popup_rect.y + 1,
            width: popup_rect.width.saturating_sub(2),
            height: popup_rect.height.saturating_sub(2),
        };
        let msg_h = inner.height.saturating_sub(1);
        let inner_chunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints([Constraint::Length(msg_h), Constraint::Length(1)])
            .split(inner);

        let lines: Vec<Line> = if app.info_lines.is_empty() {
            vec![Line::from("")]
        } else {
            app.info_lines
                .iter()
                .map(|l| Line::from(l.clone()))
                .collect()
        };
        let msg = Paragraph::new(Text::from(lines))
            .style(Style::default().fg(app.theme.text))
            .wrap(Wrap { trim: false });
        f.render_widget(msg, inner_chunks[0]);

        let tip = Paragraph::new(Text::from(vec![Line::from("Press Enter or Esc to close")]))
            .style(Style::default().fg(app.theme.subtext0));
        f.render_widget(tip, inner_chunks[1]);
    }
    // Add Packages validation warning popup
    if app.editing && app.edit_kind == EditKind::AddPackagesWarning {
        let area_w = area.width as i32;
        // Clamp to avoid underflow in `popup_rect.{width,height} - 2` on tiny terminals.
        let desired_w = (area_w * 3 / 5).max(40) as u16;
        let popup_w = if area.width < 4 {
            area.width
        } else {
            desired_w.min(area.width)
        };
        let desired_h = (app.warning_lines.len() as u16).saturating_add(5);
        let popup_h = if area.height < 4 {
            area.height
        } else {
            desired_h.min(area.height)
        };
        let popup_x = area.x + (area.width.saturating_sub(popup_w)) / 2;
        let popup_y = area.y + (area.height.saturating_sub(popup_h)) / 2;
        let popup_rect = Rect {
            x: popup_x,
            y: popup_y,
            width: popup_w,
            height: popup_h,
        };
        f.render_widget(Clear, popup_rect);
        let popup_block = Block::default()
            .title("Package warnings")
            .borders(Borders::ALL)
            .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
            .border_style(Style::default().fg(app.theme.mauve));
        f.render_widget(popup_block, popup_rect);

        let inner = Rect {
            x: popup_rect.x + 1,
            y: popup_rect.y + 1,
            width: popup_rect.width.saturating_sub(2),
            height: popup_rect.height.saturating_sub(2),
        };
        let rows = Layout::default()
            .direction(Direction::Vertical)
            .constraints([
                Constraint::Length(
                    (app.warning_lines.len() as u16).min(inner.height.saturating_sub(2)),
                ),
                Constraint::Length(1),
            ])
            .split(inner);
        let mut lines: Vec<Line> = Vec::new();
        for l in &app.warning_lines {
            lines.push(Line::from(l.clone()));
        }
        let list = Paragraph::new(Text::from(lines)).wrap(Wrap { trim: false });
        f.render_widget(list, rows[0]);
        let tip = Paragraph::new(Text::from(vec![Line::from(
            "Press Enter/Esc to return and edit",
        )]))
        .style(Style::default().fg(app.theme.subtext0));
        f.render_widget(tip, rows[1]);
    }
    // Confirm enable monitor setup popup
    if app.editing && app.edit_kind == EditKind::ConfirmEnableMonitorSetup {
        let area_w = area.width as i32;
        let popup_w = (area_w * 3 / 5).max(40) as u16;
        let popup_h = 6u16;
        let popup_x = area.x + (area.width.saturating_sub(popup_w)) / 2;
        let popup_y = area.y + (area.height.saturating_sub(popup_h)) / 2;
        let popup_rect = Rect {
            x: popup_x,
            y: popup_y,
            width: popup_w,
            height: popup_h,
        };
        f.render_widget(Clear, popup_rect);
        let popup_block = Block::default()
            .title("Enable Monitor Setup?")
            .borders(Borders::ALL)
            .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
            .border_style(Style::default().fg(app.theme.mauve));
        f.render_widget(popup_block, popup_rect);

        let inner = Rect {
            x: popup_rect.x + 1,
            y: popup_rect.y + 1,
            width: popup_rect.width - 2,
            height: popup_rect.height - 2,
        };
        let rows = Layout::default()
            .direction(Direction::Vertical)
            .constraints([Constraint::Length(2), Constraint::Length(2)])
            .split(inner);
        let msg = Paragraph::new(Text::from(vec![Line::from(
            "MONITOR_SETUP_ENABLED has to be set to true, do you want to set to true?",
        )]))
        .style(Style::default().fg(app.theme.text));
        f.render_widget(msg, rows[0]);
        let tip = Paragraph::new(Text::from(vec![Line::from(
            "Press Y/Enter to confirm, N/Esc to cancel",
        )]))
        .style(Style::default().fg(app.theme.subtext0));
        f.render_widget(tip, rows[1]);
    }
    // Confirm start install popup
    if app.editing && app.edit_kind == EditKind::ConfirmStartInstall {
        let area_w = area.width as i32;
        let popup_w = (area_w * 3 / 5).max(40) as u16;
        let popup_h = 6u16;
        let popup_x = area.x + (area.width.saturating_sub(popup_w)) / 2;
        let popup_y = area.y + (area.height.saturating_sub(popup_h)) / 2;
        let popup_rect = Rect {
            x: popup_x,
            y: popup_y,
            width: popup_w,
            height: popup_h,
        };
        f.render_widget(Clear, popup_rect);
        let popup_block = Block::default()
            .title("Start unattended install?")
            .borders(Borders::ALL)
            .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
            .border_style(Style::default().fg(app.theme.mauve));
        f.render_widget(popup_block, popup_rect);

        let inner = Rect {
            x: popup_rect.x + 1,
            y: popup_rect.y + 1,
            width: popup_rect.width - 2,
            height: popup_rect.height - 2,
        };
        let rows = Layout::default()
            .direction(Direction::Vertical)
            .constraints([Constraint::Length(2), Constraint::Length(2)])
            .split(inner);
        let msg = Paragraph::new(Text::from(vec![Line::from(
            "This will run the setup now. Proceed?",
        )]))
        .style(Style::default().fg(app.theme.text));
        f.render_widget(msg, rows[0]);
        let tip = Paragraph::new(Text::from(vec![Line::from(
            "Press Y/Enter to confirm, N/Esc to cancel",
        )]))
        .style(Style::default().fg(app.theme.subtext0));
        f.render_widget(tip, rows[1]);
    }
}

fn draw_completion_popup(f: &mut ratatui::Frame, app: &AppState, area: Rect) {
    if app.editing && app.edit_kind == EditKind::ConfirmReboot {
        let area_w = area.width as i32;
        let popup_w = (area_w * 3 / 5).max(40) as u16;
        let popup_h = 6u16;
        let popup_x = area.x + (area.width.saturating_sub(popup_w)) / 2;
        let popup_y = area.y + (area.height.saturating_sub(popup_h)) / 2;
        let popup_rect = Rect {
            x: popup_x,
            y: popup_y,
            width: popup_w,
            height: popup_h,
        };
        f.render_widget(Clear, popup_rect);
        let popup_block = Block::default()
            .title("Setup Complete")
            .borders(Borders::ALL)
            .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
            .border_style(Style::default().fg(app.theme.mauve));
        f.render_widget(popup_block, popup_rect);

        let inner = Rect {
            x: popup_rect.x + 1,
            y: popup_rect.y + 1,
            width: popup_rect.width - 2,
            height: popup_rect.height - 2,
        };
        let rows = Layout::default()
            .direction(Direction::Vertical)
            .constraints([
                Constraint::Length(2),
                Constraint::Length(2),
                Constraint::Length(1),
            ])
            .split(inner);
        let msg = Paragraph::new(Text::from(vec![Line::from(
            "Do you want to Reboot to finish the Setup?",
        )]))
        .style(Style::default().fg(app.theme.text));
        f.render_widget(msg, rows[0]);
        let tip = Paragraph::new(Text::from(vec![Line::from(
            "Enter/Y: reboot   N/Esc: cancel",
        )]))
        .style(Style::default().fg(app.theme.subtext0));
        f.render_widget(tip, rows[1]);
    }
}

// removed: old line-based preflight rendering helper; replaced by Table-based layout

fn handle_key_event(app: &mut AppState, key: KeyEvent) -> Result<bool> {
    // Completion is modal over either screen, including the live output view.
    if app.editing && app.edit_kind == EditKind::ConfirmReboot {
        return handle_preflight_keys(app, key);
    }
    match app.ui_mode {
        UiMode::Menu => match key.code {
            KeyCode::Char('q') => return Ok(true),
            KeyCode::Enter if !app.output.focused => app.ui_mode = UiMode::Preflight,
            KeyCode::Esc => {
                app.output.focused = false;
                app.output.dragging = false;
            }
            KeyCode::Up if app.output.focused => scroll_live_output(app, -1),
            KeyCode::Down if app.output.focused => scroll_live_output(app, 1),
            KeyCode::PageUp => scroll_live_output(app, -(OUTPUT_SCROLL_STEP as isize)),
            KeyCode::PageDown => scroll_live_output(app, OUTPUT_SCROLL_STEP as isize),
            KeyCode::Home => {
                app.output.focused = true;
                app.follow_tail = false;
                app.scroll = 0;
            }
            KeyCode::End => follow_live_output(app),
            KeyCode::Char('v') => toggle_live_output_mode(app),
            KeyCode::Char('c') => {
                app.logs.clear();
                app.scroll = 0;
                app.output.total_rows = 0;
            }
            KeyCode::Char('k') => {
                if let Some(mut child) = app.child.take() {
                    let _ = child.kill();
                }
                if let Some(start) = app.install_started_at.take() {
                    let d = start.elapsed();
                    app.push_log_line(format!("Install aborted after {}", format_duration(d)));
                }
            }
            _ => {}
        },
        UiMode::Preflight => return handle_preflight_keys(app, key),
    }
    Ok(false)
}

// With a single menu entry, selection logic not required; keep a noop to avoid accidental calls
#[allow(dead_code)]
fn move_selection(_app: &mut AppState, _delta: isize) {}

// run_selected_action no longer needed; start directly from Preflight

fn spawn_setup(app: &mut AppState, flags: &[&str]) -> Result<()> {
    if let Some(reason) = package_start_blocker(app) {
        bail!("setup cannot start: {reason}");
    }

    let script = match &app.setup_script {
        Some(p) => p.clone(),
        None => {
            if let Some(found) = resolve_setup_script_path() {
                app.setup_script = Some(found.clone());
                found
            } else {
                bail!("setup.sh not found. Set HYPR_SETUP_PATH or run from repo root.");
            }
        }
    };

    // Use a PTY via `script` to keep all outputs contained in the TUI area (progress bars, sudo prompts, etc.)
    // Fallback to direct bash execution if `script` is unavailable.
    let mut cmd;
    let cmdline = {
        let mut s = String::from("bash ");
        s.push_str(&script.display().to_string());
        for f in flags {
            s.push(' ');
            s.push_str(f);
        }
        s
    };

    let dry_run_flag = app.preflight.dry_run;
    if which::which("script").is_ok() && !dry_run_flag {
        // script -q (quiet) -f (flush) -c "<cmd>" /dev/null
        cmd = Command::new("script");
        cmd.arg("-q")
            .arg("-e")
            .arg("-f")
            .arg("-c")
            .arg(cmdline)
            .arg("/dev/null");
    } else {
        cmd = Command::new("bash");
        cmd.arg(&script);
        for f in flags {
            cmd.arg(f);
        }
    }
    // Build selected packages into env strings
    let selected_pacman = if !app.pacman_sel_map.is_empty() {
        let mut out = Vec::new();
        for (name, sel) in &app.pacman_sel_map {
            if *sel {
                out.push(name.clone());
            }
        }
        out.sort();
        // Merge user-added pacman packages
        for name in &app.user_added {
            if let Some(src) = app.user_added_src.get(name)
                && src == "pacman"
            {
                out.push(name.clone());
            }
        }
        out.sort();
        out.dedup();
        out.join(" ")
    } else {
        String::new()
    };
    let selected_aur = if !app.aur_sel_map.is_empty() {
        let mut out = Vec::new();
        for (name, sel) in &app.aur_sel_map {
            if *sel {
                out.push(name.clone());
            }
        }
        out.sort();
        // Merge user-added AUR packages
        for name in &app.user_added {
            if let Some(src) = app.user_added_src.get(name)
                && src == "aur"
            {
                out.push(name.clone());
            }
        }
        out.sort();
        out.dedup();
        out.join(" ")
    } else {
        String::new()
    };

    // Non-interactive env config from preflight
    let pf = &app.preflight;
    cmd.env("NON_INTERACTIVE", "true");
    if !pf.password.is_empty() {
        cmd.env("SUDO_PASSWORD", pf.password.clone());
    }
    cmd.env(
        "PROMPT_DEFAULT_YN",
        if pf.prompt_default_yes { "y" } else { "n" },
    );
    let selected_shell_is_fish = app
        .role_selection
        .as_ref()
        .and_then(|selection| selection.selected_package("shell"))
        == Some("fish");
    if selected_shell_is_fish {
        cmd.env(
            "FISH_LANGUAGE_CHOICE_OVERRIDE",
            pf.fish_language_choice.to_string(),
        );
    }
    cmd.env("WALLPAPER_DIR_OVERRIDE", pf.wallpaper_dir.clone());
    cmd.env(
        "MONITOR_SETUP_ENABLED",
        if pf.monitor_setup_enabled {
            "true"
        } else {
            "false"
        },
    );
    if !pf.monitor_config.trim().is_empty() {
        cmd.env("MONITOR_CONFIG", pf.monitor_config.clone());
    }
    cmd.env(
        "AUTO_CONTINUE_ON_WARNINGS",
        if pf.auto_continue_on_warnings {
            "true"
        } else {
            "false"
        },
    );
    cmd.env("SELECTED_PACMAN_PACKAGES", selected_pacman.clone());
    cmd.env("SELECTED_AUR_PACKAGES", selected_aur.clone());
    if let (Some(registry), Some(selection)) =
        (app.package_registry.as_ref(), app.role_selection.as_ref())
    {
        for (name, value) in selection.export_env(registry)? {
            cmd.env(name, value);
        }
    }
    // Also pass user-added splits explicitly for setup.sh merging
    let mut user_pac = Vec::new();
    let mut user_aur = Vec::new();
    for name in &app.user_added {
        if let Some(src) = app.user_added_src.get(name) {
            if src == "pacman" {
                user_pac.push(name.clone());
            }
            if src == "aur" {
                user_aur.push(name.clone());
            }
        }
    }
    if !user_pac.is_empty() {
        cmd.env("USER_ADDED_PACMAN_PACKAGES", user_pac.join(" "));
    }
    if !user_aur.is_empty() {
        cmd.env("USER_ADDED_AUR_PACKAGES", user_aur.join(" "));
    }

    cmd.stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());

    // Log sanitized command (avoid dumping env, especially password)
    let mut display_cmd = String::new();
    if dry_run_flag {
        display_cmd.push_str("bash ./setup.sh --dry-run");
    } else {
        display_cmd.push_str("bash ./setup.sh");
    }
    app.push_log_line(format!("$ {}", display_cmd));
    let mut child = cmd.spawn().context("spawn setup.sh")?;
    let stdout = child.stdout.take();
    let stderr = child.stderr.take();
    app.child = Some(child);
    // Reset sections and pre-load expected steps from script so the full list is visible from the start
    app.sections = preload_sections_from_script(&script);
    app.planned_section_count = app.sections.len();
    app.current_section = None;
    app.install_started_at = Some(Instant::now());
    app.push_log_line("Install started");
    let tx_out = app.tx.clone();
    if let Some(mut stdout) = stdout {
        thread::spawn(move || {
            let mut buf = [0u8; 8192];
            let mut acc = String::new();
            loop {
                match stdout.read(&mut buf) {
                    Ok(0) => {
                        if !acc.is_empty() {
                            let s = strip_ansi_sequences(&acc);
                            let _ = tx_out.send(s);
                        }
                        break;
                    }
                    Ok(n) => {
                        acc.push_str(&String::from_utf8_lossy(&buf[..n]));
                        // Treat \r as line breaks to flush progress lines
                        acc = acc.replace('\r', "\n");
                        while let Some(pos) = acc.find('\n') {
                            let mut line = acc[..pos].to_string();
                            acc = acc[pos + 1..].to_string();
                            if !line.trim().is_empty() {
                                line = strip_ansi_sequences(&line);
                                let _ = tx_out.send(line);
                            }
                        }
                    }
                    Err(_) => break,
                }
            }
        });
    }
    let tx_err = app.tx.clone();
    if let Some(mut stderr) = stderr {
        thread::spawn(move || {
            let mut buf = [0u8; 4096];
            let mut acc = String::new();
            loop {
                match stderr.read(&mut buf) {
                    Ok(0) => {
                        if !acc.is_empty() {
                            let s = strip_ansi_sequences(&acc);
                            let _ = tx_err.send(s);
                        }
                        break;
                    }
                    Ok(n) => {
                        acc.push_str(&String::from_utf8_lossy(&buf[..n]));
                        acc = acc.replace('\r', "\n");
                        while let Some(pos) = acc.find('\n') {
                            let mut line = acc[..pos].to_string();
                            acc = acc[pos + 1..].to_string();
                            if !line.trim().is_empty() {
                                line = strip_ansi_sequences(&line);
                                let _ = tx_err.send(line);
                            }
                        }
                    }
                    Err(_) => break,
                }
            }
        });
    }

    // Detach handles; process output is already streamed
    Ok(())
}

#[allow(dead_code)]
fn kill_child(_app: &mut AppState) {}

fn resolve_setup_script_path() -> Option<PathBuf> {
    if let Ok(p) = std::env::var("HYPR_SETUP_PATH") {
        let p = PathBuf::from(p);
        if p.exists() {
            return Some(p);
        }
    }
    let candidates = [
        PathBuf::from("./setup.sh"),
        PathBuf::from("../setup.sh"),
        PathBuf::from("../../setup.sh"),
        PathBuf::from("../../../setup.sh"),
    ];
    candidates.into_iter().find(|c| c.exists())
}

fn load_package_registry(setup_script: Option<&Path>) -> Result<PackagesRoot> {
    let setup_script = setup_script
        .context("setup.sh was not resolved, so packages.json cannot be located relative to it")?;
    let resolved = fs::canonicalize(setup_script)
        .with_context(|| format!("resolve setup script {}", setup_script.display()))?;
    let root = resolved
        .parent()
        .context("resolved setup.sh path has no parent directory")?;
    PackagesRoot::load(&root.join("packages.json"))
}

fn selected_application_role(app: &AppState) -> Option<&'static str> {
    ROLE_ORDER.get(app.application_cursor).copied()
}

fn sync_role_package_selection(app: &mut AppState) {
    let Some(registry) = app.package_registry.as_ref() else {
        return;
    };
    let Some(selection) = app.role_selection.as_ref() else {
        return;
    };
    let selected_pacman = selection.selected_install_packages(registry, PackageSource::Pacman);
    let selected_aur = selection.selected_install_packages(registry, PackageSource::Aur);
    let updates: Vec<(PackageSource, String, bool)> = [PackageSource::Pacman, PackageSource::Aur]
        .into_iter()
        .flat_map(|source| {
            let selected = match source {
                PackageSource::Pacman => &selected_pacman,
                PackageSource::Aur => &selected_aur,
                PackageSource::Official => {
                    unreachable!("official packages are not generic selections")
                }
            };
            registry
                .role_controlled_packages(source)
                .into_iter()
                .map(move |package| (source, package.to_string(), selected.contains(package)))
        })
        .collect();
    for (source, package, selected) in updates {
        match source {
            PackageSource::Pacman => {
                app.pacman_sel_map.insert(package, selected);
            }
            PackageSource::Aur => {
                app.aur_sel_map.insert(package, selected);
            }
            PackageSource::Official => unreachable!("official packages are not generic selections"),
        }
    }
}

fn force_required_selected(app: &mut AppState) {
    enforce_required(&app.required_pacman, &mut app.pacman_sel_map);
    enforce_required(&app.required_aur, &mut app.aur_sel_map);
}

fn is_role_controlled_package(app: &AppState, package: &str) -> bool {
    app.package_registry
        .as_ref()
        .is_some_and(|registry| registry.is_role_controlled_package(package))
}

fn toggle_package_selection(app: &mut AppState, source: PackageSource, package: &str) {
    let required = match source {
        PackageSource::Pacman => app.required_pacman.contains(package),
        PackageSource::Aur => app.required_aur.contains(package),
        PackageSource::Official => return,
    };
    if required {
        return;
    }

    match source {
        PackageSource::Pacman => {
            toggle_with_required(&app.required_pacman, &mut app.pacman_sel_map, package)
        }
        PackageSource::Aur => {
            toggle_with_required(&app.required_aur, &mut app.aur_sel_map, package)
        }
        PackageSource::Official => return,
    }
    force_required_selected(app);
}

fn set_all_package_selections(app: &mut AppState, source: PackageSource, selected: bool) {
    match source {
        PackageSource::Pacman => {
            set_all_with_required(&app.required_pacman, &mut app.pacman_sel_map, selected)
        }
        PackageSource::Aur => {
            set_all_with_required(&app.required_aur, &mut app.aur_sel_map, selected)
        }
        PackageSource::Official => return,
    }
    sync_role_package_selection(app);
    force_required_selected(app);
}

fn visible_package_rows(app: &AppState, source: PackageSource) -> Vec<Option<String>> {
    let (categories, filter) = match source {
        PackageSource::Pacman => (&app.pacman_cats, &app.pacman_filter_working),
        PackageSource::Aur => (&app.aur_cats, &app.aur_filter_working),
        PackageSource::Official => return Vec::new(),
    };
    let mut rows = Vec::new();
    for (category, packages) in categories {
        if !filter.is_empty() && !filter.contains(category) {
            continue;
        }
        rows.push(None);
        rows.extend(packages.iter().cloned().map(Some));
    }
    rows
}

fn package_start_blocker(app: &AppState) -> Option<String> {
    if let Some(error) = &app.package_load_error {
        return Some(format!("Package registry error: {error}"));
    }
    match (&app.package_registry, &app.role_selection) {
        (Some(registry), Some(selection)) => ROLE_ORDER.into_iter().find_map(|role_name| {
            let role = &registry.roles[role_name];
            let missing = role.required
                && selection
                    .selected_packages(role_name)
                    .is_none_or(BTreeSet::is_empty);
            missing.then(|| match role.selection {
                SelectionKind::Single => format!("Select exactly one {}", role.label),
                SelectionKind::Multiple => format!("Select at least one {}", role.label),
            })
        }),
        _ => Some("Package registry is unavailable".to_string()),
    }
}

fn classify_package(name: &str) -> Option<PackageSource> {
    let available = |program: &str| {
        Command::new(program)
            .arg("-Si")
            .arg("--")
            .arg(name)
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()
            .is_ok_and(|status| status.success())
    };
    if available("pacman") {
        Some(PackageSource::Pacman)
    } else if available("yay") {
        Some(PackageSource::Aur)
    } else {
        None
    }
}

fn install_panic_hook() {
    std::panic::set_hook(Box::new(|info| {
        restore_terminal();
        eprintln!("Application panicked: {info}");
    }));
}

fn guess_default_wallpaper_dir(setup_script: &Option<PathBuf>) -> Option<String> {
    if let Some(script) = setup_script
        && let Ok(real) = std::fs::canonicalize(script)
        && let Some(root) = real.parent()
    {
        let wp = root.join("Wallpaper");
        return Some(wp.display().to_string());
    }
    // Try to locate repo root via setup.sh if not provided
    if let Some(script) = resolve_setup_script_path()
        && let Ok(real) = std::fs::canonicalize(script)
        && let Some(root) = real.parent()
    {
        let wp = root.join("Wallpaper");
        return Some(wp.display().to_string());
    }
    // Walk upwards from current dir to find a Wallpaper directory
    if let Ok(mut dir) = std::env::current_dir() {
        for _ in 0..5 {
            let candidate = dir.join("Wallpaper");
            if candidate.exists() {
                return Some(candidate.display().to_string());
            }
            if !dir.pop() {
                break;
            }
        }
    }
    Some("./Wallpaper".to_string())
}

fn handle_preflight_keys(app: &mut AppState, key: KeyEvent) -> Result<bool> {
    if app.editing {
        if app.edit_kind == EditKind::MonitorWizard {
            // Wizard navigation and operations
            match key.code {
                KeyCode::Esc | KeyCode::Char('q') => {
                    app.editing = false;
                    app.edit_kind = EditKind::None;
                    app.mw_monitors.clear();
                    app.mw_buffer.clear();
                }
                KeyCode::Tab => {
                    app.mw_active_col = (app.mw_active_col + 1) % 3;
                }
                KeyCode::Char('j') | KeyCode::Down => match app.mw_active_col % 3 {
                    0 => {
                        app.mw_selected_monitor = app
                            .mw_selected_monitor
                            .saturating_add(1)
                            .min(app.mw_monitors.len().saturating_sub(1))
                    }
                    1 => app.mw_selected_mode = app.mw_selected_mode.saturating_add(1),
                    _ => app.mw_selected_scale = app.mw_selected_scale.saturating_add(1),
                },
                KeyCode::Char('k') | KeyCode::Up => match app.mw_active_col % 3 {
                    0 => app.mw_selected_monitor = app.mw_selected_monitor.saturating_sub(1),
                    1 => app.mw_selected_mode = app.mw_selected_mode.saturating_sub(1),
                    _ => app.mw_selected_scale = app.mw_selected_scale.saturating_sub(1),
                },
                KeyCode::Char('x') => {
                    // remove last semicolon-delimited entry
                    if let Some(idx) = app.mw_buffer.rfind(';') {
                        app.mw_buffer.truncate(idx);
                    } else {
                        app.mw_buffer.clear();
                    }
                }
                KeyCode::Enter => {
                    if let Some(mon) = app.mw_monitors.get(app.mw_selected_monitor) {
                        let name = &mon.name;
                        let modes = &mon.modes;
                        let mode = modes
                            .get(app.mw_selected_mode)
                            .cloned()
                            .unwrap_or_else(|| "1920x1080@60".to_string());
                        let scales = ["0.75", "1.0", "1.25", "1.5", "2.0"];
                        let scale = scales
                            .get(app.mw_selected_scale.min(scales.len() - 1))
                            .unwrap_or(&"1.0");
                        if !app.mw_buffer.is_empty() && !app.mw_buffer.ends_with(';') {
                            app.mw_buffer.push(';');
                        }
                        app.mw_buffer
                            .push_str(&format!("{}:{}:{}", name, mode, scale));
                    }
                }
                KeyCode::Char('s') => {
                    app.preflight.monitor_config = app.mw_buffer.clone();
                    if !app.preflight.monitor_config.trim().is_empty() {
                        app.preflight.monitor_setup_enabled = true;
                    }
                    app.editing = false;
                    app.edit_kind = EditKind::None;
                }
                _ => {}
            }
            return Ok(false);
        } else if app.edit_kind == EditKind::Info {
            match key.code {
                KeyCode::Esc | KeyCode::Enter | KeyCode::Char('q') => {
                    app.editing = false;
                    app.edit_kind = EditKind::None;
                }
                _ => {}
            }
            return Ok(false);
        } else if app.edit_kind == EditKind::AddPackagesWarning {
            match key.code {
                KeyCode::Esc | KeyCode::Enter | KeyCode::Char('q') => {
                    // Return to AddPackages text editor to let user fix
                    app.edit_kind = EditKind::Text;
                    // keep editing true, keep current buffer
                }
                _ => {}
            }
            return Ok(false);
        } else if app.edit_kind == EditKind::ConfirmEnableMonitorSetup {
            match key.code {
                KeyCode::Char('y') | KeyCode::Char('Y') | KeyCode::Enter => {
                    // Enable and open monitor wizard
                    app.preflight.monitor_setup_enabled = true;
                    app.edit_kind = EditKind::MonitorWizard;
                    app.mw_buffer = app.preflight.monitor_config.clone();
                    app.mw_monitors = discover_hypr_monitors();
                    app.mw_selected_monitor = 0;
                    app.mw_selected_mode = 0;
                    app.mw_selected_scale = 1;
                }
                KeyCode::Esc | KeyCode::Char('n') | KeyCode::Char('N') | KeyCode::Char('q') => {
                    app.editing = false;
                    app.edit_kind = EditKind::None;
                }
                _ => {}
            }
            return Ok(false);
        } else if app.edit_kind == EditKind::ConfirmStartInstall {
            match key.code {
                KeyCode::Char('y') | KeyCode::Char('Y') | KeyCode::Enter => {
                    app.editing = false;
                    app.edit_kind = EditKind::None;
                    app.ui_mode = UiMode::Menu; // return to menu for logs visibility
                    if app.preflight.dry_run {
                        spawn_setup(app, &["--dry-run"])?;
                    } else {
                        spawn_setup(app, &[])?;
                    }
                }
                KeyCode::Esc | KeyCode::Char('n') | KeyCode::Char('N') | KeyCode::Char('q') => {
                    app.editing = false;
                    app.edit_kind = EditKind::None;
                }
                _ => {}
            }
            return Ok(false);
        } else if app.edit_kind == EditKind::ConfirmReboot {
            match key.code {
                KeyCode::Char('y') | KeyCode::Char('Y') | KeyCode::Enter => {
                    // Try to reboot non-interactively
                    let _ = Command::new("systemctl").arg("reboot").spawn();
                    app.editing = false;
                    app.edit_kind = EditKind::None;
                }
                KeyCode::Esc | KeyCode::Char('n') | KeyCode::Char('N') | KeyCode::Char('q') => {
                    app.editing = false;
                    app.edit_kind = EditKind::None;
                }
                _ => {}
            }
            return Ok(false);
        } else if app.edit_kind == EditKind::SelectApplications {
            match key.code {
                KeyCode::Esc | KeyCode::Char('q') => {
                    app.editing = false;
                    app.edit_kind = EditKind::None;
                }
                KeyCode::Tab | KeyCode::Char('j') | KeyCode::Down => {
                    app.application_cursor = (app.application_cursor + 1) % ROLE_ORDER.len();
                }
                KeyCode::BackTab | KeyCode::Char('k') | KeyCode::Up => {
                    app.application_cursor =
                        (app.application_cursor + ROLE_ORDER.len() - 1) % ROLE_ORDER.len();
                }
                KeyCode::Home => app.application_cursor = 0,
                KeyCode::End => app.application_cursor = ROLE_ORDER.len() - 1,
                KeyCode::PageDown => {
                    app.application_cursor = (app.application_cursor + 5).min(ROLE_ORDER.len() - 1)
                }
                KeyCode::PageUp => {
                    app.application_cursor = app.application_cursor.saturating_sub(5)
                }
                KeyCode::Enter | KeyCode::Char(' ') => {
                    app.edit_kind = EditKind::SelectRole;
                    app.role_cursor = 0;
                }
                _ => {}
            }
            return Ok(false);
        } else if app.edit_kind == EditKind::SelectRole {
            let Some(role_name) = selected_application_role(app) else {
                app.editing = false;
                app.edit_kind = EditKind::None;
                return Ok(false);
            };
            let option_count = app
                .package_registry
                .as_ref()
                .map(|registry| {
                    let role = &registry.roles[role_name];
                    role.options.len() + usize::from(!role.required)
                })
                .unwrap_or(0);
            match key.code {
                KeyCode::Esc | KeyCode::Enter | KeyCode::Char('q') => {
                    app.edit_kind = EditKind::SelectApplications;
                }
                KeyCode::Char('j') | KeyCode::Down => {
                    if option_count > 0 {
                        app.role_cursor = (app.role_cursor + 1) % option_count;
                    }
                }
                KeyCode::Char('k') | KeyCode::Up => {
                    if option_count > 0 {
                        app.role_cursor = if app.role_cursor == 0 {
                            option_count - 1
                        } else {
                            app.role_cursor - 1
                        };
                    }
                }
                KeyCode::Home => app.role_cursor = 0,
                KeyCode::End => app.role_cursor = option_count.saturating_sub(1),
                KeyCode::PageDown => {
                    app.role_cursor = (app.role_cursor + 5).min(option_count.saturating_sub(1))
                }
                KeyCode::PageUp => app.role_cursor = app.role_cursor.saturating_sub(5),
                KeyCode::Char(' ') | KeyCode::Char('p') => {
                    let choice = app.package_registry.as_ref().and_then(|registry| {
                        let role = &registry.roles[role_name];
                        if !role.required && app.role_cursor == 0 {
                            Some(None)
                        } else {
                            let offset = usize::from(!role.required);
                            role.options
                                .get(app.role_cursor.saturating_sub(offset))
                                .map(|option| Some(option.package.clone()))
                        }
                    });
                    if let (Some(registry), Some(selection), Some(choice)) = (
                        app.package_registry.as_ref(),
                        app.role_selection.as_mut(),
                        choice,
                    ) {
                        if let Some(package) = choice {
                            if key.code == KeyCode::Char('p') {
                                let _ = selection.set_primary(registry, role_name, &package);
                            } else {
                                selection.toggle_member(registry, role_name, &package)?;
                            }
                        } else {
                            selection.clear(registry, role_name)?;
                        }
                    }
                    sync_role_package_selection(app);
                    force_required_selected(app);
                }
                _ => {}
            }
            return Ok(false);
        } else if app.edit_kind == EditKind::SelectPacman || app.edit_kind == EditKind::SelectAur {
            // Multiselect handling (categorized) — headers are not selectable
            let is_pacman = app.edit_kind == EditKind::SelectPacman;
            let source = if is_pacman {
                PackageSource::Pacman
            } else {
                PackageSource::Aur
            };
            let visible_rows = visible_package_rows(app, source);
            let len = visible_rows.len();
            let header_idx: Vec<usize> = visible_rows
                .iter()
                .enumerate()
                .filter_map(|(index, package)| package.is_none().then_some(index))
                .collect();
            match key.code {
                KeyCode::Esc | KeyCode::Char('q') => {
                    app.editing = false;
                }
                KeyCode::Enter => {
                    app.editing = false; // selections already stored in sel vecs
                }
                KeyCode::Tab => {
                    app.ms_focus_right = !app.ms_focus_right;
                }
                KeyCode::Char('j') | KeyCode::Down => {
                    if app.ms_focus_right {
                        let mut cats: Vec<String> = if is_pacman {
                            app.pacman_cats.iter().map(|(c, _)| c.clone()).collect()
                        } else {
                            app.aur_cats.iter().map(|(c, _)| c.clone()).collect()
                        };
                        cats.sort();
                        let lenf = cats.len();
                        if lenf > 0 {
                            app.ms_cursor_filter = if app.ms_cursor_filter + 1 >= lenf {
                                0
                            } else {
                                app.ms_cursor_filter + 1
                            };
                        }
                    } else if len > 0 {
                        // advance and skip headers
                        for _ in 0..len {
                            app.ms_cursor = if app.ms_cursor + 1 >= len {
                                0
                            } else {
                                app.ms_cursor + 1
                            };
                            if !header_idx.contains(&app.ms_cursor) {
                                break;
                            }
                        }
                    }
                }
                KeyCode::Char('k') | KeyCode::Up => {
                    if app.ms_focus_right {
                        let mut cats: Vec<String> = if is_pacman {
                            app.pacman_cats.iter().map(|(c, _)| c.clone()).collect()
                        } else {
                            app.aur_cats.iter().map(|(c, _)| c.clone()).collect()
                        };
                        cats.sort();
                        let lenf = cats.len();
                        if lenf > 0 {
                            app.ms_cursor_filter = if app.ms_cursor_filter == 0 {
                                lenf - 1
                            } else {
                                app.ms_cursor_filter - 1
                            };
                        }
                    } else if len > 0 {
                        // retreat and skip headers
                        for _ in 0..len {
                            app.ms_cursor = if app.ms_cursor == 0 {
                                len - 1
                            } else {
                                app.ms_cursor - 1
                            };
                            if !header_idx.contains(&app.ms_cursor) {
                                break;
                            }
                        }
                    }
                }
                KeyCode::Char(' ') => {
                    if app.ms_focus_right {
                        // toggle filter entry
                        let mut cats: Vec<String> = if is_pacman {
                            app.pacman_cats.iter().map(|(c, _)| c.clone()).collect()
                        } else {
                            app.aur_cats.iter().map(|(c, _)| c.clone()).collect()
                        };
                        cats.sort();
                        let idx = app.ms_cursor_filter.min(cats.len().saturating_sub(1));
                        if let Some(cat) = cats.get(idx) {
                            if is_pacman {
                                if app.pacman_filter_working.contains(cat) {
                                    app.pacman_filter_working.remove(cat);
                                } else {
                                    app.pacman_filter_working.insert(cat.clone());
                                }
                            } else if app.aur_filter_working.contains(cat) {
                                app.aur_filter_working.remove(cat);
                            } else {
                                app.aur_filter_working.insert(cat.clone());
                            }
                        }
                    } else if let Some(Some(package)) = visible_rows.get(app.ms_cursor) {
                        toggle_package_selection(app, source, package);
                    }
                }
                KeyCode::Char('a') => {
                    if app.ms_focus_right {
                        // select all categories
                        let mut cats: Vec<String> = if is_pacman {
                            app.pacman_cats.iter().map(|(c, _)| c.clone()).collect()
                        } else {
                            app.aur_cats.iter().map(|(c, _)| c.clone()).collect()
                        };
                        cats.sort();
                        if is_pacman {
                            app.pacman_filter_working = cats.into_iter().collect();
                        } else {
                            app.aur_filter_working = cats.into_iter().collect();
                        }
                    } else {
                        set_all_package_selections(
                            app,
                            if is_pacman {
                                PackageSource::Pacman
                            } else {
                                PackageSource::Aur
                            },
                            true,
                        );
                    }
                }
                KeyCode::Char('n') => {
                    if app.ms_focus_right {
                        // clear categories (empty means all)
                        if is_pacman {
                            app.pacman_filter_working.clear();
                        } else {
                            app.aur_filter_working.clear();
                        }
                    } else {
                        set_all_package_selections(
                            app,
                            if is_pacman {
                                PackageSource::Pacman
                            } else {
                                PackageSource::Aur
                            },
                            false,
                        );
                    }
                }
                _ => {}
            }
            return Ok(false);
        }
        match key.code {
            KeyCode::Esc => {
                app.editing = false;
                app.edit_buffer.clear();
            }
            KeyCode::Char('q') => {
                // For password input, 'q' should be treated as a regular character
                // For other text inputs, 'q' cancels editing
                if app.preflight_focus == PreflightField::Password {
                    app.edit_buffer.push('q');
                } else {
                    app.editing = false;
                    app.edit_buffer.clear();
                }
            }
            KeyCode::Enter => {
                // Intercept AddPackages: validate and show popup if issues
                if app.preflight_focus == PreflightField::AddPackages {
                    let raw = app.edit_buffer.clone();
                    let mut names: Vec<String> = raw
                        .split(',')
                        .filter(|s| !s.trim().is_empty())
                        .map(|s| s.trim().to_string())
                        .collect();
                    names.sort();
                    names.dedup();
                    let mut warnings: Vec<String> = Vec::new();
                    for name in &names {
                        if is_role_controlled_package(app, name) {
                            warnings.push(format!(
                                "Managed by its application role; use the role selector: {name}"
                            ));
                            continue;
                        }
                        if app.pacman_sel_map.contains_key(name)
                            || app.aur_sel_map.contains_key(name)
                            || app.user_added.contains(name)
                        {
                            warnings.push(format!("Already selected: {name}"));
                            continue;
                        }
                        if classify_package(name).is_none() {
                            warnings.push(format!("Not found in pacman or AUR: {}", name));
                        }
                    }
                    if !warnings.is_empty() {
                        app.warning_lines = warnings;
                        app.edit_kind = EditKind::AddPackagesWarning;
                        // keep editing true to show popup; do not apply yet
                        return Ok(false);
                    }
                }
                apply_edit_buffer(app);
                app.editing = false;
                app.edit_buffer.clear();
                // no-op
            }
            KeyCode::Backspace => {
                app.edit_buffer.pop();
            }
            KeyCode::Char(c) => app.edit_buffer.push(c),
            _ => {}
        }
        return Ok(false);
    }

    match key.code {
        KeyCode::Char('q') => return Ok(true),
        KeyCode::Home | KeyCode::End => resume_output_follow(
            &mut app.scroll,
            &mut app.follow_tail,
            app.logs.len(),
            app.log_viewport_lines,
        ),
        KeyCode::PageUp => scroll_output_up(
            &mut app.scroll,
            &mut app.follow_tail,
            app.logs.len(),
            app.log_viewport_lines,
        ),
        KeyCode::PageDown => {
            scroll_output_down(&mut app.scroll, app.logs.len(), app.log_viewport_lines)
        }
        KeyCode::Tab | KeyCode::Char('j') | KeyCode::Down => preflight_focus_next(app),
        KeyCode::BackTab | KeyCode::Char('k') | KeyCode::Up => preflight_focus_prev(app),
        KeyCode::Left => adjust_preflight_field(app, -1),
        KeyCode::Right => adjust_preflight_field(app, 1),
        KeyCode::Char('1') => set_language_choice(app, 1),
        KeyCode::Char('2') => set_language_choice(app, 2),
        KeyCode::Char('3') => set_language_choice(app, 3),
        KeyCode::Char(' ') => toggle_boolean_field(app),
        KeyCode::Char('e') => begin_editing(app),
        KeyCode::Enter => {
            // Enter: start only if Start is focused; otherwise, begin editing if field is editable
            match app.preflight_focus {
                PreflightField::Start => {
                    if let Some(reason) = package_start_blocker(app) {
                        show_info(app, "Setup cannot start", vec![reason]);
                        return Ok(false);
                    }
                    if app.preflight.password.is_empty() {
                        // Show small info popup instead of only logging
                        show_info(
                            app,
                            "Password required",
                            vec!["Password is required to run unattended setup.".to_string()],
                        );
                        return Ok(false);
                    }
                    if app.preflight.dry_run {
                        app.ui_mode = UiMode::Menu; // return to menu for logs visibility
                        spawn_setup(app, &["--dry-run"])?;
                        return Ok(false);
                    }
                    app.editing = true;
                    app.edit_kind = EditKind::ConfirmStartInstall;
                    return Ok(false);
                }
                PreflightField::Applications => {
                    app.editing = true;
                    app.edit_kind = EditKind::SelectApplications;
                }
                PreflightField::EnvWallpaperDirOverride => begin_editing(app),
                PreflightField::EnvMonitorConfig => begin_editing(app),
                PreflightField::Password => begin_editing(app),
                PreflightField::SelectPacman => {
                    app.editing = true;
                    app.edit_kind = EditKind::SelectPacman;
                    app.ms_cursor = 0;
                    app.ms_focus_right = false;
                    app.ms_cursor_filter = 0;
                }
                PreflightField::SelectAur => {
                    app.editing = true;
                    app.edit_kind = EditKind::SelectAur;
                    app.ms_cursor = 0;
                    app.ms_focus_right = false;
                    app.ms_cursor_filter = 0;
                }
                PreflightField::AddPackages => {
                    app.editing = true;
                    app.edit_kind = EditKind::Text;
                    app.add_packages_append_mode = true; // Enter opens in append mode
                    app.edit_buffer = String::new();
                }
                _ => {}
            }
        }
        _ => {}
    }
    Ok(false)
}

fn preflight_focus_next(app: &mut AppState) {
    app.preflight_focus = match app.preflight_focus {
        PreflightField::EnvPromptDefaultYn => PreflightField::EnvFishLanguageChoiceOverride,
        PreflightField::EnvFishLanguageChoiceOverride => PreflightField::Applications,
        PreflightField::Applications => PreflightField::EnvWallpaperDirOverride,
        PreflightField::EnvWallpaperDirOverride => PreflightField::EnvMonitorSetupEnabled,
        PreflightField::EnvMonitorSetupEnabled => PreflightField::EnvMonitorConfig,
        PreflightField::EnvMonitorConfig => PreflightField::EnvAutoContinueOnWarnings,
        PreflightField::EnvAutoContinueOnWarnings => PreflightField::Password,
        PreflightField::Password => PreflightField::SelectPacman,
        PreflightField::SelectPacman => PreflightField::SelectAur,
        PreflightField::SelectAur => PreflightField::AddPackages,
        PreflightField::AddPackages => PreflightField::EnvDryRun,
        PreflightField::EnvDryRun => PreflightField::Start,
        PreflightField::Start => PreflightField::EnvPromptDefaultYn,
    };
}

fn preflight_focus_prev(app: &mut AppState) {
    app.preflight_focus = match app.preflight_focus {
        PreflightField::EnvPromptDefaultYn => PreflightField::Start,
        PreflightField::EnvFishLanguageChoiceOverride => PreflightField::EnvPromptDefaultYn,
        PreflightField::Applications => PreflightField::EnvFishLanguageChoiceOverride,
        PreflightField::EnvWallpaperDirOverride => PreflightField::Applications,
        PreflightField::EnvMonitorSetupEnabled => PreflightField::EnvWallpaperDirOverride,
        PreflightField::EnvMonitorConfig => PreflightField::EnvMonitorSetupEnabled,
        PreflightField::EnvAutoContinueOnWarnings => PreflightField::EnvMonitorConfig,
        PreflightField::Password => PreflightField::EnvAutoContinueOnWarnings,
        PreflightField::SelectPacman => PreflightField::Password,
        PreflightField::SelectAur => PreflightField::SelectPacman,
        PreflightField::AddPackages => PreflightField::SelectAur,
        PreflightField::EnvDryRun => PreflightField::AddPackages,
        PreflightField::Start => PreflightField::EnvDryRun,
    };
}

fn adjust_preflight_field(app: &mut AppState, delta: i32) {
    match app.preflight_focus {
        PreflightField::EnvFishLanguageChoiceOverride => {
            let mut v = app.preflight.fish_language_choice as i32 + delta;
            if v < 1 {
                v = 3;
            }
            if v > 3 {
                v = 1;
            }
            app.preflight.fish_language_choice = v as u8;
        }
        PreflightField::EnvPromptDefaultYn => {
            app.preflight.prompt_default_yes = delta >= 0;
        }
        PreflightField::EnvDryRun => {
            app.preflight.dry_run = delta >= 0;
        }
        _ => {}
    }
}

fn set_language_choice(app: &mut AppState, choice: u8) {
    if app.preflight_focus == PreflightField::EnvFishLanguageChoiceOverride
        && (1..=3).contains(&choice)
    {
        app.preflight.fish_language_choice = choice;
    }
}

fn toggle_boolean_field(app: &mut AppState) {
    match app.preflight_focus {
        PreflightField::EnvPromptDefaultYn => {
            app.preflight.prompt_default_yes = !app.preflight.prompt_default_yes
        }
        PreflightField::EnvMonitorSetupEnabled => {
            if !app.monitor_setup_available {
                show_info(
                    app,
                    "Monitor setup not available",
                    monitor_setup_availability().1,
                );
                app.preflight.monitor_setup_enabled = false;
                return;
            }
            app.preflight.monitor_setup_enabled = !app.preflight.monitor_setup_enabled
        }
        PreflightField::EnvAutoContinueOnWarnings => {
            app.preflight.auto_continue_on_warnings = !app.preflight.auto_continue_on_warnings
        }
        PreflightField::EnvDryRun => app.preflight.dry_run = !app.preflight.dry_run,
        _ => {}
    }
}

fn begin_editing(app: &mut AppState) {
    match app.preflight_focus {
        PreflightField::EnvWallpaperDirOverride => {
            app.editing = true;
            app.edit_kind = EditKind::Text;
            app.edit_buffer = app.preflight.wallpaper_dir.clone();
        }
        PreflightField::EnvMonitorConfig => {
            if !app.monitor_setup_available {
                show_info(
                    app,
                    "Monitor setup not available",
                    monitor_setup_availability().1,
                );
                app.preflight.monitor_setup_enabled = false;
                return;
            }
            if !app.preflight.monitor_setup_enabled {
                // Ask to enable
                app.editing = true;
                app.edit_kind = EditKind::ConfirmEnableMonitorSetup;
                return;
            }
            app.editing = true;
            app.edit_kind = EditKind::MonitorWizard;
            app.mw_buffer = app.preflight.monitor_config.clone();
            // Try to discover monitors/modes via hyprctl (best-effort)
            app.mw_monitors = discover_hypr_monitors();
            app.mw_selected_monitor = 0;
            app.mw_selected_mode = 0;
            app.mw_selected_scale = 1;
        }
        PreflightField::Password => {
            app.editing = true;
            app.edit_kind = EditKind::Text;
            app.edit_buffer = String::new();
        }
        PreflightField::AddPackages => {
            app.editing = true;
            app.edit_kind = EditKind::Text;
            app.add_packages_append_mode = false; // 'e' opens in replace/edit mode
            if app.user_added.is_empty() {
                app.edit_buffer = String::new();
            } else {
                app.edit_buffer = app.user_added.join(", ");
            }
        }
        _ => {}
    }
}

fn apply_edit_buffer(app: &mut AppState) {
    match app.preflight_focus {
        PreflightField::EnvWallpaperDirOverride => {
            app.preflight.wallpaper_dir = app.edit_buffer.clone();
            app.edit_kind = EditKind::None;
        }
        PreflightField::AddPackages => {
            // Parse list, dedupe, and classify via pacman/yay availability
            let raw = app.edit_buffer.clone();
            let mut names: Vec<String> = raw
                .split(',')
                .filter(|s| !s.trim().is_empty())
                .map(|s| s.trim().to_string())
                .collect();
            names.sort();
            names.dedup();

            if app.add_packages_append_mode {
                // Append-only: keep existing user_added, add new valid ones only
                for name in names {
                    if app.user_added.contains(&name) {
                        continue;
                    }
                    if is_role_controlled_package(app, &name) {
                        app.push_log_line(format!(
                            "Package '{name}' is managed by its application role; ignored"
                        ));
                        continue;
                    }
                    if app.pacman_sel_map.contains_key(&name) {
                        if let Some(v) = app.pacman_sel_map.get_mut(&name) {
                            *v = true;
                        }
                        app.push_log_line(format!(
                            "Package '{}' already in pacman list; set selected",
                            name
                        ));
                        continue;
                    }
                    if app.aur_sel_map.contains_key(&name) {
                        if let Some(v) = app.aur_sel_map.get_mut(&name) {
                            *v = true;
                        }
                        app.push_log_line(format!(
                            "Package '{}' already in AUR list; set selected",
                            name
                        ));
                        continue;
                    }
                    let Some(source) = classify_package(&name) else {
                        app.push_log_line(format!(
                            "Skipping unknown package '{}': not found in pacman or AUR",
                            name
                        ));
                        continue;
                    };
                    app.user_added_src
                        .insert(name.clone(), source.as_str().to_string());
                    app.user_added.push(name);
                }
            } else {
                // Replace mode: rebuild list exactly from current input
                let mut new_user_added: Vec<String> = Vec::new();
                let mut new_user_added_src: HashMap<String, String> = HashMap::new();
                for name in names {
                    if is_role_controlled_package(app, &name) {
                        app.push_log_line(format!(
                            "Package '{name}' is managed by its application role; ignored"
                        ));
                        continue;
                    }
                    if app.pacman_sel_map.contains_key(&name) {
                        if let Some(v) = app.pacman_sel_map.get_mut(&name) {
                            *v = true;
                        }
                        app.push_log_line(format!(
                            "Package '{}' already in pacman list; set selected",
                            name
                        ));
                        continue;
                    }
                    if app.aur_sel_map.contains_key(&name) {
                        if let Some(v) = app.aur_sel_map.get_mut(&name) {
                            *v = true;
                        }
                        app.push_log_line(format!(
                            "Package '{}' already in AUR list; set selected",
                            name
                        ));
                        continue;
                    }
                    let Some(source) = classify_package(&name) else {
                        app.push_log_line(format!(
                            "Skipping unknown package '{}': not found in pacman or AUR",
                            name
                        ));
                        continue;
                    };
                    new_user_added_src.insert(name.clone(), source.as_str().to_string());
                    new_user_added.push(name);
                }
                app.user_added = new_user_added;
                app.user_added_src = new_user_added_src;
            }
            app.edit_kind = EditKind::None;
            app.add_packages_append_mode = false; // reset
        }
        PreflightField::EnvMonitorConfig => {
            // When using wizard, saving is handled by 's' key; keep here for text fallback
            if app.edit_kind == EditKind::Text {
                app.preflight.monitor_config = app.edit_buffer.clone();
            }
            app.edit_kind = EditKind::None;
        }
        PreflightField::Password => {
            app.preflight.password = app.edit_buffer.clone();
            app.edit_kind = EditKind::None;
        }
        _ => {}
    }
}

fn discover_hypr_monitors() -> Vec<MonitorInfo> {
    // Best-effort discovery:
    // 1) hyprctl monitors (when Hyprland is running)
    // 2) xrandr --query (works before Hyprland is installed; includes Virtual-* outputs)
    // 3) DRM sysfs connectors (last resort; names like card0-DP-1)
    if let Some(text) = try_cmd_text(
        &[
            std::env::var("HYPRCTL").ok(),
            Some("hyprctl".to_string()),
            Some("/usr/sbin/hyprctl".to_string()),
            Some("/usr/local/sbin/hyprctl".to_string()),
            Some("/usr/local/bin/hyprctl".to_string()),
        ],
        &["monitors"],
    ) {
        let mons = parse_hyprctl_monitors(&text);
        if !mons.is_empty() {
            return mons;
        }
    }

    if let Some(text) = try_cmd_text(
        &[
            std::env::var("XRANDR").ok(),
            Some("xrandr".to_string()),
            Some("/usr/bin/xrandr".to_string()),
            Some("/usr/sbin/xrandr".to_string()),
        ],
        &["--query"],
    ) {
        let mons = parse_xrandr_monitors(&text);
        if !mons.is_empty() {
            return mons;
        }
    }

    discover_drm_connectors()
}

fn show_info(app: &mut AppState, title: &str, lines: Vec<String>) {
    app.info_title = title.to_string();
    app.info_lines = lines;
    app.editing = true;
    app.edit_kind = EditKind::Info;
}

fn monitor_setup_availability() -> (bool, Vec<String>) {
    let has_hyprctl = has_any_cmd(&[
        std::env::var("HYPRCTL").ok(),
        Some("hyprctl".to_string()),
        Some("/usr/sbin/hyprctl".to_string()),
        Some("/usr/local/sbin/hyprctl".to_string()),
        Some("/usr/local/bin/hyprctl".to_string()),
    ]);
    let has_xrandr = has_any_cmd(&[
        std::env::var("XRANDR").ok(),
        Some("xrandr".to_string()),
        Some("/usr/bin/xrandr".to_string()),
        Some("/usr/sbin/xrandr".to_string()),
    ]);
    let has_drm = fs::read_dir("/sys/class/drm")
        .ok()
        .and_then(|mut it| it.next().transpose().ok().flatten())
        .is_some();

    let available = has_hyprctl || has_xrandr || has_drm;
    if available {
        return (true, Vec::new());
    }

    let mut lines = vec![
        "Monitor setup wizard is unavailable because no monitor discovery backend was found."
            .to_string(),
        "".to_string(),
        "Install one of these tools and restart the TUI:".to_string(),
        "- xrandr (Xorg)".to_string(),
        "- hyprctl (Hyprland)".to_string(),
        "".to_string(),
        "If you are in a very minimal/container environment, also ensure `/sys/class/drm` is available."
            .to_string(),
    ];
    // Keep popup reasonably short on small terminals
    if lines.len() > 10 {
        lines.truncate(10);
    }
    (false, lines)
}

fn has_any_cmd(candidates: &[Option<String>]) -> bool {
    candidates
        .iter()
        .flatten()
        .cloned()
        .any(|c| Command::new(c).arg("--version").output().is_ok())
}

fn startup_prereq_warnings(app: &AppState) -> Vec<String> {
    let mut missing: Vec<String> = Vec::new();

    if !has_any_cmd(&[
        std::env::var("BASH").ok(),
        Some("bash".to_string()),
        Some("/usr/bin/bash".to_string()),
    ]) {
        missing.push("bash".to_string());
    }

    if !has_any_cmd(&[
        std::env::var("SCRIPT").ok(),
        Some("script".to_string()),
        Some("/usr/bin/script".to_string()),
        Some("/usr/sbin/script".to_string()),
    ]) {
        missing.push("script (util-linux)".to_string());
    }

    // setup.sh uses sudo heavily; without it the install flow can't work.
    if !has_any_cmd(&[
        std::env::var("SUDO").ok(),
        Some("sudo".to_string()),
        Some("/usr/bin/sudo".to_string()),
    ]) {
        missing.push("sudo".to_string());
    }

    if app.setup_script.is_none() {
        missing.push("setup.sh (not found)".to_string());
    }
    if let Some(error) = &app.package_load_error {
        missing.push(format!("packages.json ({error})"));
    }

    if missing.is_empty() {
        return Vec::new();
    }

    let mut lines = vec![
        "Some required tools/files are missing; parts of the TUI/setup will not work.".to_string(),
        "".to_string(),
        "Missing:".to_string(),
    ];
    for m in missing {
        lines.push(format!("- {}", m));
    }
    lines.push("".to_string());
    lines.push("Install the missing tools and restart the TUI.".to_string());
    lines
}

fn try_cmd_text(candidates: &[Option<String>], args: &[&str]) -> Option<String> {
    for cand in candidates.iter().flatten() {
        match Command::new(cand).args(args).output() {
            Ok(out) if out.status.success() => {
                return Some(String::from_utf8_lossy(&out.stdout).to_string());
            }
            _ => continue,
        }
    }
    None
}

fn parse_hyprctl_monitors(text: &str) -> Vec<MonitorInfo> {
    let mut monitors: Vec<MonitorInfo> = Vec::new();
    let mut current: Option<MonitorInfo> = None;
    for line in text.lines() {
        let l = line.trim_start();
        if let Some(rest) = l.strip_prefix("Monitor ") {
            if let Some(mi) = current.take() {
                monitors.push(mi);
            }
            let name = rest
                .split_whitespace()
                .next()
                .unwrap_or("")
                .trim_end_matches([':', ','])
                .to_string();
            current = Some(MonitorInfo {
                name,
                modes: Vec::new(),
            });
        } else if l.starts_with("availableModes:")
            && let Some(mi) = current.as_mut()
        {
            let modes_str = l.split_once(':').map(|x| x.1).unwrap_or("").trim();
            let mut parsed: Vec<String> = modes_str
                .split_whitespace()
                .filter(|s| s.contains('x'))
                .map(|s| s.trim_matches(',').to_string())
                .collect();
            parsed.sort_by(|a, b| compare_modes_by_aspect_then_size(a, b));
            mi.modes = parsed;
        }
    }
    if let Some(mi) = current.take() {
        monitors.push(mi);
    }
    monitors
}

fn parse_xrandr_monitors(text: &str) -> Vec<MonitorInfo> {
    let mut out: Vec<MonitorInfo> = Vec::new();
    let mut current_name: Option<String> = None;
    let mut current_modes: Vec<String> = Vec::new();

    fn flush(
        out: &mut Vec<MonitorInfo>,
        current_name: &mut Option<String>,
        current_modes: &mut Vec<String>,
    ) {
        if let Some(name) = current_name.take() {
            let mut modes = std::mem::take(current_modes);
            modes.dedup();
            if modes.is_empty() {
                modes.push("<unknown>".to_string());
            }
            out.push(MonitorInfo { name, modes });
        }
    }

    for line in text.lines() {
        let l = line.trim_end();
        if !l.starts_with(' ') && !l.starts_with('\t') && l.contains(" connected") {
            flush(&mut out, &mut current_name, &mut current_modes);
            let name = l.split_whitespace().next().unwrap_or("").to_string();
            current_name = Some(name);
            continue;
        }

        if current_name.is_some() {
            let lt = l.trim_start();
            if let Some(tok) = lt.split_whitespace().next()
                && tok.contains('x')
                && tok
                    .chars()
                    .next()
                    .map(|c| c.is_ascii_digit())
                    .unwrap_or(false)
            {
                let hz = lt
                    .split_whitespace()
                    .nth(1)
                    .unwrap_or("")
                    .trim_end_matches(['*', '+']);
                if !hz.is_empty()
                    && hz
                        .chars()
                        .next()
                        .map(|c| c.is_ascii_digit())
                        .unwrap_or(false)
                {
                    current_modes.push(format!("{}@{}", tok, hz));
                } else {
                    current_modes.push(tok.to_string());
                }
            };
        }
    }
    flush(&mut out, &mut current_name, &mut current_modes);

    for mi in out.iter_mut() {
        let mut parsed = std::mem::take(&mut mi.modes);
        parsed.retain(|m| !m.is_empty());
        parsed.sort_by(|a, b| compare_modes_by_aspect_then_size(a, b));
        parsed.dedup();
        mi.modes = parsed;
    }
    out
}

fn discover_drm_connectors() -> Vec<MonitorInfo> {
    let mut out: Vec<MonitorInfo> = Vec::new();
    let Ok(entries) = fs::read_dir("/sys/class/drm") else {
        return out;
    };
    for ent in entries.flatten() {
        let name = ent.file_name().to_string_lossy().to_string();
        if !name.starts_with("card") || !name.contains('-') {
            continue;
        }
        let status_path = ent.path().join("status");
        let Ok(status) = fs::read_to_string(status_path) else {
            continue;
        };
        if status.trim() != "connected" {
            continue;
        }
        let pretty = name
            .split_once('-')
            .map(|x| x.1)
            .unwrap_or(&name)
            .to_string();
        out.push(MonitorInfo {
            name: pretty,
            modes: vec!["<unknown>".to_string()],
        });
    }
    out.sort_by(|a, b| a.name.cmp(&b.name));
    out.dedup_by(|a, b| a.name == b.name);
    out
}

fn aspect_ratio_label(mode: &str) -> Option<String> {
    // Expect formats like "2560x1440@144" or "1920x1080"
    let res_part = mode.split('@').next()?;
    let mut it = res_part.split('x');
    let w: i64 = it.next()?.parse().ok()?;
    let h: i64 = it.next()?.parse().ok()?;
    if w == 0 || h == 0 {
        return None;
    }
    let g = gcd_i64(w, h);
    Some(format!("{}:{}", w / g, h / g))
}

fn gcd_i64(mut a: i64, mut b: i64) -> i64 {
    while b != 0 {
        let t = b;
        b = a % b;
        a = t;
    }
    a.abs()
}

fn compare_modes_by_aspect_then_size(a: &str, b: &str) -> std::cmp::Ordering {
    use std::cmp::Ordering;
    let (aw, ah, ar) = parse_mode_numbers(a);
    let (bw, bh, br) = parse_mode_numbers(b);

    let apr = ratio_priority(&ar);
    let bpr = ratio_priority(&br);
    match apr.cmp(&bpr) {
        Ordering::Equal => match bw.cmp(&aw) {
            // width desc
            Ordering::Equal => match bh.cmp(&ah) {
                // height desc
                Ordering::Equal => a.cmp(b),
                other => other,
            },
            other => other,
        },
        other => other,
    }
}

fn parse_mode_numbers(mode: &str) -> (u32, u32, String) {
    let res_part = mode.split('@').next().unwrap_or("");
    let mut it = res_part.split('x');
    let w: u32 = it.next().and_then(|s| s.parse().ok()).unwrap_or(0);
    let h: u32 = it.next().and_then(|s| s.parse().ok()).unwrap_or(0);
    let ratio = aspect_ratio_label(mode).unwrap_or_default();
    (w, h, ratio)
}

fn ratio_priority(r: &str) -> u32 {
    match r {
        "16:9" => 0,
        "16:10" => 1,
        "21:9" => 2,
        "32:9" => 3,
        "4:3" => 4,
        "5:4" => 5,
        _ => 100,
    }
}

fn strip_ansi_sequences(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut iter = s.chars().peekable();
    while let Some(ch) = iter.next() {
        if ch == '\u{1b}' {
            match iter.next() {
                Some('[') => {
                    for c in iter.by_ref() {
                        if ('@'..='~').contains(&c) {
                            break;
                        }
                    }
                }
                // OSC includes sudo/systemd session metadata, not printable output.
                Some(']' | 'P' | '^' | '_') => {
                    while let Some(c) = iter.next() {
                        if c == '\u{7}' {
                            break;
                        }
                        if c == '\u{1b}' && iter.peek() == Some(&'\\') {
                            iter.next();
                            break;
                        }
                    }
                }
                Some(' '..='/') => {
                    for c in iter.by_ref() {
                        if ('0'..='~').contains(&c) {
                            break;
                        }
                    }
                }
                _ => {}
            }
        } else if !ch.is_control() || matches!(ch, '\t' | '\n' | '\r') {
            out.push(ch);
        }
    }
    out
}

fn format_duration(d: Duration) -> String {
    let secs = d.as_secs();
    let ms = d.subsec_millis();
    let h = secs / 3600;
    let m = (secs % 3600) / 60;
    let s = secs % 60;
    if h > 0 {
        format!("{}h {:02}m {:02}.{:03}s", h, m, s, ms)
    } else if m > 0 {
        format!("{}m {:02}.{:03}s", m, s, ms)
    } else {
        format!("{}.{:03}s", s, ms)
    }
}

fn normalized_section_title(title: &str) -> String {
    title
        .split_whitespace()
        .map(str::to_lowercase)
        .collect::<Vec<_>>()
        .join(" ")
}

fn update_sections_from_line(app: &mut AppState, raw_line: &str) {
    // Detect headings like "=== Step ===" or "========= Step ========="
    let clean_line = strip_ansi_sequences(raw_line);
    let trimmed = clean_line.trim();
    let is_heading = (trimmed.starts_with("=== ") && trimmed.ends_with(" ==="))
        || (trimmed.starts_with("=========") && trimmed.ends_with("========="));
    if is_heading {
        // Extract title without '=' and spaces
        let title = trimmed.trim_matches('=').trim().to_string();
        // Mark previous as done
        if let Some(idx) = app.current_section
            && let Some(prev) = app.sections.get_mut(idx)
        {
            prev.done = true;
        }
        // Match case- and whitespace-insensitively so display-only shell changes do not
        // create a new progress step and change the denominator during a run.
        let normalized_title = normalized_section_title(&title);
        if let Some(pos) = app
            .sections
            .iter()
            .position(|section| normalized_section_title(&section.title) == normalized_title)
        {
            app.current_section = Some(pos);
        } else {
            app.sections.push(SetupSection {
                title: title.clone(),
                done: false,
                severity: StepSeverity::None,
            });
            app.current_section = Some(app.sections.len() - 1);
        }
        return;
    }

    // Check for warnings/errors and annotate current section.
    let sev = output_line_severity(trimmed);
    if sev != StepSeverity::None
        && let Some(idx) = app.current_section
        && let Some(sec) = app.sections.get_mut(idx)
    {
        // Upgrade severity if needed (Error overrides Warning)
        match (sec.severity, sev) {
            (StepSeverity::Error, _) => {}
            (StepSeverity::Warning, StepSeverity::Error) => sec.severity = StepSeverity::Error,
            (StepSeverity::None, s) => sec.severity = s,
            _ => {}
        }
    }

    // Summary markers that imply completion
    if (trimmed.contains("All configurations completed successfully!")
        || trimmed.contains("Hyprland setup completed successfully!"))
        && let Some(idx) = app.current_section
    {
        if let Some(prev) = app.sections.get_mut(idx) {
            prev.done = true;
        }
        app.current_section = None;
    }
}

fn shell_function_name(line: &str) -> Option<String> {
    let declaration = line.trim().strip_suffix('{')?.trim_end();
    let name = declaration.strip_suffix("()")?.trim();
    if name.is_empty()
        || !name
            .chars()
            .all(|ch| ch == '_' || ch.is_ascii_alphanumeric())
    {
        return None;
    }
    Some(name.to_string())
}

fn literal_step_title(line: &str) -> Option<String> {
    let trimmed = line.trim();
    for prefix in ["announce_step \"", "extended_announce_step \""] {
        if let Some(rest) = trimmed.strip_prefix(prefix)
            && let Some(end) = rest.find('"')
        {
            return Some(rest[..end].to_string());
        }
    }

    // Some legacy steps, such as Installation Summary, print the same heading directly.
    let heading_start = trimmed.find("========= ")? + "========= ".len();
    let rest = &trimmed[heading_start..];
    let heading_end = rest.find(" =========")?;
    let title = rest[..heading_end].trim();
    (!title.is_empty()).then(|| title.to_string())
}

fn push_unique_section(sections: &mut Vec<SetupSection>, title: String) {
    if sections.iter().any(|section| section.title == title) {
        return;
    }
    sections.push(SetupSection {
        title,
        done: false,
        severity: StepSeverity::None,
    });
}

fn preload_sections_from_script(script_path: &PathBuf) -> Vec<SetupSection> {
    let Ok(content) = fs::read_to_string(script_path) else {
        return Vec::new();
    };
    let lines: Vec<&str> = content.lines().collect();
    let function_starts: Vec<(String, usize)> = lines
        .iter()
        .enumerate()
        .filter_map(|(index, line)| shell_function_name(line).map(|name| (name, index)))
        .collect();

    use std::collections::HashMap;
    let function_ranges: HashMap<String, (usize, usize)> = function_starts
        .iter()
        .enumerate()
        .map(|(position, (name, start))| {
            let end = function_starts
                .get(position + 1)
                .map(|(_, next_start)| *next_start)
                .unwrap_or(lines.len());
            (name.clone(), (*start + 1, end))
        })
        .collect();

    let Some(&(main_start, main_end)) = function_ranges.get("main") else {
        return Vec::new();
    };
    let mut sections = Vec::new();
    for line in &lines[main_start..main_end] {
        let trimmed = line.trim();
        if let Some(title) = literal_step_title(trimmed) {
            push_unique_section(&mut sections, title);
            continue;
        }

        let called_function = trimmed.split_whitespace().next().unwrap_or("");
        let Some(&(function_start, function_end)) = function_ranges.get(called_function) else {
            continue;
        };
        if let Some(title) = lines[function_start..function_end]
            .iter()
            .find_map(|function_line| literal_step_title(function_line))
        {
            push_unique_section(&mut sections, title);
        }
    }
    sections
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn completion_prompt_renders_without_input_and_handles_keys_over_either_screen() {
        let (tx, rx) = mpsc::channel();
        let script = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("setup.sh");
        let mut app = AppState::new(rx, tx, Some(script));
        let mut terminal = Terminal::new(ratatui::backend::TestBackend::new(120, 40)).unwrap();

        for mode in [UiMode::Menu, UiMode::Preflight] {
            for cancel in [KeyCode::Char('n'), KeyCode::Esc, KeyCode::Char('q')] {
                app.ui_mode = mode;
                app.editing = true;
                app.edit_kind = EditKind::ConfirmReboot;
                terminal.draw(|frame| draw_ui(frame, &mut app)).unwrap();
                let screen: String = terminal
                    .backend()
                    .buffer()
                    .content
                    .iter()
                    .map(|cell| cell.symbol())
                    .collect();
                assert!(screen.contains("Setup Complete"));
                assert!(screen.contains("Do you want to Reboot to finish the Setup?"));
                assert!(screen.contains("Enter/Y: reboot   N/Esc: cancel"));

                // An unrelated key must not reach the underlying installer screen.
                let key = KeyEvent::new(KeyCode::Char('v'), event::KeyModifiers::NONE);
                assert!(!handle_key_event(&mut app, key).unwrap());
                assert!(!app.logs.show_details);
                assert_eq!(app.edit_kind, EditKind::ConfirmReboot);

                let key = KeyEvent::new(cancel, event::KeyModifiers::NONE);
                assert!(!handle_key_event(&mut app, key).unwrap());
                assert!(!app.editing);
                assert_eq!(app.edit_kind, EditKind::None);
                assert_eq!(app.ui_mode, mode);
                terminal.draw(|frame| draw_ui(frame, &mut app)).unwrap();
                let screen: String = terminal
                    .backend()
                    .buffer()
                    .content
                    .iter()
                    .map(|cell| cell.symbol())
                    .collect();
                assert!(!screen.contains("Setup Complete"));
            }
        }
    }

    fn open_application_role(app: &mut AppState, role: &str) {
        let key = |code| KeyEvent::new(code, event::KeyModifiers::NONE);
        if !app.editing {
            app.preflight_focus = PreflightField::Applications;
            handle_preflight_keys(app, key(KeyCode::Enter)).unwrap();
        }
        assert_eq!(app.edit_kind, EditKind::SelectApplications);
        handle_preflight_keys(app, key(KeyCode::Home)).unwrap();
        for _ in 0..ROLE_ORDER.iter().position(|name| *name == role).unwrap() {
            handle_preflight_keys(app, key(KeyCode::Down)).unwrap();
        }
        handle_preflight_keys(app, key(KeyCode::Enter)).unwrap();
        assert_eq!(app.edit_kind, EditKind::SelectRole);
    }

    fn render_app_screen(app: &mut AppState, width: u16, height: u16) -> String {
        let mut terminal =
            Terminal::new(ratatui::backend::TestBackend::new(width, height)).unwrap();
        terminal.draw(|frame| draw_ui(frame, app)).unwrap();
        terminal
            .backend()
            .buffer()
            .content
            .iter()
            .map(|cell| cell.symbol())
            .collect()
    }

    #[test]
    fn preflight_shows_one_applications_entry_instead_of_individual_roles() {
        let (tx, rx) = mpsc::channel();
        let script = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("setup.sh");
        let mut app = AppState::new(rx, tx, Some(script));
        app.ui_mode = UiMode::Preflight;
        let screen = render_app_screen(&mut app, 120, 24);
        assert_eq!(screen.matches("Applications").count(), 1);
        assert!(screen.contains("14 groups"));
        assert!(screen.contains("Start unattended install"));
        for label in [
            "Browser",
            "Notifications",
            "TUI editor",
            "GUI editor",
            "Launcher",
        ] {
            assert!(!screen.contains(label));
        }
        assert!(!screen.contains("zen-browser-bin"));
        assert!(!screen.contains("(primary)"));

        app.preflight_focus = PreflightField::EnvFishLanguageChoiceOverride;
        preflight_focus_next(&mut app);
        assert_eq!(app.preflight_focus, PreflightField::Applications);
        preflight_focus_next(&mut app);
        assert_eq!(app.preflight_focus, PreflightField::EnvWallpaperDirOverride);
        preflight_focus_prev(&mut app);
        assert_eq!(app.preflight_focus, PreflightField::Applications);
        preflight_focus_prev(&mut app);
        assert_eq!(
            app.preflight_focus,
            PreflightField::EnvFishLanguageChoiceOverride
        );
    }

    #[test]
    fn applications_submenu_reaches_every_role_and_returns_one_level_at_a_time() {
        let (tx, rx) = mpsc::channel();
        let script = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("setup.sh");
        let mut app = AppState::new(rx, tx, Some(script));
        app.ui_mode = UiMode::Preflight;
        app.preflight_focus = PreflightField::Applications;
        let key = |code| KeyEvent::new(code, event::KeyModifiers::NONE);
        handle_preflight_keys(&mut app, key(KeyCode::Enter)).unwrap();
        let screen = render_app_screen(&mut app, 120, 30);
        assert!(screen.contains("Browser"));
        assert!(screen.contains("Launcher"));
        assert!(screen.contains("zen-browser-bin (primary)"));
        let original = app.role_selection.clone();

        for (index, role) in ROLE_ORDER.into_iter().enumerate() {
            assert_eq!(selected_application_role(&app), Some(role));
            handle_preflight_keys(&mut app, key(KeyCode::Enter)).unwrap();
            assert_eq!(app.edit_kind, EditKind::SelectRole);
            let label = app.package_registry.as_ref().unwrap().roles[role]
                .label
                .clone();
            assert!(render_app_screen(&mut app, 120, 30).contains(&label));
            let back = [KeyCode::Esc, KeyCode::Enter, KeyCode::Char('q')][index % 3];
            handle_preflight_keys(&mut app, key(back)).unwrap();
            assert!(app.editing);
            assert_eq!(app.edit_kind, EditKind::SelectApplications);
            assert_eq!(app.application_cursor, index);
            handle_preflight_keys(&mut app, key(KeyCode::Down)).unwrap();
        }
        assert_eq!(app.application_cursor, 0);
        assert_eq!(app.role_selection, original);
        handle_preflight_keys(&mut app, key(KeyCode::Up)).unwrap();
        assert_eq!(app.application_cursor, ROLE_ORDER.len() - 1);
        for back in [KeyCode::Esc, KeyCode::Char('q')] {
            handle_preflight_keys(&mut app, key(back)).unwrap();
            assert!(!app.editing);
            assert_eq!(app.edit_kind, EditKind::None);
            assert_eq!(app.preflight_focus, PreflightField::Applications);
            handle_preflight_keys(&mut app, key(KeyCode::Enter)).unwrap();
            assert_eq!(app.application_cursor, ROLE_ORDER.len() - 1);
        }
    }

    #[test]
    fn applications_submenu_scrolls_selected_groups_into_small_viewports() {
        let (tx, rx) = mpsc::channel();
        let script = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("setup.sh");
        let mut app = AppState::new(rx, tx, Some(script));
        app.ui_mode = UiMode::Preflight;
        app.preflight_focus = PreflightField::Applications;
        let key = |code| KeyEvent::new(code, event::KeyModifiers::NONE);
        handle_preflight_keys(&mut app, key(KeyCode::Enter)).unwrap();
        for role in ROLE_ORDER {
            let label = app.package_registry.as_ref().unwrap().roles[role]
                .label
                .clone();
            assert!(render_app_screen(&mut app, 60, 10).contains(&label));
            handle_preflight_keys(&mut app, key(KeyCode::Down)).unwrap();
        }
        handle_preflight_keys(&mut app, key(KeyCode::End)).unwrap();
        assert_eq!(selected_application_role(&app), Some("agent"));
        handle_preflight_keys(&mut app, key(KeyCode::Home)).unwrap();
        assert_eq!(selected_application_role(&app), Some("browser"));
    }

    fn render_choice_lines(
        app: &AppState,
        width: u16,
        height: u16,
        group_list: bool,
    ) -> Vec<String> {
        let mut terminal =
            Terminal::new(ratatui::backend::TestBackend::new(width, height)).unwrap();
        terminal
            .draw(|frame| {
                if group_list {
                    draw_applications_menu(frame, app, frame.area());
                } else {
                    draw_role_menu(frame, app, frame.area());
                }
            })
            .unwrap();
        terminal
            .backend()
            .buffer()
            .content
            .chunks(usize::from(width.max(1)))
            .map(|row| row.iter().map(|cell| cell.symbol()).collect())
            .collect()
    }

    fn render_choice_screen(app: &AppState, width: u16, height: u16, group_list: bool) -> String {
        let rows = render_choice_lines(app, width, height, group_list);
        let mut text = rows.join(" ");
        if !group_list
            && let Some((header_y, header)) = rows
                .iter()
                .enumerate()
                .find(|(_, row)| row.contains("Description"))
        {
            let column = header[..header.find("Description").unwrap()]
                .chars()
                .count();
            // Read wrapped descriptions vertically, without interleaving wrapped app-name cells.
            for row in rows
                .iter()
                .skip(header_y + 1)
                .take_while(|row| !row.contains('└') && !row.contains("Enter/Esc"))
            {
                text.push(' ');
                text.extend(row.chars().skip(column));
            }
        }
        text.chars()
            .map(|ch| match ch {
                '│' | '─' | '┌' | '┐' | '└' | '┘' | '▶' => ' ',
                ch => ch,
            })
            .collect::<String>()
            .split_whitespace()
            .collect::<Vec<_>>()
            .join(" ")
    }

    #[test]
    fn role_menu_separates_type_help_and_aligns_name_description_columns() {
        let (tx, rx) = mpsc::channel();
        let script = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("setup.sh");
        let mut app = AppState::new(rx, tx, Some(script));
        app.application_cursor = ROLE_ORDER
            .iter()
            .position(|role| *role == "gui_editor")
            .unwrap();
        app.role_cursor = 1;
        let rows = render_choice_lines(&app, 120, 32, false);
        let about_y = rows
            .iter()
            .position(|row| row.contains("About GUI editor"))
            .unwrap();
        assert!(rows[about_y].contains('┌') && rows[about_y].contains('┐'));
        assert!(rows[about_y + 1].contains("Edits text and code in a graphical window."));
        let about_bottom = rows
            .iter()
            .enumerate()
            .skip(about_y + 1)
            .find(|(_, row)| row.contains('└'))
            .unwrap()
            .0;
        assert!(rows[about_bottom].contains('┘'));
        assert!(
            rows[about_bottom + 1]
                .chars()
                .all(|ch| ch == ' ' || ch == '│')
        );
        assert!(rows[about_bottom + 2].contains("Choices"));
        let header_y = rows
            .iter()
            .position(|row| row.contains("Description"))
            .unwrap();
        assert_eq!(header_y, about_bottom + 3);
        let column = |row: &str, word: &str| row[..row.find(word).unwrap()].chars().count();
        let name_x = column(&rows[header_y], "App");
        let description_x = column(&rows[header_y], "Description");
        assert!(description_x > name_x + 20);
        let zed_row = rows
            .iter()
            .find(|row| row.contains("zed [pacman]"))
            .unwrap();
        assert_eq!(column(zed_row, "[ ] zed"), name_x);
        assert_eq!(column(zed_row, "GPU-rendered"), description_x);
        assert!(zed_row.contains('▶'));
        let none_row = rows.iter().find(|row| row.contains("[ ] None")).unwrap();
        assert_eq!(column(none_row, "Skip GUI editors"), description_x);
    }

    #[test]
    fn every_application_type_and_package_has_descriptive_help() {
        let (tx, rx) = mpsc::channel();
        let script = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("setup.sh");
        let mut app = AppState::new(rx, tx, Some(script));
        for (index, role_name) in ROLE_ORDER.into_iter().enumerate() {
            app.application_cursor = index;
            let description = application_type_description(role_name);
            assert!(description.len() > 40);
            assert!(!description.starts_with("Select the applications"));
            let screen = render_choice_screen(&app, 100, 24, true);
            assert!(
                screen.contains(description),
                "type description hidden for {role_name}: {screen}"
            );
            for option in &app.package_registry.as_ref().unwrap().roles[role_name].options {
                let description = &app.pkg_descs[&option.package];
                assert!(
                    description.len() >= 50 && description.len() <= 160,
                    "{} needs a concise differentiating description",
                    option.package
                );
            }
        }
    }

    #[test]
    fn all_choices_and_descriptions_fit_when_terminal_height_permits() {
        let (tx, rx) = mpsc::channel();
        let script = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("setup.sh");
        let mut app = AppState::new(rx, tx, Some(script));
        for (width, height) in [(80, 40), (120, 24)] {
            for (index, role_name) in ROLE_ORDER.into_iter().enumerate() {
                app.application_cursor = index;
                let role = &app.package_registry.as_ref().unwrap().roles[role_name];
                let screen = render_choice_screen(&app, width, height, false);
                assert!(screen.contains(application_type_description(role_name)));
                if !role.required {
                    assert!(screen.contains("None"));
                }
                for option in &role.options {
                    assert!(
                        screen.contains(&option.package),
                        "choice {} clipped at {width}x{height}",
                        option.package
                    );
                    assert!(
                        screen.contains(&app.pkg_descs[&option.package]),
                        "description for {} clipped at {width}x{height}: {screen}",
                        option.package
                    );
                }
            }
        }
    }

    #[test]
    fn short_choosers_keep_every_focused_choice_description_visible() {
        let (tx, rx) = mpsc::channel();
        let script = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("setup.sh");
        let mut app = AppState::new(rx, tx, Some(script));
        app.editing = true;
        app.edit_kind = EditKind::SelectRole;
        let key = |code| KeyEvent::new(code, event::KeyModifiers::NONE);
        for (index, role_name) in ROLE_ORDER.into_iter().enumerate() {
            app.application_cursor = index;
            let role = &app.package_registry.as_ref().unwrap().roles[role_name];
            let optional = !role.required;
            let packages: Vec<_> = role.options.iter().map(|o| o.package.clone()).collect();
            app.role_cursor = usize::from(optional);
            for package in &packages {
                let screen = render_choice_screen(&app, 60, 10, false);
                assert!(screen.contains(package));
                assert!(
                    screen.contains(&app.pkg_descs[package]),
                    "focused description for {package} clipped: {screen}"
                );
                assert!(screen.contains("scroll"));
                handle_preflight_keys(&mut app, key(KeyCode::Down)).unwrap();
            }
            handle_preflight_keys(&mut app, key(KeyCode::End)).unwrap();
            assert_eq!(app.role_cursor, packages.len() - 1 + usize::from(optional));
            assert!(render_choice_screen(&app, 60, 10, false).contains(packages.last().unwrap()));
            handle_preflight_keys(&mut app, key(KeyCode::Home)).unwrap();
            assert_eq!(app.role_cursor, 0);
            if optional {
                assert!(render_choice_screen(&app, 60, 10, false).contains("None"));
            }
        }
    }

    #[test]
    fn choice_layout_stays_within_tiny_terminal_bounds() {
        let (tx, rx) = mpsc::channel();
        let script = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("setup.sh");
        let app = AppState::new(rx, tx, Some(script));
        for (width, height) in [(0, 0), (1, 1), (20, 4), (40, 8)] {
            let area = Rect::new(0, 0, width, height);
            let (popup, rows) = choice_popup_layout(area, [3, 18, 2], 4);
            assert!(popup.right() <= area.right() && popup.bottom() <= area.bottom());
            assert!(
                rows.iter()
                    .all(|row| row.right() <= popup.right() && row.bottom() <= popup.bottom())
            );
            render_choice_screen(&app, width, height, false);
            render_choice_screen(&app, width, height, true);
        }
    }

    #[test]
    fn choice_descriptions_wrap_long_words_without_losing_text() {
        assert_eq!(
            wrap_choice_description("abcdefghij next", 4),
            ["abcd", "efgh", "ij", "next"]
        );
        assert!(wrap_choice_description("text", 0).is_empty());
        assert_eq!(
            wrap_choice_description("a  short   sentence", 40),
            ["a short sentence"]
        );
    }

    #[test]
    fn role_popup_edits_membership_primary_and_single_choice_independently() {
        let (tx, rx) = mpsc::channel();
        let script = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("setup.sh");
        let mut app = AppState::new(rx, tx, Some(script));
        let key = |code| KeyEvent::new(code, event::KeyModifiers::NONE);

        open_application_role(&mut app, "terminal");
        assert_eq!(app.edit_kind, EditKind::SelectRole);
        handle_preflight_keys(&mut app, key(KeyCode::Down)).unwrap();
        handle_preflight_keys(&mut app, key(KeyCode::Char(' '))).unwrap();
        handle_preflight_keys(&mut app, key(KeyCode::Char('p'))).unwrap();
        let selection = app.role_selection.as_ref().unwrap();
        assert_eq!(selection.selected_package("terminal"), Some("alacritty"));
        assert_eq!(
            selection.selected_packages("terminal").unwrap(),
            &BTreeSet::from(["alacritty".to_string(), "kitty".to_string()])
        );
        assert!(app.pacman_sel_map["alacritty"]);
        assert!(app.pacman_sel_map["kitty"]);

        handle_preflight_keys(&mut app, key(KeyCode::Enter)).unwrap();
        open_application_role(&mut app, "launcher");
        handle_preflight_keys(&mut app, key(KeyCode::Down)).unwrap();
        handle_preflight_keys(&mut app, key(KeyCode::Char(' '))).unwrap();
        let selection = app.role_selection.as_ref().unwrap();
        assert_eq!(selection.selected_package("launcher"), Some("rofi"));
        assert_eq!(
            selection.selected_packages("launcher").unwrap(),
            &BTreeSet::from(["rofi".to_string()])
        );
        assert!(!app.pacman_sel_map["wofi"]);
        assert!(app.pacman_sel_map["rofi"]);
    }

    #[test]
    fn optional_role_popup_exposes_none_and_required_empty_blocks_launch() {
        let (tx, rx) = mpsc::channel();
        let script = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("setup.sh");
        let mut app = AppState::new(rx, tx, Some(script));
        let key = |code| KeyEvent::new(code, event::KeyModifiers::NONE);
        open_application_role(&mut app, "dock");

        let mut terminal = Terminal::new(ratatui::backend::TestBackend::new(120, 40)).unwrap();
        terminal.draw(|frame| draw_ui(frame, &mut app)).unwrap();
        let screen: String = terminal
            .backend()
            .buffer()
            .content
            .iter()
            .map(|cell| cell.symbol())
            .collect();
        assert!(screen.contains("Dock — single choice, optional"));
        assert!(screen.contains("[*] None"));
        assert!(package_start_blocker(&app).is_none());

        handle_preflight_keys(&mut app, key(KeyCode::Enter)).unwrap();
        open_application_role(&mut app, "notifications");
        handle_preflight_keys(&mut app, key(KeyCode::Char(' '))).unwrap();
        assert_eq!(
            package_start_blocker(&app).as_deref(),
            Some("Select exactly one Notifications")
        );
    }

    #[test]
    fn generic_bulk_changes_preserve_role_membership_and_shared_package_union() {
        let (tx, rx) = mpsc::channel();
        let script = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("setup.sh");
        let mut app = AppState::new(rx, tx, Some(script));
        {
            let registry = app.package_registry.as_ref().unwrap();
            let selection = app.role_selection.as_mut().unwrap();
            selection
                .toggle_member(registry, "bar", "nwg-panel")
                .unwrap();
            selection
                .toggle_member(registry, "dock", "nwg-panel")
                .unwrap();
        }
        sync_role_package_selection(&mut app);
        set_all_package_selections(&mut app, PackageSource::Pacman, false);
        set_all_package_selections(&mut app, PackageSource::Aur, true);

        let selection = app.role_selection.as_ref().unwrap();
        assert_eq!(selection.selected_package("bar"), Some("nwg-panel"));
        assert_eq!(selection.selected_package("dock"), Some("nwg-panel"));
        assert_eq!(
            selection.selected_packages("browser").unwrap(),
            &BTreeSet::from(["zen-browser-bin".to_string()])
        );
        assert_eq!(
            selection.selected_packages("gui_editor").unwrap(),
            &BTreeSet::from(["visual-studio-code-bin".to_string()])
        );
        assert!(app.pacman_sel_map["nwg-panel"]);
        assert!(!app.aur_sel_map["brave-bin"]);
        assert!(!app.aur_sel_map["cursor-bin"]);
    }

    #[test]
    fn compact_output_hides_package_chatter_but_retains_detailed_history() {
        let lines = [
            "Install started",
            "========= Install AUR extras =========",
            "[*] Installing selected AUR packages",
            "(4/8) Installiert wird meson [########] 100%",
            "Optionale Abhängigkeiten für python-mako",
            "    python-beaker: for caching support",
            "==> Erstelle Paket: wlogout 1.2.2-0",
            "[!] Optional package skipped",
            "==> FEHLER: Ein Fehler ist aufgetreten",
            "Warnung: package is out of date",
            "error: could not build package",
        ];
        let mut log = OutputLog::default();
        for line in lines {
            log.push(format!("[2026-09-19 13:08:42] {line}"), line);
        }
        assert!(!log.show_details);
        assert_eq!(log.len(), 7);
        assert!(!log.lines().iter().any(|line| line.contains("100%")));
        assert!(log.lines().iter().any(|line| line.contains("FEHLER")));
        assert!(log.lines().iter().any(|line| line.contains("Warnung")));
        log.show_details = true;
        assert_eq!(log.len(), lines.len());
        assert!(log.lines()[3].ends_with("100%"));
    }

    #[test]
    fn compact_output_preserves_summary_details_and_resets_for_next_run() {
        let mut log = OutputLog::default();
        for line in [
            "========= Installation Summary =========",
            "Failed packages:",
            "  - example-package",
            "Configuration Status:",
            "NetworkManager: configured",
            "Recommendations:",
            "  1. Re-run failed installs",
        ] {
            log.push(line.to_string(), line);
        }
        assert_eq!(log.len(), 7);
        log.clear();
        log.push("summary continues".into(), "summary continues");
        assert_eq!(log.len(), 1);
        log.push("Install started".into(), "Install started");
        log.push("build chatter".into(), "build chatter");
        assert_eq!(log.len(), 2);
        log.show_details = true;
        assert_eq!(log.len(), 3);
        log.clear();
        assert_eq!(log.len(), 0);
        log.show_details = false;
        assert_eq!(log.len(), 0);
    }

    #[test]
    fn detailed_chatter_cannot_evict_compact_status_and_histories_are_bounded() {
        let mut log = OutputLog::default();
        log.push("[*] Starting".into(), "[*] Starting");
        for _ in 0..=OUTPUT_HISTORY_LIMIT {
            assert_eq!(log.push("build output".into(), "build output"), 0);
        }
        assert_eq!(log.lines(), &["[*] Starting"]);
        log.show_details = true;
        assert_eq!(log.len(), OUTPUT_HISTORY_LIMIT);
        assert_eq!(log.push("more output".into(), "more output"), 1);
        log.show_details = false;
        for _ in 1..OUTPUT_HISTORY_LIMIT {
            assert_eq!(log.push("[*] Status".into(), "[*] Status"), 0);
        }
        assert_eq!(log.push("[!] Warning".into(), "[!] Warning"), 1);
        assert_eq!(log.len(), OUTPUT_HISTORY_LIMIT);
    }

    #[test]
    fn compact_rendering_omits_timestamps_and_heading_decoration() {
        let theme = Theme::catppuccin_mocha();
        let heading = "[2026-09-19 13:08:42] ========= Install AUR extras =========";
        assert_eq!(
            live_output_line(theme, heading, false).to_string(),
            "Install AUR extras"
        );
        assert_eq!(live_output_line(theme, heading, true).to_string(), heading);
        let warning = live_output_line(theme, "[2026-09-19 13:08:42] [!] skipped", false);
        assert_eq!(warning.to_string(), "[!] skipped");
        assert_eq!(warning.spans[0].style.fg, Some(Color::Yellow));

        let backend = ratatui::backend::TestBackend::new(40, 4);
        let mut terminal = Terminal::new(backend).unwrap();
        terminal
            .draw(|frame| {
                let output = Paragraph::new(vec![
                    live_output_line(theme, heading, false),
                    warning.clone(),
                ]);
                frame.render_widget(output, frame.area());
            })
            .unwrap();
        let mut expected = ratatui::buffer::Buffer::with_lines([
            "Install AUR extras                      ",
            "[!] skipped                             ",
            "                                        ",
            "                                        ",
        ]);
        expected.set_style(Rect::new(0, 0, 18, 1), Style::default().fg(theme.subtext0));
        expected.set_style(
            Rect::new(0, 1, 11, 1),
            Style::default()
                .fg(Color::Yellow)
                .add_modifier(Modifier::BOLD),
        );
        terminal.backend().assert_buffer(&expected);
    }

    #[test]
    fn terminal_metadata_is_removed_without_losing_neighboring_output() {
        for terminator in ["\u{7}", "\u{1b}\\"] {
            let raw = format!(
                "before\u{1b}]3008;start=session;user=test{terminator}\u{1b}[31m[ERROR] failed\u{1b}[0m"
            );
            assert_eq!(strip_ansi_sequences(&raw), "before[ERROR] failed");
        }
        assert_eq!(
            strip_ansi_sequences("\u{1b}]8;;https://example.org\u{1b}\\link\u{1b}]8;;\u{1b}\\"),
            "link"
        );
        assert_eq!(strip_ansi_sequences("safe\u{1b}]3008;unterminated"), "safe");
        assert_eq!(strip_ansi_sequences("\u{1b}(Bplain text"), "plain text");
        assert_eq!(
            strip_ansi_sequences("hello\u{7}\u{8}\tworld"),
            "hello\tworld"
        );
        assert_eq!(
            strip_ansi_sequences("before\u{1b}Ppayload\u{1b}\\after"),
            "beforeafter"
        );
    }

    #[test]
    fn selected_preflight_row_has_color_independent_highlight() {
        let theme = Theme::catppuccin_mocha();
        let selected = preflight_row_style(theme, true);
        let idle = preflight_row_style(theme, false);

        assert!(selected.add_modifier.contains(Modifier::BOLD));
        assert!(selected.add_modifier.contains(Modifier::REVERSED));
        assert!(!idle.add_modifier.contains(Modifier::REVERSED));
    }

    #[test]
    fn spinner_advances_at_a_visible_rate() {
        assert_eq!(spinner_frame(Duration::from_millis(0)), "|");
        assert_eq!(spinner_frame(Duration::from_millis(150)), "/");
        assert_eq!(spinner_frame(Duration::from_millis(300)), "-");
        assert_eq!(spinner_frame(Duration::from_millis(450)), "\\");
        assert_eq!(spinner_frame(Duration::from_millis(600)), "|");
    }

    #[test]
    fn section_progress_counts_only_completed_steps() {
        let sections = vec![
            SetupSection {
                title: "Done".to_string(),
                done: true,
                severity: StepSeverity::None,
            },
            SetupSection {
                title: "Running".to_string(),
                done: false,
                severity: StepSeverity::None,
            },
        ];

        assert_eq!(installation_step_progress(&sections, 2), (1, 2));

        let mut sections_with_unplanned_output = sections.clone();
        sections_with_unplanned_output.push(SetupSection {
            title: "Unexpected diagnostic heading".to_string(),
            done: true,
            severity: StepSeverity::None,
        });
        assert_eq!(
            installation_step_progress(&sections_with_unplanned_output, 2),
            (1, 2)
        );
        assert_eq!(installation_percent(1, 2), 50);
        assert_eq!(ascii_progress_bar(1, 2, 5), "[==>--]");
        assert_eq!(ascii_progress_bar(2, 2, 5), "[=====]");
    }

    #[test]
    fn setup_progress_plan_contains_the_complete_main_flow() {
        let script = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("setup.sh");
        let titles: Vec<String> = preload_sections_from_script(&script)
            .into_iter()
            .map(|section| section.title)
            .collect();

        assert_eq!(
            titles,
            vec![
                "Updating Arch mirrors",
                "Updating pacman packages",
                "Updating AUR packages",
                "Removing pacman cache",
                "Install pacman packages",
                "Install AUR extras",
                "Verifying selected packages",
                "Install selected coding agents",
                "Update configs",
                "Configuring selected application roles",
                "Configuring selected shell",
                "Configuring Environment",
                "Configuring NetworkManager",
                "Configuring WiFi",
                "Configuring Bluetooth",
                "Configuring gnome-keyring",
                "Configuring filepicker",
                "Configuring Pacman Color",
                "Setting up Timeshift",
                "Configuring grub-btrfsd",
                "Configuring monitor",
                "Enabling SDDM display manager",
                "Configuring SDDM Theme",
                "Installation Summary",
                "Hyprland setup completed successfully!",
            ]
        );
    }

    #[test]
    fn completed_non_success_sections_have_tty_visible_states() {
        let theme = Theme::catppuccin_mocha();
        let warning = SetupSection {
            title: "Skipped step".to_string(),
            done: true,
            severity: StepSeverity::Warning,
        };
        let error = SetupSection {
            title: "Failed step".to_string(),
            done: true,
            severity: StepSeverity::Error,
        };

        assert_eq!(setup_section_marker(&warning, false), "!");
        assert_eq!(
            setup_section_style(theme, &warning, false).fg,
            Some(Color::Yellow)
        );
        assert_eq!(setup_section_marker(&error, false), "X");
        assert_eq!(
            setup_section_style(theme, &error, false).fg,
            Some(Color::Red)
        );
    }

    #[test]
    fn live_output_detects_structured_warnings_and_errors() {
        assert_eq!(
            output_line_severity("[2026-08-29 10:59:08] [ERROR] package failed"),
            StepSeverity::Error
        );
        assert_eq!(
            output_line_severity("[2026-08-29 10:59:08] X [install] hard failure"),
            StepSeverity::Error
        );
        assert_eq!(
            output_line_severity("[2026-08-29 10:59:08] [!] skipped optional step"),
            StepSeverity::Warning
        );
        assert_eq!(
            output_line_severity("[2026-08-29 10:59:08] Skipped Steps (2):"),
            StepSeverity::Warning
        );
        assert_eq!(
            output_line_severity("[2026-08-29 10:59:08] package installation complete"),
            StepSeverity::None
        );
    }

    fn output_test_app(lines: usize) -> AppState {
        let (tx, rx) = mpsc::channel();
        let script = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("setup.sh");
        let mut app = AppState::new(rx, tx, Some(script));
        app.ui_mode = UiMode::Menu;
        app.editing = false;
        app.edit_kind = EditKind::None;
        app.logs.show_details = true;
        // Exercise the in-memory view without writing to the user's installation log.
        app.logfile_path = PathBuf::new();
        for index in 0..lines {
            let line = format!("[*] output {index:04}");
            app.logs.push(line.clone(), &line);
        }
        app
    }

    fn output_mouse(kind: MouseEventKind, column: u16, row: u16) -> MouseEvent {
        MouseEvent {
            kind,
            column,
            row,
            modifiers: event::KeyModifiers::NONE,
        }
    }

    #[test]
    fn output_mouse_focus_wheel_follow_and_details_survive_incoming_logs() {
        let mut app = output_test_app(100);
        render_app_screen(&mut app, 120, 40);
        let body = app.output.body;
        let tail = app.scroll;
        handle_mouse_event(
            &mut app,
            output_mouse(MouseEventKind::Down(MouseButton::Left), body.x, body.y),
        );
        assert!(app.output.focused && app.follow_tail);
        handle_mouse_event(
            &mut app,
            output_mouse(MouseEventKind::ScrollUp, body.x, body.y),
        );
        assert_eq!(app.scroll, tail - 3);
        assert!(!app.follow_tail);
        let reading = app.scroll;
        app.tx.send("[*] another message".into()).unwrap();
        assert_eq!(drain_output_events(&mut app), 1);
        let screen = render_app_screen(&mut app, 120, 40);
        assert_eq!(app.scroll, reading);
        assert!(screen.contains("Paused"));
        let follow = app.output.follow_button;
        handle_mouse_event(
            &mut app,
            output_mouse(MouseEventKind::Down(MouseButton::Left), follow.x, follow.y),
        );
        assert!(app.follow_tail);
        assert_eq!(
            app.scroll,
            output_tail_start(app.output.total_rows, app.log_viewport_lines)
        );
        let mode = app.output.mode_button;
        handle_mouse_event(
            &mut app,
            output_mouse(MouseEventKind::Down(MouseButton::Left), mode.x, mode.y),
        );
        assert!(!app.logs.show_details);
        assert!(render_app_screen(&mut app, 120, 40).contains("[Details]"));
        handle_mouse_event(
            &mut app,
            output_mouse(MouseEventKind::ScrollDown, body.x, body.y),
        );
        assert!(!app.follow_tail);
    }

    #[test]
    fn output_scrollbar_clicks_and_drag_clamp_without_resuming_follow() {
        let mut app = output_test_app(100);
        render_app_screen(&mut app, 120, 40);
        let bar = app.output.scrollbar;
        let end = output_tail_start(app.output.total_rows, app.log_viewport_lines);
        handle_mouse_event(
            &mut app,
            output_mouse(MouseEventKind::Down(MouseButton::Left), bar.x, bar.y),
        );
        assert!(app.output.dragging && app.output.focused);
        assert_eq!(app.scroll, 0);
        handle_mouse_event(
            &mut app,
            output_mouse(
                MouseEventKind::Drag(MouseButton::Left),
                0,
                bar.bottom() + 10,
            ),
        );
        assert_eq!(app.scroll, end);
        assert!(!app.follow_tail);
        handle_mouse_event(
            &mut app,
            output_mouse(MouseEventKind::Drag(MouseButton::Left), 0, 0),
        );
        assert_eq!(app.scroll, 0);
        handle_mouse_event(
            &mut app,
            output_mouse(MouseEventKind::Up(MouseButton::Left), 0, 0),
        );
        assert!(!app.output.dragging);
        handle_mouse_event(
            &mut app,
            output_mouse(MouseEventKind::Drag(MouseButton::Left), bar.x, bar.bottom()),
        );
        assert_eq!(app.scroll, 0);
        assert_eq!(output_scrollbar_thumb(100, 20, 10, 80), (8, 2));
        assert_eq!(output_scrollbar_thumb(100, 20, 0, 80), (0, 0));
        assert_eq!(output_scrollbar_thumb(0, 0, 10, 0), (0, 10));
    }

    #[test]
    fn output_mouse_cannot_operate_through_modals_or_other_screens() {
        let mut app = output_test_app(100);
        render_app_screen(&mut app, 120, 40);
        let body = app.output.body;
        let tail = app.scroll;
        handle_mouse_event(&mut app, output_mouse(MouseEventKind::ScrollUp, 0, 0));
        assert_eq!(app.scroll, tail);
        app.output.focused = true;
        handle_mouse_event(
            &mut app,
            output_mouse(MouseEventKind::Down(MouseButton::Left), 0, 0),
        );
        assert!(!app.output.focused);
        app.editing = true;
        app.edit_kind = EditKind::ConfirmReboot;
        handle_mouse_event(
            &mut app,
            output_mouse(MouseEventKind::ScrollUp, body.x, body.y),
        );
        assert_eq!(app.scroll, tail);
        app.editing = false;
        app.ui_mode = UiMode::Preflight;
        handle_mouse_event(
            &mut app,
            output_mouse(MouseEventKind::ScrollUp, body.x, body.y),
        );
        assert_eq!(app.scroll, tail);
        render_app_screen(&mut app, 120, 40);
        assert_eq!(app.output.area, Rect::default());
    }

    #[test]
    fn focused_output_keyboard_navigation_preserves_explicit_follow_control() {
        let mut app = output_test_app(100);
        render_app_screen(&mut app, 120, 40);
        app.output.focused = true;
        let key = |code| KeyEvent::new(code, event::KeyModifiers::NONE);
        let tail = app.scroll;
        handle_key_event(&mut app, key(KeyCode::Up)).unwrap();
        assert_eq!(app.scroll, tail - 1);
        handle_key_event(&mut app, key(KeyCode::Home)).unwrap();
        assert_eq!(app.scroll, 0);
        assert!(!app.follow_tail);
        handle_key_event(&mut app, key(KeyCode::End)).unwrap();
        assert_eq!(app.scroll, tail);
        assert!(app.follow_tail);
        handle_key_event(&mut app, key(KeyCode::PageUp)).unwrap();
        assert_eq!(app.scroll, tail - OUTPUT_SCROLL_STEP);
        handle_key_event(&mut app, key(KeyCode::Enter)).unwrap();
        assert_eq!(app.ui_mode, UiMode::Menu);
        handle_key_event(&mut app, key(KeyCode::Esc)).unwrap();
        assert!(!app.output.focused);
        handle_key_event(&mut app, key(KeyCode::Enter)).unwrap();
        assert_eq!(app.ui_mode, UiMode::Preflight);
    }

    #[test]
    fn wrapped_output_tail_and_styles_use_visual_rows() {
        let original = Line::from(vec![
            Span::styled("timestamp ", Style::default().fg(Color::DarkGray)),
            Span::styled(
                "warning: abc界defghijklmnop",
                Style::default().fg(Color::Yellow),
            ),
        ]);
        let text = original.to_string();
        let rows = wrap_output_line(original, 12);
        assert!(rows.len() > 1);
        assert!(rows.iter().all(|line| line.width() <= 12));
        assert_eq!(
            rows.iter().map(ToString::to_string).collect::<String>(),
            text
        );
        assert_eq!(
            rows.last().unwrap().spans.last().unwrap().style.fg,
            Some(Color::Yellow)
        );
        assert!(wrap_output_line(Line::from("text"), 0).is_empty());

        let mut app = output_test_app(0);
        render_app_screen(&mut app, 80, 14);
        let text = format!(
            "[*] {}TAIL-END",
            "x".repeat(usize::from(app.output.body.width) * 8)
        );
        app.logs.push(text.clone(), &text);
        let screen = render_app_screen(&mut app, 80, 14);
        assert!(screen.contains("TAIL-END"));
        assert!(app.output.total_rows > app.logs.len());
        scroll_live_output(&mut app, -3);
        render_app_screen(&mut app, 100, 20);
        assert!(!app.follow_tail);
        assert!(app.scroll <= output_tail_start(app.output.total_rows, app.log_viewport_lines));
    }

    #[test]
    fn history_eviction_adjusts_browsing_by_wrapped_rows() {
        let mut app = output_test_app(0);
        app.logs.push(
            "abcdefghijklmnopqrstuvwx".into(),
            "abcdefghijklmnopqrstuvwx",
        );
        for _ in 1..OUTPUT_HISTORY_LIMIT {
            app.logs.push("short".into(), "short");
        }
        app.output.body.width = 8;
        app.follow_tail = false;
        app.scroll = 10;
        app.push_log_line("[*] new output");
        assert_eq!(app.logs.len(), OUTPUT_HISTORY_LIMIT);
        assert_eq!(app.scroll, 7);
    }

    #[cfg(target_os = "linux")]
    #[test]
    fn output_mouse_remains_active_while_a_setup_process_is_running() {
        struct RunningOutput(AppState);
        impl Drop for RunningOutput {
            fn drop(&mut self) {
                if let Some(mut child) = self.0.child.take() {
                    let _ = child.kill();
                    let _ = child.wait();
                }
            }
        }
        let mut running = RunningOutput(output_test_app(100));
        running.0.child = Some(
            Command::new("/usr/bin/sleep")
                .arg("60")
                .stdin(Stdio::null())
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .spawn()
                .unwrap(),
        );
        running.0.install_started_at = Some(Instant::now());
        let app = &mut running.0;
        let screen = render_app_screen(app, 120, 40);
        assert!(screen.contains("RUNNING"));
        let body = app.output.body;
        handle_mouse_event(app, output_mouse(MouseEventKind::ScrollUp, body.x, body.y));
        assert!(app.output.focused && !app.follow_tail);
        let position = app.scroll;
        app.tx.send("[*] installer progress".into()).unwrap();
        assert_eq!(drain_output_events(app), 1);
        render_app_screen(app, 120, 40);
        assert_eq!(app.scroll, position);
        let button = app.output.follow_button;
        handle_mouse_event(
            app,
            output_mouse(MouseEventKind::Down(MouseButton::Left), button.x, button.y),
        );
        assert!(app.follow_tail);
        assert!(app.child.as_mut().unwrap().try_wait().unwrap().is_none());
    }

    #[test]
    fn output_batches_leave_interaction_opportunities_without_dropping_messages() {
        let mut app = output_test_app(0);
        for index in 0..OUTPUT_MESSAGES_PER_TICK + 15 {
            app.tx.send(format!("[*] queued {index}")).unwrap();
        }
        assert_eq!(drain_output_events(&mut app), OUTPUT_MESSAGES_PER_TICK);
        assert_eq!(app.logs.len(), OUTPUT_MESSAGES_PER_TICK);
        render_app_screen(&mut app, 120, 40);
        let body = app.output.body;
        handle_mouse_event(
            &mut app,
            output_mouse(MouseEventKind::ScrollUp, body.x, body.y),
        );
        let reading = app.scroll;
        assert!(!app.follow_tail);
        assert_eq!(drain_output_events(&mut app), 15);
        assert_eq!(drain_output_events(&mut app), 0);
        render_app_screen(&mut app, 120, 40);
        assert_eq!(app.scroll, reading);
        assert_eq!(app.logs.len(), OUTPUT_MESSAGES_PER_TICK + 15);
        assert!(
            app.logs
                .lines()
                .last()
                .unwrap()
                .ends_with(&format!("queued {}", OUTPUT_MESSAGES_PER_TICK + 14))
        );
    }

    #[test]
    fn manual_output_scroll_stays_detached_until_follow_is_resumed() {
        let mut scroll = output_tail_start(100, 20);
        let mut follow_tail = true;

        scroll_output_up(&mut scroll, &mut follow_tail, 100, 20);
        assert_eq!(scroll, 72);
        assert!(!follow_tail);

        sync_output_scroll_after_append(&mut scroll, follow_tail, 120, 20);
        assert_eq!(scroll, 72);
        assert!(!follow_tail);

        for _ in 0..10 {
            scroll_output_down(&mut scroll, 120, 20);
        }
        assert_eq!(scroll, 100);
        assert!(!follow_tail);

        resume_output_follow(&mut scroll, &mut follow_tail, 120, 20);
        assert_eq!(scroll, 100);
        assert!(follow_tail);

        sync_output_scroll_after_append(&mut scroll, follow_tail, 121, 20);
        assert_eq!(scroll, 101);
    }

    #[test]
    fn live_output_uses_tty_colors_and_strips_ansi() {
        let theme = Theme::catppuccin_mocha();
        let error = live_output_line(
            theme,
            "[2026-08-29 10:59:08] \u{1b}[31m[ERROR] package failed\u{1b}[0m",
            true,
        );
        let warning = live_output_line(theme, "\u{1b}[33m[!] skipped optional step\u{1b}[0m", true);

        assert_eq!(error.spans.len(), 2);
        assert_eq!(error.spans[0].style.fg, Some(Color::DarkGray));
        assert_eq!(error.spans[1].style.fg, Some(Color::Red));
        assert!(error.spans[1].style.add_modifier.contains(Modifier::BOLD));
        assert!(!error.spans[1].content.contains('\u{1b}'));
        assert_eq!(warning.spans[0].style.fg, Some(Color::Yellow));
        assert!(warning.spans[0].style.add_modifier.contains(Modifier::BOLD));
        assert!(!warning.spans[0].content.contains('\u{1b}'));
    }
}
