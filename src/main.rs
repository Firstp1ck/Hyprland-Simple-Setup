use std::io::{self};
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::mpsc::{self, Receiver, Sender};
use std::thread;
use std::time::{Duration, Instant};

use anyhow::{Context, Result, bail};
use chrono::Local;
use crossterm::event::{self, Event, KeyCode, KeyEvent, KeyEventKind};
use crossterm::terminal::{
    EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode,
};
use crossterm::execute;
use ratatui::Terminal;
use ratatui::backend::CrosstermBackend;
use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span, Text};
use ratatui::widgets::{
    Block, Borders, Cell, Clear, List, ListItem, ListState, Paragraph, Row, Table, Wrap,
};
use std::fs;
use std::fs::OpenOptions;
use std::io::Read as IoRead;
use std::io::Write as IoWrite;
use std::collections::{HashMap, HashSet};
use serde::Deserialize;

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

#[derive(Clone, Debug)]
struct SetupSection {
    title: String,
    done: bool,
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
    SelectPacman,
    SelectAur,
}

#[derive(Clone, Debug, Default)]
struct MonitorInfo {
    name: String,
    modes: Vec<String>,
}

struct AppState {
    list_state: ListState,
    logs: Vec<String>,
    last_tick: Instant,
    scroll: u16,
    follow_tail: bool,
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
    current_section: Option<usize>,
    // Packages data and selections
    pacman_cats: Vec<(String, Vec<String>)>,
    aur_cats: Vec<(String, Vec<String>)>,
    pacman_sel_map: HashMap<String, bool>,
    aur_sel_map: HashMap<String, bool>,
    ms_cursor: usize,
    // Right-pane focus and cursor for live category filter in package selector
    ms_focus_right: bool,
    ms_cursor_filter: usize,
    // Optional category filters (None = all). When Some, only listed categories are shown. (kept for backward-compat / future persistence)
    #[allow(dead_code)] pacman_filter_cats: Option<HashSet<String>>,
    #[allow(dead_code)] aur_filter_cats: Option<HashSet<String>>,
    // Working sets for live category filter in package selector
    pacman_filter_working: HashSet<String>,
    aur_filter_working: HashSet<String>,
    // User-added packages and their resolved source
    user_added: Vec<String>,
    user_added_src: HashMap<String, String>, // name -> "pacman" | "aur"
    // Package descriptions loaded from packages.json
    pkg_descs: HashMap<String, String>,
    // Generic lines for warning popups (e.g., Add Packages validation)
    warning_lines: Vec<String>,
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

        let mut s = Self {
            list_state,
            logs: Vec::new(),
            last_tick: Instant::now(),
            scroll: 0,
            follow_tail: true,
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
            current_section: None,
            pacman_cats: Vec::new(),
            aur_cats: Vec::new(),
            pacman_sel_map: HashMap::new(),
            aur_sel_map: HashMap::new(),
            ms_cursor: 0,
            ms_focus_right: false,
            ms_cursor_filter: 0,
            pacman_filter_cats: None,
            aur_filter_cats: None,
            pacman_filter_working: HashSet::new(),
            aur_filter_working: HashSet::new(),
            user_added: Vec::new(),
            user_added_src: HashMap::new(),
            pkg_descs: HashMap::new(),
            warning_lines: Vec::new(),
            add_packages_append_mode: false,
        };
        // Load packages.json if present
        if let Some((pac_cats, aur_cats, descs)) = load_packages_json_categorized() {
            s.pacman_cats = pac_cats;
            s.aur_cats = aur_cats;
            s.pkg_descs = descs;
            // default select all
            for (_, pkgs) in &s.pacman_cats { for p in pkgs { s.pacman_sel_map.insert(p.clone(), true); } }
            for (_, pkgs) in &s.aur_cats { for p in pkgs { s.aur_sel_map.insert(p.clone(), true); } }
        }
        s
    }

    #[allow(dead_code)]
    fn selected_index(&self) -> usize {
        self.list_state.selected().unwrap_or(0)
    }

    fn push_log_line(&mut self, line: impl Into<String>) {
        let raw: String = line.into();
        if raw.trim().is_empty() {
            return;
        }
        // Update live section tracking based on raw (pre-timestamp) line
        update_sections_from_line(self, &raw);
        let ts = Local::now().format("%Y-%m-%d %H:%M:%S");
        let s = format!("[{}] {}", ts, raw);
        self.logs.push(s.clone());
        // Append to file
        if let Ok(mut f) = OpenOptions::new()
            .create(true)
            .append(true)
            .open(&self.logfile_path)
        {
            let _ = writeln!(f, "{}", s);
        }
        if self.logs.len() > 5000 {
            let drop = self.logs.len() - 5000;
            self.logs.drain(0..drop);
        }
        if self.follow_tail {
            self.scroll = self.logs.len().saturating_sub(1) as u16;
        }
    }
}

fn main() -> Result<()> {
    let setup_script = resolve_setup_script_path();

    let (tx, rx) = mpsc::channel::<String>();
    let app_tx = tx.clone();

    install_panic_hook();
    enable_raw_mode().context("enable raw mode")?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen).context("enter alt screen")?;
    // (Windows) Avoid duplicate raw mode enabling
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend).context("create terminal")?;

    let mut app = AppState::new(rx, app_tx, setup_script);
    app.push_log_line("Hyprland Setup TUI - ratatui + crossterm");
    app.push_log_line("Use Arrow Up/Down to select, Enter to run");
    app.push_log_line("Keys: q=quit, c=clear log, k=kill process, PgUp/PgDn=scroll");
    if app.setup_script.is_none() {
        app.push_log_line(
            "setup.sh not found automatically. Set $HYPR_SETUP_PATH or run from repo root.",
        );
    }

    let tick_rate = Duration::from_millis(100);

    let res = run_app(&mut terminal, &mut app, tick_rate);

    disable_raw_mode().ok();
    let mut out = io::stdout();
    execute!(out, LeaveAlternateScreen).ok();
    terminal.show_cursor().ok();

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
        while let Ok(line) = app.rx.try_recv() {
            app.push_log_line(line);
        }

        // Detect setup.sh completion and report once
        if let Some(child) = app.child.as_mut()
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
            if status.success() {
                app.push_log_line(format!(
                    "setup.sh finished successfully (exit {code}){}",
                    elapsed_msg
                ));
            } else {
                app.push_log_line(format!("setup.sh exited with status {code}{}", elapsed_msg));
            }
            // Mark the final section as done when the process ends
            if let Some(idx) = app.current_section.take()
                && let Some(sec) = app.sections.get_mut(idx)
            {
                sec.done = true;
            }
            app.child = None;
            // Show reboot confirmation popup
            app.ui_mode = UiMode::Menu; // ensure popup on main view
            app.editing = true;
            app.edit_kind = EditKind::ConfirmReboot;
        }

        terminal.draw(|f| draw_ui(f, app)).context("draw ui")?;

        let timeout = tick_rate.saturating_sub(app.last_tick.elapsed());
        if event::poll(timeout).context("poll events")? {
            match event::read().context("read event")? {
                Event::Key(key) => {
                    // Process only on Press to avoid duplicate triggers from Release/Repeat (Windows)
                    if matches!(key.kind, KeyEventKind::Press) {
                        if handle_key_event(app, key)? {
                            break;
                        }
                    }
                }
                Event::Mouse(_)
                | Event::Resize(_, _)
                | Event::FocusGained
                | Event::FocusLost
                | Event::Paste(_) => {}
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
        UiMode::Preflight => draw_preflight_ui(f, app, area),
    }
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

    if !app.sections.is_empty() {
        // Render sections with color: green=done, white=pending, blue=current
        let mut lines: Vec<Line> = Vec::new();
        for (idx, sec) in app.sections.iter().enumerate() {
            let style = if Some(idx) == app.current_section {
                Style::default()
                    .fg(app.theme.blue)
                    .add_modifier(Modifier::BOLD)
            } else if sec.done {
                Style::default().fg(Color::Green)
            } else {
                Style::default().fg(app.theme.text)
            };
            lines.push(Line::from(Span::styled(format!("• {}", sec.title), style)));
        }
        let left_widget = Paragraph::new(Text::from(lines)).block(left_block);
        f.render_widget(left_widget, chunks[0]);
    } else {
        let items: Vec<ListItem> = vec![ListItem::new(Line::from(Span::styled(
            "Run Hyprland setup",
            Style::default().fg(app.theme.text),
        )))];
        let menu = List::new(items)
            .block(left_block)
            .highlight_style(
                Style::default()
                    .fg(app.theme.blue)
                    .add_modifier(Modifier::BOLD),
            )
            .highlight_symbol("▶ ");
        // Use List for selection when idle
        f.render_stateful_widget(menu, chunks[0], &mut app.list_state);
    }

    let desc = "Execute setup.sh with full flow";
    let right_chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(3), Constraint::Min(1)])
        .split(chunks[1]);

    let script_path_text = app
        .setup_script
        .as_ref()
        .map(|p| p.display().to_string())
        .unwrap_or_else(|| "<not found>".to_string());

    let header = Paragraph::new(vec![
        Line::from(vec![
            Span::styled("Selected: ", Style::default().fg(app.theme.yellow)),
            Span::raw(desc),
        ]),
        Line::from(vec![
            Span::styled("Script: ", Style::default().fg(app.theme.yellow)),
            Span::raw(script_path_text),
        ]),
        Line::from("q quit  Enter run  ↑↓ navigate  PgUp/PgDn scroll"),
    ])
    .block(
        Block::default()
            .title("Info")
            .borders(Borders::ALL)
            .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
            .border_style(Style::default().fg(app.theme.mauve)),
    )
    .wrap(Wrap { trim: false });
    f.render_widget(header, right_chunks[0]);

    // Calculate visible slice to avoid cloning thousands of lines every frame
    let visible_lines = right_chunks[1].height.saturating_sub(2) as usize; // approx border lines
    let total_lines = app.logs.len();
    let mut start_idx = app.scroll as usize;
    if app.follow_tail {
        start_idx = total_lines.saturating_sub(visible_lines);
    } else {
        let max_scroll = total_lines.saturating_sub(1);
        if start_idx > max_scroll {
            start_idx = max_scroll;
        }
    }
    let end_idx = (start_idx.saturating_add(visible_lines)).min(total_lines);
    let log_text: Vec<Line> = app.logs[start_idx..end_idx]
        .iter()
        .map(|l| Line::from(l.clone()))
        .collect();

    let logs = Paragraph::new(log_text)
        .block(
            Block::default()
                .title("Output")
                .borders(Borders::ALL)
                .style(
                    Style::default()
                        .bg(app.theme.surface0)
                        .fg(app.theme.subtext0),
                )
                .border_style(Style::default().fg(app.theme.surface1)),
        )
        .wrap(Wrap { trim: false });
    f.render_widget(logs, right_chunks[1]);

    // Footer with keybind help
    let footer = Paragraph::new(Text::from(vec![Line::from(
        "Enter: preflight   PgUp/PgDn: scroll   Home/End: follow   c: clear   k: kill   q: quit",
    )]))
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
        let base = if selected {
            Style::default()
                .fg(app.theme.blue)
                .add_modifier(Modifier::BOLD)
        } else {
            Style::default().fg(app.theme.text)
        };
        Row::new(vec![
            Cell::from(name.to_string()).style(base),
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
        format!("{} selected", app.pacman_sel_map.values().filter(|v| **v).count()),
        sel(PreflightField::SelectPacman),
    ));
    rows.push(mk(
        "Enter",
        "Select AUR packages",
        format!("{} selected", app.aur_sel_map.values().filter(|v| **v).count()),
        sel(PreflightField::SelectAur),
    ));
    rows.push(mk(
        "Edit",
        "Add packages (comma-separated)",
        if app.user_added.is_empty() { "<none>".to_string() } else { app.user_added.join(", ") },
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
        "".to_string(),
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
    // Package multiselect popups (categorized)
    if app.editing && (app.edit_kind == EditKind::SelectPacman || app.edit_kind == EditKind::SelectAur) {
        let is_pacman = app.edit_kind == EditKind::SelectPacman;
        let area_w = area.width as i32;
        let popup_w = (area_w * 4 / 5).max(50) as u16;
        let popup_h = (area.height.saturating_sub(6)).max(12);
        let popup_x = area.x + (area.width.saturating_sub(popup_w)) / 2;
        let popup_y = area.y + (area.height.saturating_sub(popup_h)) / 2;
        let popup_rect = Rect { x: popup_x, y: popup_y, width: popup_w, height: popup_h };
        f.render_widget(Clear, popup_rect);
        let title = if app.edit_kind == EditKind::SelectPacman { "Select pacman packages" } else { "Select AUR packages" };
        let popup_block = Block::default()
            .title(title)
            .borders(Borders::ALL)
            .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
            .border_style(Style::default().fg(app.theme.mauve));
        f.render_widget(popup_block, popup_rect);

        let inner = Rect { x: popup_rect.x + 1, y: popup_rect.y + 1, width: popup_rect.width - 2, height: popup_rect.height - 2 };
        // Split vertically into help + main + footer
        let rows = Layout::default()
            .direction(Direction::Vertical)
            .constraints([Constraint::Length(1), Constraint::Min(5), Constraint::Length(2)])
            .split(inner);
        // Split main horizontally: left packages, right live category filter
        let cols = Layout::default()
            .direction(Direction::Horizontal)
            .constraints([Constraint::Percentage(60), Constraint::Percentage(40)])
            .split(rows[1]);

        let help = Paragraph::new(Text::from(vec![Line::from("Space toggle   a all   n none   Tab switch pane   changes apply live   Enter save   Esc cancel   j/k/↑/↓ move")]))
            .style(Style::default().fg(app.theme.subtext0));
        f.render_widget(help, rows[0]);

        // Prepare right pane: live category filter data and ensure working set initialized
        let mut cats: Vec<String> = if is_pacman { app.pacman_cats.iter().map(|(c, _)| c.clone()).collect() } else { app.aur_cats.iter().map(|(c, _)| c.clone()).collect() };
        cats.sort();

        // Build categorized lines into a flat list of (is_header, label, key_opt)
        // label includes package name and a description column
        let mut flat: Vec<(bool, String, Option<String>)> = Vec::new();
        if is_pacman {
            let cat_filter = if app.pacman_filter_working.is_empty() { None } else { Some(&app.pacman_filter_working) };
            for (cat, pkgs) in &app.pacman_cats {
                if let Some(cf) = cat_filter { if !cf.contains(cat) { continue; } }
                flat.push((true, format!("[{}]", cat), None));
                for p in pkgs {
                    let chosen = *app.pacman_sel_map.get(p).unwrap_or(&false);
                    let mark = if chosen { "[x]" } else { "[ ]" };
                    let desc = app.pkg_descs.get(p).cloned().unwrap_or_else(|| "".to_string());
                    // Two-column layout: name left, desc right; pad name to fixed width
                    let name_col = format!("{} {}", mark, p);
                    let name_width = (popup_rect.width as usize).saturating_sub(6).min(40); // cap name width
                    let padded = if name_col.len() < name_width { format!("{:<width$}", name_col, width=name_width) } else { name_col };
                    flat.push((false, format!("{}  {}", padded, desc), Some(p.clone())));
                }
            }
        } else {
            let cat_filter = if app.aur_filter_working.is_empty() { None } else { Some(&app.aur_filter_working) };
            for (cat, pkgs) in &app.aur_cats {
                if let Some(cf) = cat_filter { if !cf.contains(cat) { continue; } }
                flat.push((true, format!("[{}]", cat), None));
                for p in pkgs {
                    let chosen = *app.aur_sel_map.get(p).unwrap_or(&false);
                    let mark = if chosen { "[x]" } else { "[ ]" };
                    let desc = app.pkg_descs.get(p).cloned().unwrap_or_else(|| "".to_string());
                    let name_col = format!("{} {}", mark, p);
                    let name_width = (popup_rect.width as usize).saturating_sub(6).min(40);
                    let padded = if name_col.len() < name_width { format!("{:<width$}", name_col, width=name_width) } else { name_col };
                    flat.push((false, format!("{}  {}", padded, desc), Some(p.clone())));
                }
            }
        }

        // Create items; highlight only non-headers
        let mut items: Vec<ListItem> = Vec::with_capacity(flat.len());
        for (is_header, label, _) in &flat {
            if *is_header {
                items.push(ListItem::new(Line::from(label.clone())).style(Style::default().fg(app.theme.yellow)));
            } else {
                items.push(ListItem::new(Line::from(label.clone())));
            }
        }
        let mut state = ListState::default();
        state.select(Some(app.ms_cursor.min(items.len().saturating_sub(1))));
        let list = List::new(items)
            .highlight_style(Style::default().fg(app.theme.blue).add_modifier(Modifier::BOLD))
            .highlight_symbol("▶ ")
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
                    .border_style(Style::default().fg(if !app.ms_focus_right { app.theme.mauve } else { app.theme.surface1 })),
            );
        f.render_stateful_widget(list, cols[0], &mut state);

        // Right pane: live category filter
        let mut filter_items: Vec<ListItem> = Vec::new();
        for c in &cats {
            let mark = if (if is_pacman { &app.pacman_filter_working } else { &app.aur_filter_working }).contains(c) { "[x]" } else { "[ ]" };
            filter_items.push(ListItem::new(Line::from(format!("{} {}", mark, c))));
        }
        let mut filter_state = ListState::default();
        filter_state.select(Some(app.ms_cursor_filter.min(cats.len().saturating_sub(1))));
        let filter_title = if is_pacman { "Filter pacman categories" } else { "Filter AUR categories" };
        let filter_list = List::new(filter_items)
            .highlight_style(Style::default().fg(app.theme.mauve).add_modifier(Modifier::BOLD))
            .highlight_symbol("▶ ")
            .block(
                Block::default()
                    .title(filter_title)
                    .borders(Borders::ALL)
                    .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
                    .border_style(Style::default().fg(if app.ms_focus_right { app.theme.mauve } else { app.theme.surface1 })),
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
        let bottom = Paragraph::new(Text::from(vec![Line::from(format!("Selected: {} / {}", selected_count, total_count))]))
            .style(Style::default().fg(app.theme.subtext0));
        f.render_widget(bottom, rows[2]);
    }

    // Category filter popup removed (now part of split-pane in package selector)

    // Simple info popup (dismiss with Enter/Esc)
    if app.editing && app.edit_kind == EditKind::Info {
        let area_w = area.width as i32;
        let popup_w = (area_w * 3 / 5).max(28) as u16;
        let popup_h = 5u16; // title + message + tip
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
            .title("Info")
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
        let inner_chunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints([Constraint::Length(2), Constraint::Length(1)])
            .split(inner);

        let msg = Paragraph::new(Text::from(vec![Line::from(
            "Password is required to run unattended setup.",
        )]))
        .style(Style::default().fg(app.theme.text));
        f.render_widget(msg, inner_chunks[0]);

        let tip = Paragraph::new(Text::from(vec![Line::from("Press Enter or Esc to close")]))
            .style(Style::default().fg(app.theme.subtext0));
        f.render_widget(tip, inner_chunks[1]);
    }
    // Add Packages validation warning popup
    if app.editing && app.edit_kind == EditKind::AddPackagesWarning {
        let area_w = area.width as i32;
        let popup_w = (area_w * 3 / 5).max(40) as u16;
        let popup_h = (app.warning_lines.len() as u16 + 5).min(area.height.saturating_sub(4));
        let popup_x = area.x + (area.width.saturating_sub(popup_w)) / 2;
        let popup_y = area.y + (area.height.saturating_sub(popup_h)) / 2;
        let popup_rect = Rect { x: popup_x, y: popup_y, width: popup_w, height: popup_h };
        f.render_widget(Clear, popup_rect);
        let popup_block = Block::default()
            .title("Package warnings")
            .borders(Borders::ALL)
            .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
            .border_style(Style::default().fg(app.theme.mauve));
        f.render_widget(popup_block, popup_rect);

        let inner = Rect { x: popup_rect.x + 1, y: popup_rect.y + 1, width: popup_rect.width - 2, height: popup_rect.height - 2 };
        let rows = Layout::default()
            .direction(Direction::Vertical)
            .constraints([Constraint::Length((app.warning_lines.len() as u16).min(inner.height.saturating_sub(2))), Constraint::Length(1)])
            .split(inner);
        let mut lines: Vec<Line> = Vec::new();
        for l in &app.warning_lines {
            lines.push(Line::from(l.clone()));
        }
        let list = Paragraph::new(Text::from(lines)).wrap(Wrap { trim: false });
        f.render_widget(list, rows[0]);
        let tip = Paragraph::new(Text::from(vec![Line::from("Press Enter/Esc to return and edit")]))
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
        let popup_rect = Rect { x: popup_x, y: popup_y, width: popup_w, height: popup_h };
        f.render_widget(Clear, popup_rect);
        let popup_block = Block::default()
            .title("Enable Monitor Setup?")
            .borders(Borders::ALL)
            .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
            .border_style(Style::default().fg(app.theme.mauve));
        f.render_widget(popup_block, popup_rect);

        let inner = Rect { x: popup_rect.x + 1, y: popup_rect.y + 1, width: popup_rect.width - 2, height: popup_rect.height - 2 };
        let rows = Layout::default()
            .direction(Direction::Vertical)
            .constraints([Constraint::Length(2), Constraint::Length(2)])
            .split(inner);
        let msg = Paragraph::new(Text::from(vec![Line::from("MONITOR_SETUP_ENABLED has to be set to true, do you want to set to true?")]))
            .style(Style::default().fg(app.theme.text));
        f.render_widget(msg, rows[0]);
        let tip = Paragraph::new(Text::from(vec![Line::from("Press Y/Enter to confirm, N/Esc to cancel")]))
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
        let popup_rect = Rect { x: popup_x, y: popup_y, width: popup_w, height: popup_h };
        f.render_widget(Clear, popup_rect);
        let popup_block = Block::default()
            .title("Start unattended install?")
            .borders(Borders::ALL)
            .style(Style::default().bg(app.theme.surface0).fg(app.theme.text))
            .border_style(Style::default().fg(app.theme.mauve));
        f.render_widget(popup_block, popup_rect);

        let inner = Rect { x: popup_rect.x + 1, y: popup_rect.y + 1, width: popup_rect.width - 2, height: popup_rect.height - 2 };
        let rows = Layout::default()
            .direction(Direction::Vertical)
            .constraints([Constraint::Length(2), Constraint::Length(2)])
            .split(inner);
        let msg = Paragraph::new(Text::from(vec![Line::from("This will run the setup now. Proceed?")]))
            .style(Style::default().fg(app.theme.text));
        f.render_widget(msg, rows[0]);
        let tip = Paragraph::new(Text::from(vec![Line::from("Press Y/Enter to confirm, N/Esc to cancel")]))
            .style(Style::default().fg(app.theme.subtext0));
        f.render_widget(tip, rows[1]);
    }
    // Confirm reboot popup
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
    match app.ui_mode {
        UiMode::Menu => match key.code {
            KeyCode::Char('q') => return Ok(true),
            KeyCode::Enter => {
                app.ui_mode = UiMode::Preflight;
            }
            KeyCode::PageUp => {
                app.follow_tail = false;
                app.scroll = app.scroll.saturating_sub(8);
            }
            KeyCode::PageDown => {
                let max = app.logs.len().saturating_sub(1) as u16;
                app.scroll = (app.scroll.saturating_add(8)).min(max);
                if app.scroll >= max {
                    app.follow_tail = true;
                }
            }
            KeyCode::Home => {
                app.follow_tail = false;
                app.scroll = 0;
            }
            KeyCode::End => {
                app.follow_tail = true;
            }
            KeyCode::Char('c') => {
                app.logs.clear();
                app.scroll = 0;
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
    // No concurrent run guard needed in the simplified flow

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
            if *sel { out.push(name.clone()); }
        }
        out.sort();
        // Merge user-added pacman packages
        for name in &app.user_added {
            if let Some(src) = app.user_added_src.get(name) { if src == "pacman" { out.push(name.clone()); } }
        }
        out.sort();
        out.dedup();
        out.join(" ")
    } else { String::new() };
    let selected_aur = if !app.aur_sel_map.is_empty() {
        let mut out = Vec::new();
        for (name, sel) in &app.aur_sel_map {
            if *sel { out.push(name.clone()); }
        }
        out.sort();
        // Merge user-added AUR packages
        for name in &app.user_added {
            if let Some(src) = app.user_added_src.get(name) { if src == "aur" { out.push(name.clone()); } }
        }
        out.sort();
        out.dedup();
        out.join(" ")
    } else { String::new() };

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
    cmd.env(
        "FISH_LANGUAGE_CHOICE_OVERRIDE",
        pf.fish_language_choice.to_string(),
    );
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
    if !selected_pacman.is_empty() { cmd.env("SELECTED_PACMAN_PACKAGES", selected_pacman.clone()); }
    if !selected_aur.is_empty() { cmd.env("SELECTED_AUR_PACKAGES", selected_aur.clone()); }
    // Also pass user-added splits explicitly for setup.sh merging
    let mut user_pac = Vec::new();
    let mut user_aur = Vec::new();
    for name in &app.user_added {
        if let Some(src) = app.user_added_src.get(name) {
            if src == "pacman" { user_pac.push(name.clone()); }
            if src == "aur" { user_aur.push(name.clone()); }
        }
    }
    if !user_pac.is_empty() { cmd.env("USER_ADDED_PACMAN_PACKAGES", user_pac.join(" ")); }
    if !user_aur.is_empty() { cmd.env("USER_ADDED_AUR_PACKAGES", user_aur.join(" ")); }

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

#[derive(Deserialize)]
struct PackagesRoot {
    hyprland_packages: HashMap<String, Vec<String>>,
    aur_packages: HashMap<String, Vec<String>>,
    package_descriptions: Option<HashMap<String, String>>,
}

fn load_packages_json_categorized() -> Option<(
    Vec<(String, Vec<String>)>,
    Vec<(String, Vec<String>)>,
    HashMap<String, String>,
)> {
    let candidates = [
        PathBuf::from("./packages.json"),
        PathBuf::from("../packages.json"),
        PathBuf::from("../../packages.json"),
        PathBuf::from("../../../packages.json"),
    ];
    let path = candidates.into_iter().find(|p| p.exists())?;
    let data = fs::read_to_string(path).ok()?;
    let parsed: PackagesRoot = serde_json::from_str(&data).ok()?;
    let mut pac_cats: Vec<(String, Vec<String>)> = parsed
        .hyprland_packages
        .into_iter()
        .map(|(k, mut v)| {
            v.sort();
            (k, v)
        })
        .collect();
    pac_cats.sort_by(|a, b| a.0.cmp(&b.0));
    let mut aur_cats: Vec<(String, Vec<String>)> = parsed
        .aur_packages
        .into_iter()
        .map(|(k, mut v)| {
            v.sort();
            (k, v)
        })
        .collect();
    aur_cats.sort_by(|a, b| a.0.cmp(&b.0));
    let descs = parsed.package_descriptions.unwrap_or_default();
    Some((pac_cats, aur_cats, descs))
}

fn install_panic_hook() {
    std::panic::set_hook(Box::new(|info| {
        let _ = disable_raw_mode();
        let mut stdout = std::io::stdout();
        let _ = execute!(stdout, LeaveAlternateScreen);
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
        } else if app.edit_kind == EditKind::SelectPacman || app.edit_kind == EditKind::SelectAur {
            // Multiselect handling (categorized) — headers are not selectable
            let is_pacman = app.edit_kind == EditKind::SelectPacman;
            let len: usize = if is_pacman {
                app.pacman_cats.iter().map(|(_, pkgs)| 1 + pkgs.len()).sum()
            } else {
                app.aur_cats.iter().map(|(_, pkgs)| 1 + pkgs.len()).sum()
            };
            // Compute header indices to skip
            let mut header_idx: Vec<usize> = Vec::new();
            if is_pacman {
                let mut idx = 0usize;
                for (_, pkgs) in &app.pacman_cats {
                    header_idx.push(idx);
                    idx += 1 + pkgs.len();
                }
            } else {
                let mut idx = 0usize;
                for (_, pkgs) in &app.aur_cats {
                    header_idx.push(idx);
                    idx += 1 + pkgs.len();
                }
            }
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
                        let mut cats: Vec<String> = if is_pacman { app.pacman_cats.iter().map(|(c, _)| c.clone()).collect() } else { app.aur_cats.iter().map(|(c, _)| c.clone()).collect() };
                        cats.sort();
                        let lenf = cats.len();
                        if lenf > 0 { app.ms_cursor_filter = if app.ms_cursor_filter + 1 >= lenf { 0 } else { app.ms_cursor_filter + 1 }; }
                    } else {
                        if len > 0 {
                            // advance and skip headers
                            for _ in 0..len {
                                app.ms_cursor = if app.ms_cursor + 1 >= len { 0 } else { app.ms_cursor + 1 };
                                if !header_idx.contains(&app.ms_cursor) { break; }
                            }
                        }
                    }
                }
                KeyCode::Char('k') | KeyCode::Up => {
                    if app.ms_focus_right {
                        let mut cats: Vec<String> = if is_pacman { app.pacman_cats.iter().map(|(c, _)| c.clone()).collect() } else { app.aur_cats.iter().map(|(c, _)| c.clone()).collect() };
                        cats.sort();
                        let lenf = cats.len();
                        if lenf > 0 { app.ms_cursor_filter = if app.ms_cursor_filter == 0 { lenf - 1 } else { app.ms_cursor_filter - 1 }; }
                    } else {
                        if len > 0 {
                            // retreat and skip headers
                            for _ in 0..len {
                                app.ms_cursor = if app.ms_cursor == 0 { len - 1 } else { app.ms_cursor - 1 };
                                if !header_idx.contains(&app.ms_cursor) { break; }
                            }
                        }
                    }
                }
                KeyCode::Char(' ') => {
                    if app.ms_focus_right {
                        // toggle filter entry
                        let mut cats: Vec<String> = if is_pacman { app.pacman_cats.iter().map(|(c, _)| c.clone()).collect() } else { app.aur_cats.iter().map(|(c, _)| c.clone()).collect() };
                        cats.sort();
                        let idx = app.ms_cursor_filter.min(cats.len().saturating_sub(1));
                        if let Some(cat) = cats.get(idx) {
                            if is_pacman {
                                if app.pacman_filter_working.contains(cat) { app.pacman_filter_working.remove(cat); } else { app.pacman_filter_working.insert(cat.clone()); }
                            } else {
                                if app.aur_filter_working.contains(cat) { app.aur_filter_working.remove(cat) ; } else { app.aur_filter_working.insert(cat.clone()); }
                            }
                        }
                    } else {
                        // Toggle selected package if not a header
                        let mut idx = 0usize;
                        if is_pacman {
                            'outerp: for (_, pkgs) in &app.pacman_cats {
                                if app.ms_cursor == idx { idx += 1; continue; } // header row
                                idx += 1;
                                for p in pkgs {
                                    if app.ms_cursor == idx { let e = app.pacman_sel_map.entry(p.clone()).or_insert(false); *e = !*e; break 'outerp; }
                                    idx += 1;
                                }
                            }
                        } else {
                            'outera: for (_, pkgs) in &app.aur_cats {
                                if app.ms_cursor == idx { idx += 1; continue; } // header row
                                idx += 1;
                                for p in pkgs {
                                    if app.ms_cursor == idx { let e = app.aur_sel_map.entry(p.clone()).or_insert(false); *e = !*e; break 'outera; }
                                    idx += 1;
                                }
                            }
                        }
                    }
                }
                KeyCode::Char('a') => {
                    if app.ms_focus_right {
                        // select all categories
                        let mut cats: Vec<String> = if is_pacman { app.pacman_cats.iter().map(|(c, _)| c.clone()).collect() } else { app.aur_cats.iter().map(|(c, _)| c.clone()).collect() };
                        cats.sort();
                        if is_pacman { app.pacman_filter_working = cats.into_iter().collect(); } else { app.aur_filter_working = cats.into_iter().collect(); }
                    } else {
                        if is_pacman { for v in app.pacman_sel_map.values_mut() { *v = true; } } else { for v in app.aur_sel_map.values_mut() { *v = true; } }
                    }
                }
                KeyCode::Char('n') => {
                    if app.ms_focus_right {
                        // clear categories (empty means all)
                        if is_pacman { app.pacman_filter_working.clear(); } else { app.aur_filter_working.clear(); }
                    } else {
                        if is_pacman { for v in app.pacman_sel_map.values_mut() { *v = false; } } else { for v in app.aur_sel_map.values_mut() { *v = false; } }
                    }
                }
                _ => {}
            }
            return Ok(false);
        }
        match key.code {
            KeyCode::Esc | KeyCode::Char('q') => {
                app.editing = false;
                app.edit_buffer.clear();
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
                        if app.pacman_sel_map.contains_key(name) || app.aur_sel_map.contains_key(name) || app.user_added.contains(name) {
                            warnings.push(format!("Already selected: {}", name));
                            continue;
                        }
                        let is_repo = Command::new("bash").arg("-lc").arg(format!("pacman -Si -- {} >/dev/null 2>&1", name)).status().ok().map(|s| s.success()).unwrap_or(false);
                        let is_aur = if is_repo { false } else { Command::new("bash").arg("-lc").arg(format!("yay -Si -- {} >/dev/null 2>&1", name)).status().ok().map(|s| s.success()).unwrap_or(false) };
                        if !is_repo && !is_aur {
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
        KeyCode::Home => {
            app.follow_tail = false;
            app.scroll = 0;
        }
        KeyCode::End => {
            app.follow_tail = true;
        }
        KeyCode::PageUp => {
            app.follow_tail = false;
            app.scroll = app.scroll.saturating_sub(8);
        }
        KeyCode::PageDown => {
            let max = app.logs.len().saturating_sub(1) as u16;
            app.scroll = (app.scroll.saturating_add(8)).min(max);
            if app.scroll >= max {
                app.follow_tail = true;
            }
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
                    if app.preflight.password.is_empty() {
                        // Show small info popup instead of only logging
                        app.editing = true;
                        app.edit_kind = EditKind::Info;
                        return Ok(false);
                    }
                    if app.preflight.dry_run {
                        app.ui_mode = UiMode::Menu; // return to menu for logs visibility
                        spawn_setup(app, &["--dry-run"]) ?;
                        return Ok(false);
                    }
                    app.editing = true;
                    app.edit_kind = EditKind::ConfirmStartInstall;
                    return Ok(false);
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
        PreflightField::EnvFishLanguageChoiceOverride => PreflightField::EnvWallpaperDirOverride,
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
        PreflightField::EnvWallpaperDirOverride => PreflightField::EnvFishLanguageChoiceOverride,
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
                    if app.pacman_sel_map.contains_key(&name) {
                        if let Some(v) = app.pacman_sel_map.get_mut(&name) { *v = true; }
                        app.push_log_line(format!("Package '{}' already in pacman list; set selected", name));
                        continue;
                    }
                    if app.aur_sel_map.contains_key(&name) {
                        if let Some(v) = app.aur_sel_map.get_mut(&name) { *v = true; }
                        app.push_log_line(format!("Package '{}' already in AUR list; set selected", name));
                        continue;
                    }
                    let mut src = String::from("unknown");
                    if Command::new("bash").arg("-lc").arg(format!("pacman -Si -- {} >/dev/null 2>&1", name)).status().ok().map(|s| s.success()).unwrap_or(false) {
                        src = "pacman".to_string();
                    } else if Command::new("bash").arg("-lc").arg(format!("yay -Si -- {} >/dev/null 2>&1", name)).status().ok().map(|s| s.success()).unwrap_or(false) {
                        src = "aur".to_string();
                    }
                    if src == "unknown" { app.push_log_line(format!("Skipping unknown package '{}': not found in pacman or AUR", name)); continue; }
                    app.user_added_src.insert(name.clone(), src);
                    app.user_added.push(name);
                }
            } else {
                // Replace mode: rebuild list exactly from current input
                let mut new_user_added: Vec<String> = Vec::new();
                let mut new_user_added_src: HashMap<String, String> = HashMap::new();
                for name in names {
                    if app.pacman_sel_map.contains_key(&name) {
                        if let Some(v) = app.pacman_sel_map.get_mut(&name) { *v = true; }
                        app.push_log_line(format!("Package '{}' already in pacman list; set selected", name));
                        continue;
                    }
                    if app.aur_sel_map.contains_key(&name) {
                        if let Some(v) = app.aur_sel_map.get_mut(&name) { *v = true; }
                        app.push_log_line(format!("Package '{}' already in AUR list; set selected", name));
                        continue;
                    }
                    let mut src = String::from("unknown");
                    if Command::new("bash").arg("-lc").arg(format!("pacman -Si -- {} >/dev/null 2>&1", name)).status().ok().map(|s| s.success()).unwrap_or(false) {
                        src = "pacman".to_string();
                    } else if Command::new("bash").arg("-lc").arg(format!("yay -Si -- {} >/dev/null 2>&1", name)).status().ok().map(|s| s.success()).unwrap_or(false) {
                        src = "aur".to_string();
                    }
                    if src == "unknown" { app.push_log_line(format!("Skipping unknown package '{}': not found in pacman or AUR", name)); continue; }
                    new_user_added_src.insert(name.clone(), src);
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
    // Fallback to empty list if hyprctl not present or parsing fails
    let output = Command::new("hyprctl").arg("monitors").output();
    let text = match output {
        Ok(out) if out.status.success() => String::from_utf8_lossy(&out.stdout).to_string(),
        _ => return Vec::new(),
    };

    let mut monitors: Vec<MonitorInfo> = Vec::new();
    let mut current: Option<MonitorInfo> = None;
    for line in text.lines() {
        if let Some(rest) = line.strip_prefix("Monitor ") {
            if let Some(mi) = current.take() {
                monitors.push(mi);
            }
            let name = rest.split_whitespace().next().unwrap_or("").to_string();
            current = Some(MonitorInfo {
                name,
                modes: Vec::new(),
            });
        } else if line.trim_start().starts_with("availableModes:")
            && let Some(mi) = current.as_mut()
        {
            let modes_str = line.split_once(':').map(|x| x.1).unwrap_or("").trim();
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

// Very small ANSI/CSI escape stripper to keep logs readable while respecting carriage returns
fn strip_ansi_sequences(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut iter = s.chars();
    while let Some(ch) = iter.next() {
        if ch == '\u{1b}' {
            // ESC
            if let Some('[') = iter.next() {
                // consume until final byte (0x40-0x7E)
                for c in iter.by_ref() {
                    if ('@'..='~').contains(&c) {
                        break;
                    }
                }
                continue;
            }
            continue;
        }
        out.push(ch);
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

fn update_sections_from_line(app: &mut AppState, raw_line: &str) {
    // Detect headings like "=== Step ===" or "========= Step ========="
    let trimmed = raw_line.trim();
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
        // If we preloaded, try to move focus to matching title; otherwise append
        if let Some(pos) = app.sections.iter().position(|s| s.title == title) {
            app.current_section = Some(pos);
        } else {
            app.sections.push(SetupSection {
                title: title.clone(),
                done: false,
            });
            app.current_section = Some(app.sections.len() - 1);
        }
        return;
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

fn preload_sections_from_script(script_path: &PathBuf) -> Vec<SetupSection> {
    // Strategy: derive order from the main() call sequence.
    // 1) Collect function definitions present in the script.
    // 2) Scan the main() block, extract called function names in order.
    // 3) For each called function, look up the first announce_step title in its body.
    // 4) Build the sections vector in that order, and append the final marker.
    let mut out: Vec<SetupSection> = Vec::new();
    let Ok(content) = fs::read_to_string(script_path) else { return out };

    let lines: Vec<&str> = content.lines().collect();

    // 1) Find function definitions: pattern "name() {"
    use std::collections::HashMap;
    let mut fn_starts: HashMap<String, usize> = HashMap::new();
    for (i, raw) in lines.iter().enumerate() {
        let t = raw.trim();
        if let Some(paren) = t.find("(){") {
            // rough; many functions are formatted as "name() {"
            let name = t[..paren].trim();
            if !name.is_empty()
                && name.chars().all(|c| c == '_' || c.is_ascii_alphanumeric())
            {
                fn_starts.insert(name.to_string(), i);
            }
        } else if let Some(paren) = t.find("() {") {
            let name = t[..paren].trim();
            if !name.is_empty()
                && name.chars().all(|c| c == '_' || c.is_ascii_alphanumeric())
            {
                fn_starts.insert(name.to_string(), i);
            }
        }
    }

    // Helper: extract first announce title inside a function body starting at index
    let mut title_cache: HashMap<String, String> = HashMap::new();
    let mut get_title_for_fn = |fname: &str| -> Option<String> {
        if let Some(t) = title_cache.get(fname) {
            return Some(t.clone());
        }
        let start = *fn_starts.get(fname)?;
        // find body range by brace counting from the line containing "{" forward
        let mut depth: i32 = 0;
        let mut in_body = false;
        for raw in &lines[start..] {
            let s = *raw;
            if !in_body {
                if s.contains('{') {
                    in_body = true;
                    depth = 1;
                }
                continue;
            }
            // check for announce_step
            let t = s.trim();
            if let Some(rest) = t.strip_prefix("announce_step \"")
                .or_else(|| t.strip_prefix("extended_announce_step \""))
            {
                if let Some(end) = rest.find('"') {
                    let title = rest[..end].to_string();
                    title_cache.insert(fname.to_string(), title.clone());
                    return Some(title);
                }
            }
            if s.contains('{') {
                depth += 1;
            }
            if s.contains('}') {
                depth -= 1;
                if depth <= 0 {
                    break;
                }
            }
        }
        None
    };

    // 2) Extract the main() block lines
    let mut main_start = None;
    for (i, raw) in lines.iter().enumerate() {
        if raw.trim_start().starts_with("main() {") {
            main_start = Some(i);
            break;
        }
    }
    if let Some(start_idx) = main_start {
        let mut depth: i32 = 0;
        let mut in_body = false;
        let mut called: Vec<String> = Vec::new();
        for raw in &lines[start_idx..] {
            let s = *raw;
            if !in_body {
                if s.contains('{') {
                    in_body = true;
                    depth = 1;
                }
                continue;
            }
            let t = s.trim();
            // stop at end of main
            if t.contains('}') {
                depth -= 1;
                if depth <= 0 {
                    break;
                }
            }
            if t.contains('{') {
                depth += 1; // nested blocks inside main (if/else)
            }
            // very simple call detection for shell: a line starting with a known function name
            // (functions are invoked as plain identifiers like: update_pacman)
            let token = t.split_whitespace().next().unwrap_or("");
            if fn_starts.contains_key(token) {
                called.push(token.to_string());
            }
        }
        // 3) Map to titles and build sections
        for fname in called {
            if let Some(title) = get_title_for_fn(&fname) {
                if !out.iter().any(|s| s.title == title) {
                    out.push(SetupSection { title, done: false });
                }
            }
        }
    }
    out
}
