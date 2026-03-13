use ratatui::{
    layout::Rect,
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph},
    Frame,
};

use crate::app::App;

pub fn render(f: &mut Frame, _app: &App, area: Rect) {
    let h = Style::default().add_modifier(Modifier::BOLD | Modifier::UNDERLINED);
    let k = Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD);
    let d = Style::default().fg(Color::DarkGray);
    let w = Style::default().fg(Color::White);

    macro_rules! row {
        ($key:expr, $desc:expr) => {
            Line::from(vec![
                Span::styled(format!("  {:<28}", $key), k),
                Span::styled($desc, w),
            ])
        };
    }
    macro_rules! head {
        ($s:expr) => { Line::from(Span::styled($s, h)) };
    }

    let lines = vec![
        Line::from(Span::styled(
            " OpenClaw TUI — dragun.app",
            Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD),
        )),
        Line::from(Span::styled(" Remote management for Termux → VPS", d)),
        Line::from(""),
        head!(" Global"),
        row!("1-5  /  Tab / Shift+Tab", "Switch tabs"),
        row!("r",                        "Refresh current view"),
        row!("Ctrl-C  /  q",             "Quit"),
        Line::from(""),
        head!(" Dashboard (1)"),
        row!("p",                        "Toggle panic mode  (confirm required)"),
        Line::from(""),
        head!(" HITL Queue (2)"),
        row!("↑/↓  k/j",                 "Navigate tasks"),
        row!("y  /  a",                  "Approve selected task"),
        row!("n  /  d",                  "Reject  (prompts for reason)"),
        Line::from(""),
        head!(" Logs (3)"),
        row!("←/→  h/l",                 "Switch source: system / orchestrator / devsecops / growth"),
        row!("↑/↓  k/j",                 "Scroll"),
        row!("f",                        "Toggle follow mode (auto-scroll to bottom)"),
        Line::from(""),
        head!(" Costs (4)"),
        row!("↑/↓  k/j",                 "Scroll cost report"),
        Line::from(""),
        head!(" Config"),
        Line::from(vec![
            Span::styled("  ~/.config/openclaw-tui/config.toml", k),
        ]),
        Line::from(vec![
            Span::styled("  or env: OPENCLAW_VPS_HOST  OPENCLAW_VPS_USER  OPENCLAW_SSH_KEY", d),
        ]),
        Line::from(""),
        head!(" Caps  (enforced by orchestrator)"),
        Line::from(vec![Span::styled("  Global $5/day  |  DevSecOps $3/day  |  Growth $2/day", w)]),
        Line::from(vec![Span::styled("  Panic auto-triggers at $4.50 global spend", d)]),
    ];

    let para = Paragraph::new(lines)
        .block(Block::default().borders(Borders::ALL).title(" Help "));
    f.render_widget(para, area);
}
