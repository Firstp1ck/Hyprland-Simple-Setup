use std::io::{self, BufRead, BufReader};
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::sync::mpsc::{self, Receiver, Sender};
use std::thread;
use std::time::{Duration, Instant};

use anyhow::{bail, Context, Result};
use crossterm::event::{self, Event, KeyCode, KeyEvent, KeyModifiers};
use crossterm::terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen};
use crossterm::{execute, terminal};
use ratatui::backend::CrosstermBackend;
use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span, Text};
use ratatui::widgets::{Block, Borders, List, ListItem, ListState, Paragraph, Wrap};
use ratatui::Terminal;

#[derive(Clone, Copy, Debug)]
enum MenuAction {
    FullSetup,
    DryRun,
    ConfigureMonitorOnly,
    ConfigureSddmOnly,
    Quit,
}

struct MenuItem {
    label: &'static str,
    action: MenuAction,
    description: &'static str,
}

struct ProcessHandles {
    child: Child,
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
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum PreflightField {
    PromptDefault,
    FishLanguage,
    WallpaperDir,
    MonitorEnabled,
    MonitorConfig,
    AutoContinue,
    Start,
}

struct AppState {
    items: Vec<MenuItem>,
    list_state: ListState,
    logs: Vec<String>,
    last_tick: Instant,
    scroll: u16,
    process: Option<ProcessHandles>,
    rx: Receiver<String>,
    tx: Sender<String>,
    setup_script: Option<PathBuf>,
    ui_mode: UiMode,
    preflight: PreflightConfig,
    preflight_focus: PreflightField,
    editing: bool,
    edit_buffer: String,
}

impl AppState {
    fn new(rx: Receiver<String>, tx: Sender<String>, setup_script: Option<PathBuf>) -> Self {
        let mut list_state = ListState::default();
        list_state.select(Some(0));
        let default_wallpaper = guess_default_wallpaper_dir(&setup_script)
            .unwrap_or_else(|| "./Wallpaper".to_string());
        Self {
            items: vec![
                MenuItem { label: "Run Hyprland setup", action: MenuAction::FullSetup, description: "Execute setup.sh with full flow" },
                MenuItem { label: "Dry run (no changes)", action: MenuAction::DryRun, description: "Execute setup.sh --dry-run" },
                MenuItem { label: "Configure monitor only", action: MenuAction::ConfigureMonitorOnly, description: "Execute setup.sh --configure-monitor" },
                MenuItem { label: "Configure SDDM theme only", action: MenuAction::ConfigureSddmOnly, description: "Execute setup.sh --configure-sddm" },
                MenuItem { label: "Quit", action: MenuAction::Quit, description: "Exit the TUI" },
            ],
            list_state,
            logs: Vec::new(),
            last_tick: Instant::now(),
            scroll: 0,
            process: None,
            rx,
            tx,
            setup_script,
            ui_mode: UiMode::Menu,
            preflight: PreflightConfig {
                prompt_default_yes: true,
                fish_language_choice: 1,
                wallpaper_dir: default_wallpaper,
                monitor_setup_enabled: false,
                monitor_config: String::new(),
                auto_continue_on_warnings: true,
            },
            preflight_focus: PreflightField::Start,
            editing: false,
            edit_buffer: String::new(),
        }
    }

    fn selected_index(&self) -> usize {
        self.list_state.selected().unwrap_or(0)
    }

    fn push_log_line(&mut self, line: impl Into<String>) {
        self.logs.push(line.into());
        if self.logs.len() > 5000 {
            let drop = self.logs.len() - 5000;
            self.logs.drain(0..drop);
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
    terminal::enable_raw_mode().ok();
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend).context("create terminal")?;

    let mut app = AppState::new(rx, app_tx, setup_script);
    app.push_log_line("Hyprland Setup TUI - ratatui + crossterm");
    app.push_log_line("Use Arrow Up/Down to select, Enter to run");
    app.push_log_line("Keys: q=quit, c=clear log, k=kill process, PgUp/PgDn=scroll");
    if app.setup_script.is_none() {
        app.push_log_line("setup.sh not found automatically. Set $HYPR_SETUP_PATH or run from repo root.");
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

        terminal.draw(|f| draw_ui(f, app)).context("draw ui")?;

        let timeout = tick_rate.saturating_sub(app.last_tick.elapsed());
        if event::poll(timeout).context("poll events")? {
            match event::read().context("read event")? {
                Event::Key(key) => {
                    if handle_key_event(app, key)? {
                        break;
                    }
                }
                Event::Mouse(_) | Event::Resize(_, _) | Event::FocusGained | Event::FocusLost | Event::Paste(_) => {}
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

    let items: Vec<ListItem> = app
        .items
        .iter()
        .map(|i| ListItem::new(Line::from(Span::raw(i.label))))
        .collect();
    let menu = List::new(items)
        .block(
            Block::default()
                .title("Hyprland Setup Actions")
                .borders(Borders::ALL),
        )
        .highlight_style(Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD))
        .highlight_symbol("▶ ");
    f.render_stateful_widget(menu, chunks[0], &mut app.list_state);

    let selected = app.selected_index();
    let desc = app.items.get(selected).map(|i| i.description).unwrap_or("");
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
        Line::from(vec![Span::styled("Selected: ", Style::default().fg(Color::Yellow)), Span::raw(desc)]),
        Line::from(vec![Span::styled("Script: ", Style::default().fg(Color::Yellow)), Span::raw(script_path_text)]),
        Line::from("q=quit  c=clear  k=kill  ↑↓=navigate  Enter=run  PgUp/PgDn=scroll"),
    ])
    .block(Block::default().title("Info").borders(Borders::ALL))
    .wrap(Wrap { trim: false });
    f.render_widget(header, right_chunks[0]);

    let log_text: Vec<Line> = app
        .logs
        .iter()
        .map(|l| Line::from(l.clone()))
        .collect();
    let logs = Paragraph::new(log_text)
        .block(Block::default().title("Output").borders(Borders::ALL))
        .scroll((app.scroll, 0))
        .wrap(Wrap { trim: false });
    f.render_widget(logs, right_chunks[1]);

    // Footer with keybind help
    let footer = Paragraph::new(Text::from(vec![
        Line::from(
            "Keys: ↑/↓ select  Enter run  q quit  c clear  k kill  PgUp/PgDn scroll",
        ),
    ]))
    .block(Block::default().borders(Borders::ALL));
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
        Line::from("Preflight configuration - set values, then press Enter to start"),
        Line::from("Tab/Shift-Tab: move  Space/Left/Right: change  e: edit text  Esc: cancel edit  q: back"),
    ]))
    .block(Block::default().title("Preflight").borders(Borders::ALL));
    f.render_widget(header, chunks[0]);

    let pf = &app.preflight;
    let mut lines: Vec<Line> = Vec::new();
    lines.push(styled_field_line(
        PreflightField::PromptDefault,
        app,
        format!("Default yes to prompts: {}", if pf.prompt_default_yes { "Yes" } else { "No" }),
    ));
    lines.push(styled_field_line(
        PreflightField::FishLanguage,
        app,
        format!("Fish language: {}", match pf.fish_language_choice { 1 => "de_CH", 2 => "de_DE", 3 => "en_US", _ => "de_CH" }),
    ));
    lines.push(styled_field_line(
        PreflightField::WallpaperDir,
        app,
        format!("Wallpaper dir: {}", pf.wallpaper_dir),
    ));
    lines.push(styled_field_line(
        PreflightField::MonitorEnabled,
        app,
        format!("Monitor setup enabled: {}", if pf.monitor_setup_enabled { "Yes" } else { "No" }),
    ));
    lines.push(styled_field_line(
        PreflightField::MonitorConfig,
        app,
        format!("Monitor config: {}", if pf.monitor_config.is_empty() { "<empty>".to_string() } else { pf.monitor_config.clone() }),
    ));
    lines.push(styled_field_line(
        PreflightField::AutoContinue,
        app,
        format!("Auto-continue on warnings: {}", if pf.auto_continue_on_warnings { "Yes" } else { "No" }),
    ));
    lines.push(styled_field_line(
        PreflightField::Start,
        app,
        "Start unattended install (Enter)".to_string(),
    ));

    let body = Paragraph::new(Text::from(lines))
        .block(Block::default().title("Values").borders(Borders::ALL))
        .wrap(Wrap { trim: false });
    f.render_widget(body, chunks[1]);

    let help = Paragraph::new(Text::from(vec![
        Line::from("Keys: Tab/Shift-Tab move  ←/→ change  Space toggle  e edit  Esc cancel  Enter start  q back"),
        Line::from("MONITOR_CONFIG: name:1920x1080@60:1.0;name2:2560x1440@144:1.25"),
    ]))
    .block(Block::default().borders(Borders::ALL));
    f.render_widget(help, chunks[2]);
}

fn styled_field_line(field: PreflightField, app: &AppState, text: String) -> Line<'static> {
    let selected = app.preflight_focus == field;
    if selected {
        Line::from(Span::styled(text, Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD)))
    } else {
        Line::from(Span::raw(text))
    }
}

fn handle_key_event(app: &mut AppState, key: KeyEvent) -> Result<bool> {
    match app.ui_mode {
        UiMode::Menu => match key.code {
            KeyCode::Char('q') => return Ok(true),
            KeyCode::Up => move_selection(app, -1),
            KeyCode::Down => move_selection(app, 1),
            KeyCode::PageUp => {
                app.scroll = app.scroll.saturating_sub(8);
            }
            KeyCode::PageDown => {
                app.scroll = app.scroll.saturating_add(8);
            }
            KeyCode::Char('c') if key.modifiers.is_empty() => {
                app.logs.clear();
                app.scroll = 0;
            }
            KeyCode::Char('k') if key.modifiers.is_empty() => {
                kill_child(app);
            }
            KeyCode::Enter => {
                // Before running, open preflight
                let idx = app.selected_index();
                let item = &app.items[idx];
                match item.action {
                    MenuAction::Quit => return Ok(true),
                    _ => app.ui_mode = UiMode::Preflight,
                }
            }
            KeyCode::Char('C') if key.modifiers.contains(KeyModifiers::CONTROL) => {
                kill_child(app);
            }
            _ => {}
        },
        UiMode::Preflight => return handle_preflight_keys(app, key),
    }
    Ok(false)
}

fn move_selection(app: &mut AppState, delta: isize) {
    let len = app.items.len() as isize;
    let current = app.selected_index() as isize;
    let mut next = current + delta;
    if next < 0 {
        next = len - 1;
    }
    if next >= len {
        next = 0;
    }
    app.list_state.select(Some(next as usize));
}

fn run_selected_action(app: &mut AppState) -> Result<()> {
    let idx = app.selected_index();
    let item = &app.items[idx];
    match item.action {
        MenuAction::Quit => return Ok(()),
        MenuAction::FullSetup => spawn_setup(app, &[]),
        MenuAction::DryRun => spawn_setup(app, &["--dry-run"]),
        MenuAction::ConfigureMonitorOnly => spawn_setup(app, &["--configure-monitor"]),
        MenuAction::ConfigureSddmOnly => spawn_setup(app, &["--configure-sddm"]),
    }
}

fn spawn_setup(app: &mut AppState, flags: &[&str]) -> Result<()> {
    if app.process.is_some() {
        app.push_log_line("A process is already running. Kill it first (k) or wait.");
        return Ok(());
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

    let mut cmd = Command::new("bash");
    cmd.arg(script);
    for f in flags {
        cmd.arg(f);
    }
    // Non-interactive env config from preflight
    let pf = &app.preflight;
    cmd.env("NON_INTERACTIVE", "true");
    cmd.env("PROMPT_DEFAULT_YN", if pf.prompt_default_yes { "y" } else { "n" });
    cmd.env("FISH_LANGUAGE_CHOICE_OVERRIDE", pf.fish_language_choice.to_string());
    cmd.env("WALLPAPER_DIR_OVERRIDE", pf.wallpaper_dir.clone());
    cmd.env("MONITOR_SETUP_ENABLED", if pf.monitor_setup_enabled { "true" } else { "false" });
    if !pf.monitor_config.trim().is_empty() {
        cmd.env("MONITOR_CONFIG", pf.monitor_config.clone());
    }
    cmd.env(
        "AUTO_CONTINUE_ON_WARNINGS",
        if pf.auto_continue_on_warnings { "true" } else { "false" },
    );

    cmd.stdout(Stdio::piped()).stderr(Stdio::piped());

    app.push_log_line(format!("$ {:?}", &cmd));
    let mut child = cmd.spawn().context("spawn setup.sh")?;

    let stdout = child.stdout.take();
    let stderr = child.stderr.take();
    let tx_out = app.tx.clone();
    if let Some(stdout) = stdout {
        thread::spawn(move || {
            let reader = BufReader::new(stdout);
            for line in reader.lines().flatten() {
                let _ = tx_out.send(line);
            }
        });
    }
    let tx_err = app.tx.clone();
    if let Some(stderr) = stderr {
        thread::spawn(move || {
            let reader = BufReader::new(stderr);
            for line in reader.lines().flatten() {
                let _ = tx_err.send(line);
            }
        });
    }

    app.process = Some(ProcessHandles { child });
    Ok(())
}

fn kill_child(app: &mut AppState) {
    if let Some(mut handles) = app.process.take() {
        let _ = handles.child.kill();
        let _ = handles.child.wait();
        app.push_log_line("Process killed.");
    } else {
        app.push_log_line("No running process.");
    }
}

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
    for c in candidates {
        if c.exists() {
            return Some(c);
        }
    }
    None
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
    if let Some(script) = setup_script {
        if let Some(root) = script.parent() {
            let wp = root.join("Wallpaper");
            return Some(wp.display().to_string());
        }
    }
    Some("./Wallpaper".to_string())
}

fn handle_preflight_keys(app: &mut AppState, key: KeyEvent) -> Result<bool> {
    if app.editing {
        match key.code {
            KeyCode::Esc => {
                app.editing = false;
                app.edit_buffer.clear();
            }
            KeyCode::Enter => {
                apply_edit_buffer(app);
                app.editing = false;
                app.edit_buffer.clear();
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
        KeyCode::Char('q') => {
            app.ui_mode = UiMode::Menu;
        }
        KeyCode::Tab => preflight_focus_next(app),
        KeyCode::BackTab => preflight_focus_prev(app),
        KeyCode::Left => adjust_preflight_field(app, -1),
        KeyCode::Right => adjust_preflight_field(app, 1),
        KeyCode::Char(' ') => toggle_boolean_field(app),
        KeyCode::Char('e') => begin_editing(app),
        KeyCode::Enter => {
            // Start
            app.ui_mode = UiMode::Menu; // return to menu for logs visibility
            // Determine which menu action was selected when opening preflight
            let idx = app.selected_index();
            let item = &app.items[idx];
            match item.action {
                MenuAction::FullSetup => run_selected_action(app)?,
                MenuAction::DryRun => run_selected_action(app)?,
                MenuAction::ConfigureMonitorOnly => run_selected_action(app)?,
                MenuAction::ConfigureSddmOnly => run_selected_action(app)?,
                MenuAction::Quit => {}
            }
        }
        _ => {}
    }
    Ok(false)
}

fn preflight_focus_next(app: &mut AppState) {
    app.preflight_focus = match app.preflight_focus {
        PreflightField::PromptDefault => PreflightField::FishLanguage,
        PreflightField::FishLanguage => PreflightField::WallpaperDir,
        PreflightField::WallpaperDir => PreflightField::MonitorEnabled,
        PreflightField::MonitorEnabled => PreflightField::MonitorConfig,
        PreflightField::MonitorConfig => PreflightField::AutoContinue,
        PreflightField::AutoContinue => PreflightField::Start,
        PreflightField::Start => PreflightField::PromptDefault,
    };
}

fn preflight_focus_prev(app: &mut AppState) {
    app.preflight_focus = match app.preflight_focus {
        PreflightField::PromptDefault => PreflightField::Start,
        PreflightField::FishLanguage => PreflightField::PromptDefault,
        PreflightField::WallpaperDir => PreflightField::FishLanguage,
        PreflightField::MonitorEnabled => PreflightField::WallpaperDir,
        PreflightField::MonitorConfig => PreflightField::MonitorEnabled,
        PreflightField::AutoContinue => PreflightField::MonitorConfig,
        PreflightField::Start => PreflightField::AutoContinue,
    };
}

fn adjust_preflight_field(app: &mut AppState, delta: i32) {
    match app.preflight_focus {
        PreflightField::FishLanguage => {
            let mut v = app.preflight.fish_language_choice as i32 + delta;
            if v < 1 { v = 3; }
            if v > 3 { v = 1; }
            app.preflight.fish_language_choice = v as u8;
        }
        PreflightField::PromptDefault => {
            app.preflight.prompt_default_yes = delta >= 0;
        }
        _ => {}
    }
}

fn toggle_boolean_field(app: &mut AppState) {
    match app.preflight_focus {
        PreflightField::PromptDefault => app.preflight.prompt_default_yes = !app.preflight.prompt_default_yes,
        PreflightField::MonitorEnabled => app.preflight.monitor_setup_enabled = !app.preflight.monitor_setup_enabled,
        PreflightField::AutoContinue => app.preflight.auto_continue_on_warnings = !app.preflight.auto_continue_on_warnings,
        _ => {}
    }
}

fn begin_editing(app: &mut AppState) {
    match app.preflight_focus {
        PreflightField::WallpaperDir => {
            app.editing = true;
            app.edit_buffer = app.preflight.wallpaper_dir.clone();
        }
        PreflightField::MonitorConfig => {
            app.editing = true;
            app.edit_buffer = app.preflight.monitor_config.clone();
        }
        _ => {}
    }
}

fn apply_edit_buffer(app: &mut AppState) {
    match app.preflight_focus {
        PreflightField::WallpaperDir => {
            app.preflight.wallpaper_dir = app.edit_buffer.clone();
        }
        PreflightField::MonitorConfig => {
            app.preflight.monitor_config = app.edit_buffer.clone();
        }
        _ => {}
    }
}


