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
use ratatui::widgets::{Block, Borders, List, ListItem, ListState, Paragraph, Wrap, Clear};
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
    EnvPromptDefaultYn,
    EnvFishLanguageChoiceOverride,
    EnvWallpaperDirOverride,
    EnvMonitorSetupEnabled,
    EnvMonitorConfig,
    EnvAutoContinueOnWarnings,
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
        PreflightField::EnvPromptDefaultYn,
        app,
        format!("PROMPT_DEFAULT_YN: {}", if pf.prompt_default_yes { "y" } else { "n" }),
    ));
    lines.push(styled_field_line(
        PreflightField::EnvFishLanguageChoiceOverride,
        app,
        format!("FISH_LANGUAGE_CHOICE_OVERRIDE: {} (1=de_CH,2=de_DE,3=en_US)", pf.fish_language_choice),
    ));
    lines.push(styled_field_line(
        PreflightField::EnvWallpaperDirOverride,
        app,
        format!("WALLPAPER_DIR_OVERRIDE: {}", pf.wallpaper_dir),
    ));
    lines.push(styled_field_line(
        PreflightField::EnvMonitorSetupEnabled,
        app,
        format!("MONITOR_SETUP_ENABLED: {}", if pf.monitor_setup_enabled { "true" } else { "false" }),
    ));
    lines.push(styled_field_line(
        PreflightField::EnvMonitorConfig,
        app,
        format!("MONITOR_CONFIG: {}", if pf.monitor_config.is_empty() { "<empty>".to_string() } else { pf.monitor_config.clone() }),
    ));
    lines.push(styled_field_line(
        PreflightField::EnvAutoContinueOnWarnings,
        app,
        format!("AUTO_CONTINUE_ON_WARNINGS: {}", if pf.auto_continue_on_warnings { "true" } else { "false" }),
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

    // Bottom help (when not editing)
    let help_lines: Vec<Line> = vec![
        Line::from("Keys: Tab/Shift-Tab or j/k or ↑/↓ move  ←/→ change  Space toggle  e edit  Enter start  q back"),
        Line::from("MONITOR_CONFIG: name:1920x1080@60:1.0;name2:2560x1440@144:1.25"),
    ];
    let help = Paragraph::new(Text::from(help_lines))
        .block(Block::default().borders(Borders::ALL));
    f.render_widget(help, chunks[2]);

    // Center popup for editing
    if app.editing {
        let area_w = area.width as i32;
        let popup_w = (area_w * 3 / 4).max(30) as u16; // 75% width, min 30
        let popup_h = 7u16; // title + input + help
        let popup_x = area.x + (area.width.saturating_sub(popup_w)) / 2;
        let popup_y = area.y + (area.height.saturating_sub(popup_h)) / 2;
        let popup_rect = Rect { x: popup_x, y: popup_y, width: popup_w, height: popup_h };

        let field = match app.preflight_focus {
            PreflightField::EnvWallpaperDirOverride => "WALLPAPER_DIR_OVERRIDE",
            PreflightField::EnvMonitorConfig => "MONITOR_CONFIG",
            _ => "",
        };
        let caret = "▏";
        let buffer_with_caret = format!("{}{}", app.edit_buffer, caret);

        // Clear area under popup
        f.render_widget(Clear, popup_rect);

        // Draw popup content
        let popup_block = Block::default().title("Edit value").borders(Borders::ALL);
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

        let title = Paragraph::new(Text::from(vec![Line::from(format!("{}", field))]));
        f.render_widget(title, inner_chunks[0]);

        let input = Paragraph::new(Text::from(vec![Line::from(buffer_with_caret)])).block(
            Block::default().title("Input").borders(Borders::ALL),
        );
        f.render_widget(input, inner_chunks[1]);

        let tip = Paragraph::new(Text::from(vec![
            Line::from("Enter save  Esc cancel  (type to edit, Backspace deletes)"),
        ]));
        f.render_widget(tip, inner_chunks[2]);
    }
}

fn styled_field_line(field: PreflightField, app: &AppState, text: String) -> Line<'static> {
    let selected = app.preflight_focus == field;
    if selected {
        if app.editing {
            Line::from(vec![
                Span::styled(
                    text,
                    Style::default()
                        .fg(Color::Yellow)
                        .add_modifier(Modifier::BOLD | Modifier::UNDERLINED),
                ),
                Span::raw("  "),
                Span::styled("[editing]", Style::default().fg(Color::Yellow)),
            ])
        } else {
            Line::from(Span::styled(
                text,
                Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD),
            ))
        }
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

    // Use a PTY via `script` to keep all outputs contained in the TUI area (progress bars, sudo prompts, etc.)
    // Fallback to direct bash execution if `script` is unavailable.
    let mut cmd;
    let cmdline = {
        let mut s = String::from("bash ");
        s.push_str(&script.display().to_string());
        for f in flags { s.push(' '); s.push_str(f); }
        s
    };

    if which::which("script").is_ok() {
        // script -q (quiet) -f (flush) -c "<cmd>" /dev/null
        cmd = Command::new("script");
        cmd.arg("-q").arg("-f").arg("-c").arg(cmdline).arg("/dev/null");
    } else {
        cmd = Command::new("bash");
        cmd.arg(script);
        for f in flags { cmd.arg(f); }
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

    cmd.stdin(Stdio::null()).stdout(Stdio::piped()).stderr(Stdio::piped());

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
        KeyCode::Tab | KeyCode::Char('j') | KeyCode::Down => preflight_focus_next(app),
        KeyCode::BackTab | KeyCode::Char('k') | KeyCode::Up => preflight_focus_prev(app),
        KeyCode::Left => adjust_preflight_field(app, -1),
        KeyCode::Right => adjust_preflight_field(app, 1),
        KeyCode::Char(' ') => toggle_boolean_field(app),
        KeyCode::Char('e') => begin_editing(app),
        KeyCode::Enter => {
            // Enter: start only if Start is focused; otherwise, begin editing if field is editable
            match app.preflight_focus {
                PreflightField::Start => {
                    app.ui_mode = UiMode::Menu; // return to menu for logs visibility
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
                PreflightField::EnvWallpaperDirOverride | PreflightField::EnvMonitorConfig => {
                    begin_editing(app);
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
        PreflightField::EnvAutoContinueOnWarnings => PreflightField::Start,
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
        PreflightField::Start => PreflightField::EnvAutoContinueOnWarnings,
    };
}

fn adjust_preflight_field(app: &mut AppState, delta: i32) {
    match app.preflight_focus {
        PreflightField::EnvFishLanguageChoiceOverride => {
            let mut v = app.preflight.fish_language_choice as i32 + delta;
            if v < 1 { v = 3; }
            if v > 3 { v = 1; }
            app.preflight.fish_language_choice = v as u8;
        }
        PreflightField::EnvPromptDefaultYn => {
            app.preflight.prompt_default_yes = delta >= 0;
        }
        _ => {}
    }
}

fn toggle_boolean_field(app: &mut AppState) {
    match app.preflight_focus {
        PreflightField::EnvPromptDefaultYn => app.preflight.prompt_default_yes = !app.preflight.prompt_default_yes,
        PreflightField::EnvMonitorSetupEnabled => app.preflight.monitor_setup_enabled = !app.preflight.monitor_setup_enabled,
        PreflightField::EnvAutoContinueOnWarnings => app.preflight.auto_continue_on_warnings = !app.preflight.auto_continue_on_warnings,
        _ => {}
    }
}

fn begin_editing(app: &mut AppState) {
    match app.preflight_focus {
        PreflightField::EnvWallpaperDirOverride => {
            app.editing = true;
            app.edit_buffer = app.preflight.wallpaper_dir.clone();
        }
        PreflightField::EnvMonitorConfig => {
            app.editing = true;
            app.edit_buffer = app.preflight.monitor_config.clone();
        }
        _ => {}
    }
}

fn apply_edit_buffer(app: &mut AppState) {
    match app.preflight_focus {
        PreflightField::EnvWallpaperDirOverride => {
            app.preflight.wallpaper_dir = app.edit_buffer.clone();
        }
        PreflightField::EnvMonitorConfig => {
            app.preflight.monitor_config = app.edit_buffer.clone();
        }
        _ => {}
    }
}


