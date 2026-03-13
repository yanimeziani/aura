mod costs;
mod dashboard;
mod help;
mod hitl;
mod logs;

use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::Line,
    widgets::{Block, Borders, Clear, Paragraph, Tabs},
    Frame,
};

use crate::app::{App, Overlay, Tab};

pub fn render(f: &mut Frame, app: &App) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // tab bar
            Constraint::Min(0),    // content
            Constraint::Length(1), // status bar
        ])
        .split(f.area());

    render_tab_bar(f, app, chunks[0]);

    match app.tab {
        Tab::Dashboard => dashboard::render(f, app, chunks[1]),
        Tab::Hitl      => hitl::render(f, app, chunks[1]),
        Tab::Logs      => logs::render(f, app, chunks[1]),
        Tab::Costs     => costs::render(f, app, chunks[1]),
        Tab::Help      => help::render(f, app, chunks[1]),
    }

    render_status_bar(f, app, chunks[2]);

    // Overlay dialogs (rendered last so they appear on top)
    match &app.overlay {
        Overlay::RejectReason  => render_reject_input(f, app),
        Overlay::ConfirmPanic  => render_confirm_dialog(
            f,
            " Confirm Panic Mode ",
            if app.status.as_ref().map(|s| s.panic_mode).unwrap_or(false) {
                "Deactivate panic mode? Growth will resume.  [y] confirm  [n] cancel"
            } else {
                "Activate panic mode? Growth paused, DevSecOps cheap-only.  [y] confirm  [n] cancel"
            },
            Color::Red,
        ),
        Overlay::None => {}
    }
}

// ── tab bar ───────────────────────────────────────────────────────────────────

fn render_tab_bar(f: &mut Frame, app: &App, area: Rect) {
    let titles: Vec<Line> = Tab::ALL
        .iter()
        .map(|tab| {
            let mut label = format!(" {} ", tab.title());
            if *tab == Tab::Hitl {
                if let Some(s) = &app.status {
                    if s.hitl_pending > 0 {
                        label = format!(" {} [{}] ", tab.title(), s.hitl_pending);
                    }
                }
            }
            Line::from(label)
        })
        .collect();

    let loading_suffix = if app.loading { "  ⟳ " } else { "" };

    let tabs = Tabs::new(titles)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .title(format!(" OpenClaw TUI — dragun.app{loading_suffix} "))
                .title_style(
                    Style::default()
                        .fg(Color::Cyan)
                        .add_modifier(Modifier::BOLD),
                ),
        )
        .select(app.tab.index())
        .style(Style::default().fg(Color::DarkGray))
        .highlight_style(
            Style::default()
                .fg(Color::White)
                .add_modifier(Modifier::BOLD),
        );

    f.render_widget(tabs, area);
}

// ── status bar ────────────────────────────────────────────────────────────────

fn render_status_bar(f: &mut Frame, app: &App, area: Rect) {
    let (text, col) = if let Some((msg, is_err)) = &app.status_msg {
        (msg.as_str(), if *is_err { Color::Red } else { Color::Green })
    } else {
        let hint = match app.tab {
            Tab::Dashboard => " r:refresh  p:panic  Tab:switch  q:quit",
            Tab::Hitl      => " y/a:approve  n/d:reject  ↑↓:nav  r:refresh  q:quit",
            Tab::Logs      => " ←→:source  f:follow  ↑↓:scroll  r:refresh  q:quit",
            Tab::Costs     => " ↑↓:scroll  r:refresh  q:quit",
            Tab::Help      => " Tab:switch  q:quit",
        };
        (hint, Color::DarkGray)
    };
    f.render_widget(
        Paragraph::new(text).style(Style::default().fg(col)),
        area,
    );
}

// ── overlay helpers ───────────────────────────────────────────────────────────

fn render_reject_input(f: &mut Frame, app: &App) {
    let area = centered(60, 5, f.area());
    let para = Paragraph::new(app.input_buf.as_str())
        .block(
            Block::default()
                .borders(Borders::ALL)
                .title(" Reject reason (Enter=confirm  Esc=cancel) ")
                .border_style(Style::default().fg(Color::Yellow)),
        )
        .style(Style::default().fg(Color::White));
    f.render_widget(Clear, area);
    f.render_widget(para, area);
}

fn render_confirm_dialog(f: &mut Frame, title: &str, msg: &str, col: Color) {
    let area = centered(60, 5, f.area());
    let para = Paragraph::new(msg)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .title(title)
                .border_style(Style::default().fg(col)),
        )
        .style(Style::default().fg(Color::Yellow));
    f.render_widget(Clear, area);
    f.render_widget(para, area);
}

fn centered(pct_x: u16, rows: u16, r: Rect) -> Rect {
    let v = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Percentage((100u16.saturating_sub(rows.saturating_mul(5))) / 2),
            Constraint::Length(rows),
            Constraint::Percentage((100u16.saturating_sub(rows.saturating_mul(5))) / 2),
        ])
        .split(r);
    Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage((100 - pct_x) / 2),
            Constraint::Percentage(pct_x),
            Constraint::Percentage((100 - pct_x) / 2),
        ])
        .split(v[1])[1]
}
