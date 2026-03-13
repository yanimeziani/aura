use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, Paragraph, Tabs},
    Frame,
};

use crate::app::{App, LogSource};

pub fn render(f: &mut Frame, app: &App, area: Rect) {
    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(3), Constraint::Min(0)])
        .split(area);

    // ── source tabs ──────────────────────────────────────────────────────
    let titles: Vec<Line> = LogSource::ALL
        .iter()
        .map(|s| Line::from(format!(" {} ", s.name())))
        .collect();

    let follow_tag = if app.log_follow { " [FOLLOW]" } else { "" };
    let total_tag  = format!("  {} lines", app.log_lines.len());

    let tabs = Tabs::new(titles)
        .block(Block::default().borders(Borders::ALL).title(format!(
            " Logs{follow_tag}{total_tag} — ←/→ source  f follow  ↑↓ scroll "
        )))
        .select(app.log_src.index())
        .style(Style::default().fg(Color::DarkGray))
        .highlight_style(
            Style::default()
                .fg(Color::Cyan)
                .add_modifier(Modifier::BOLD),
        );
    f.render_widget(tabs, rows[0]);

    // ── error / empty ────────────────────────────────────────────────────
    if let Some(err) = &app.log_err {
        let p = Paragraph::new(format!("SSH error: {err}"))
            .block(Block::default().borders(Borders::ALL))
            .style(Style::default().fg(Color::Red));
        f.render_widget(p, rows[1]);
        return;
    }

    if app.log_lines.is_empty() {
        let p = Paragraph::new("\n  No log lines found yet. r to refresh.")
            .block(Block::default().borders(Borders::ALL))
            .style(Style::default().fg(Color::DarkGray));
        f.render_widget(p, rows[1]);
        return;
    }

    // ── log view ─────────────────────────────────────────────────────────
    let viewport_h = rows[1].height.saturating_sub(2) as usize;
    let total      = app.log_lines.len();
    let start      = if app.log_follow {
        total.saturating_sub(viewport_h)
    } else {
        app.log_scroll.saturating_sub(viewport_h / 2).min(total.saturating_sub(viewport_h))
    };

    let items: Vec<ListItem> = app.log_lines
        .iter()
        .skip(start)
        .take(viewport_h)
        .map(|line| {
            let col = if line.contains("ERROR") || line.contains("error") {
                Color::Red
            } else if line.contains("WARN") || line.contains("warn") {
                Color::Yellow
            } else if line.contains("INFO") {
                Color::White
            } else {
                Color::DarkGray
            };

            // Truncate for narrow mobile displays
            let display = if line.len() > 180 {
                format!("{}…", &line[..180])
            } else {
                line.clone()
            };

            ListItem::new(Line::from(Span::styled(display, Style::default().fg(col))))
        })
        .collect();

    let list = List::new(items)
        .block(Block::default().borders(Borders::ALL).title(format!(
            " {} — lines {}-{} of {} ",
            app.log_src.name(),
            start + 1,
            (start + viewport_h).min(total),
            total
        )));

    f.render_widget(list, rows[1]);
}
