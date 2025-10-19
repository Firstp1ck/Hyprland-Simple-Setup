use std::io::{self};
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::mpsc::{self, Receiver, Sender};
use std::thread;
use std::time::{Duration, Instant};

use anyhow::{Context, Result, bail};
use chrono::Local;
use crossterm::event::{self, Event, KeyCode, KeyEvent};
use crossterm::terminal::{
    EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode,
};
use crossterm::{execute, terminal};
use ratatui::Terminal;
use ratatui::backend::CrosstermBackend;
use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span, Text};
use ratatui::widgets::{Block, Borders, Clear, List, ListItem, ListState, Paragraph, Wrap};
use std::fs::OpenOptions;
use std::io::Read as IoRead;
use std::io::Write as IoWrite;

// MenuAction/MenuItem and process tracking removed to simplify and avoid warnings

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
    Start,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum EditKind {
    None,
    Text,
    MonitorWizard,
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
}

impl AppState {
    fn new(rx: Receiver<String>, tx: Sender<String>, setup_script: Option<PathBuf>) -> Self {
        let mut list_state = ListState::default();
        list_state.select(Some(0));
        let default_wallpaper =
            guess_default_wallpaper_dir(&setup_script).unwrap_or_else(|| "./Wallpaper".to_string());
        let logfile_path = std::env::var("HYPRLAND_SETUP_LOG")
            .map(PathBuf::from)
            .unwrap_or_else(|_| {
                let mut p = dirs::home_dir().unwrap_or_else(|| PathBuf::from("."));
                p.push("Hyprland-Setup.log");
                p
            });
        Self {
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
            preflight_focus: PreflightField::Start,
            editing: false,
            edit_buffer: String::new(),
            edit_kind: EditKind::None,
            mw_monitors: Vec::new(),
            mw_selected_monitor: 0,
            mw_selected_mode: 0,
            mw_selected_scale: 1, // default 1.0
            mw_active_col: 0,
            mw_buffer: String::new(),
        }
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
    terminal::enable_raw_mode().ok();
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

        terminal.draw(|f| draw_ui(f, app)).context("draw ui")?;

        let timeout = tick_rate.saturating_sub(app.last_tick.elapsed());
        if event::poll(timeout).context("poll events")? {
            match event::read().context("read event")? {
                Event::Key(key) => {
                    if handle_key_event(app, key)? {
                        break;
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

    let items: Vec<ListItem> = vec![ListItem::new(Line::from(Span::raw("Run Hyprland setup")))];
    let menu = List::new(items)
        .block(
            Block::default()
                .title("Hyprland Setup Actions")
                .borders(Borders::ALL),
        )
        .highlight_style(
            Style::default()
                .fg(Color::Cyan)
                .add_modifier(Modifier::BOLD),
        )
        .highlight_symbol("▶ ");
    f.render_stateful_widget(menu, chunks[0], &mut app.list_state);

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
            Span::styled("Selected: ", Style::default().fg(Color::Yellow)),
            Span::raw(desc),
        ]),
        Line::from(vec![
            Span::styled("Script: ", Style::default().fg(Color::Yellow)),
            Span::raw(script_path_text),
        ]),
        Line::from("q=quit  c=clear  k=kill  ↑↓=navigate  Enter=run  PgUp/PgDn=scroll"),
    ])
    .block(Block::default().title("Info").borders(Borders::ALL))
    .wrap(Wrap { trim: false });
    f.render_widget(header, right_chunks[0]);

    let log_text: Vec<Line> = app.logs.iter().map(|l| Line::from(l.clone())).collect();
    // Calculate scroll so that new output is anchored at the bottom when following
    let mut y_offset = app.scroll as usize;
    if app.follow_tail {
        let visible = right_chunks[1].height.saturating_sub(2) as usize; // approx: border lines
        let total = app.logs.len();
        y_offset = total.saturating_sub(visible);
    } else {
        // Clamp when not following
        let max_scroll = app.logs.len().saturating_sub(1);
        if y_offset > max_scroll {
            y_offset = max_scroll;
        }
    }
    let logs = Paragraph::new(log_text)
        .block(
            Block::default()
                .title("Output (PgUp/PgDn scroll, End follow, Home top)")
                .borders(Borders::ALL),
        )
        .scroll((y_offset as u16, 0))
        .wrap(Wrap { trim: false });
    f.render_widget(logs, right_chunks[1]);

    // Footer with keybind help
    let footer = Paragraph::new(Text::from(vec![Line::from(
        "Keys: Enter open preflight  q quit",
    )]))
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
        Line::from("Tab/Shift-Tab: move  Space/Left/Right: change  1/2/3: set language  e/Enter: edit text  Esc: cancel edit  q: back"),
        Line::from("Left label shows how to change each option: [Toggle] or [Edit]"),
    ]))
    .block(Block::default().title("Preflight").borders(Borders::ALL));
    f.render_widget(header, chunks[0]);

    let pf = &app.preflight;
    let mut lines: Vec<Line> = Vec::new();
    lines.push(styled_field_line(
        PreflightField::EnvPromptDefaultYn,
        app,
        format!(
            "[Toggle] PROMPT_DEFAULT_YN: {}",
            if pf.prompt_default_yes { "y" } else { "n" }
        ),
    ));
    lines.push(styled_field_line(
        PreflightField::EnvFishLanguageChoiceOverride,
        app,
        format!(
            "[1/2/3] FISH_LANGUAGE_CHOICE_OVERRIDE: {} (1=de_CH,2=de_DE,3=en_US)",
            pf.fish_language_choice
        ),
    ));
    lines.push(styled_field_line(
        PreflightField::EnvWallpaperDirOverride,
        app,
        format!("[Edit] WALLPAPER_DIR_OVERRIDE: {}", pf.wallpaper_dir),
    ));
    lines.push(styled_field_line(
        PreflightField::EnvMonitorSetupEnabled,
        app,
        format!(
            "[Toggle] MONITOR_SETUP_ENABLED: {}",
            if pf.monitor_setup_enabled {
                "true"
            } else {
                "false"
            }
        ),
    ));
    lines.push(styled_field_line(
        PreflightField::EnvMonitorConfig,
        app,
        format!(
            "[Edit] MONITOR_CONFIG: {}",
            if pf.monitor_config.is_empty() {
                "<empty>".to_string()
            } else {
                pf.monitor_config.clone()
            }
        ),
    ));
    lines.push(styled_field_line(
        PreflightField::EnvAutoContinueOnWarnings,
        app,
        format!(
            "[Toggle] AUTO_CONTINUE_ON_WARNINGS: {}",
            if pf.auto_continue_on_warnings {
                "true"
            } else {
                "false"
            }
        ),
    ));
    lines.push(styled_field_line(
        PreflightField::Password,
        app,
        format!(
            "[Edit/required] Password: {}",
            if pf.password.is_empty() {
                "<empty>"
            } else {
                "******"
            }
        ),
    ));
    lines.push(styled_field_line(
        PreflightField::EnvDryRun,
        app,
        format!(
            "[Toggle] DRY_RUN (--dry-run): {}",
            if pf.dry_run { "true" } else { "false" }
        ),
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
        Line::from(
            "Keys: Tab/Shift-Tab or j/k or ↑/↓ move  ←/→ change  Space toggle  e edit  Enter start  q back",
        ),
        Line::from("MONITOR_CONFIG: name:1920x1080@60:1.0;name2:2560x1440@144:1.25"),
    ];
    let help = Paragraph::new(Text::from(help_lines)).block(Block::default().borders(Borders::ALL));
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

        let title = Paragraph::new(Text::from(vec![Line::from(field.to_string())]));
        f.render_widget(title, inner_chunks[0]);

        let input_title = if matches!(app.preflight_focus, PreflightField::Password) {
            "Input (hidden)"
        } else {
            "Input"
        };
        let input = Paragraph::new(Text::from(vec![Line::from(buffer_with_caret)]))
            .block(Block::default().title(input_title).borders(Borders::ALL));
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
            .borders(Borders::ALL);
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
            "Active: {}   Tab switch column  j/k/↑/↓ move  Enter add selection  x remove last  s save  Esc cancel",
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
                    .fg(Color::Cyan)
                    .add_modifier(Modifier::BOLD),
            )
            .highlight_symbol("▶ ")
            .block(
                Block::default()
                    .title("Monitors")
                    .borders(Borders::ALL)
                    .border_style(if app.mw_active_col == 0 {
                        Style::default().fg(Color::Yellow)
                    } else {
                        Style::default()
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
                    .fg(Color::Cyan)
                    .add_modifier(Modifier::BOLD),
            )
            .highlight_symbol("▶ ")
            .block(
                Block::default()
                    .title("Modes")
                    .borders(Borders::ALL)
                    .border_style(if app.mw_active_col == 1 {
                        Style::default().fg(Color::Yellow)
                    } else {
                        Style::default()
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
                    .fg(Color::Cyan)
                    .add_modifier(Modifier::BOLD),
            )
            .highlight_symbol("▶ ")
            .block(
                Block::default()
                    .title("Scale")
                    .borders(Borders::ALL)
                    .border_style(if app.mw_active_col == 2 {
                        Style::default().fg(Color::Yellow)
                    } else {
                        Style::default()
                    }),
            );
        f.render_stateful_widget(scale_list, cols[2], &mut scale_state);

        // Current buffer and tips
        let current = Paragraph::new(Text::from(vec![Line::from(format!(
            "Current: {}",
            app.mw_buffer
        ))]))
        .block(Block::default().title("Selection").borders(Borders::ALL));
        f.render_widget(current, rows[2]);

        let bottom_help = Paragraph::new(Text::from(vec![Line::from(
            "Enter adds: name:WxH@Hz:scale;   s saves to MONITOR_CONFIG   x removes last",
        )]));
        f.render_widget(bottom_help, rows[3]);
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
                Style::default()
                    .fg(Color::Cyan)
                    .add_modifier(Modifier::BOLD),
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
            KeyCode::Enter => {
                app.ui_mode = UiMode::Preflight;
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
        cmd.arg(script);
        for f in flags {
            cmd.arg(f);
        }
    }
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
        && let Some(root) = script.parent()
    {
        let wp = root.join("Wallpaper");
        return Some(wp.display().to_string());
    }
    Some("./Wallpaper".to_string())
}

fn handle_preflight_keys(app: &mut AppState, key: KeyEvent) -> Result<bool> {
    if app.editing {
        if app.edit_kind == EditKind::MonitorWizard {
            // Wizard navigation and operations
            match key.code {
                KeyCode::Esc => {
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
        }
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
                        app.push_log_line("Password is required to continue.");
                        return Ok(false);
                    }
                    app.ui_mode = UiMode::Menu; // return to menu for logs visibility
                    if app.preflight.dry_run {
                        spawn_setup(app, &["--dry-run"])?;
                    } else {
                        spawn_setup(app, &[])?;
                    }
                }
                PreflightField::EnvWallpaperDirOverride => begin_editing(app),
                PreflightField::EnvMonitorConfig => begin_editing(app),
                PreflightField::Password => begin_editing(app),
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
        PreflightField::Password => PreflightField::EnvDryRun,
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
        PreflightField::EnvDryRun => PreflightField::Password,
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
        _ => {}
    }
}

fn apply_edit_buffer(app: &mut AppState) {
    match app.preflight_focus {
        PreflightField::EnvWallpaperDirOverride => {
            app.preflight.wallpaper_dir = app.edit_buffer.clone();
            app.edit_kind = EditKind::None;
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
