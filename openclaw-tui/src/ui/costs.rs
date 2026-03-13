use ratatui::{
    layout::Rect,
    style::{Color, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, Paragraph},
    Frame,
};

use crate::app::App;

pub fn render(f: &mut Frame, app: &App, area: Rect) {
    if let Some(err) = &app.cost_err {
        let p = Paragraph::new(format!("SSH error: {err}"))
            .block(Block::default().borders(Borders::ALL).title(" Costs "))
            .style(Style::default().fg(Color::Red));
        f.render_widget(p, area);
        return;
    }

    if app.cost_lines.is_empty() {
        let p = Paragraph::new(
            "\n  No cost report for today yet.\n\n  \
             DevSecOps agent generates one daily at 02:00 UTC.\n\n  r to refresh",
        )
        .block(Block::default().borders(Borders::ALL).title(" Costs "))
        .style(Style::default().fg(Color::DarkGray));
        f.render_widget(p, area);
        return;
    }

    let viewport_h = area.height.saturating_sub(2) as usize;
    let start = app
        .cost_scroll
        .min(app.cost_lines.len().saturating_sub(viewport_h));

    let items: Vec<ListItem> = app.cost_lines
        .iter()
        .skip(start)
        .take(viewport_h)
        .map(|line| {
            let col = if line.starts_with("##") {
                Color::Cyan
            } else if line.contains("PANIC") || line.contains("cap") {
                Color::Red
            } else if line.contains("Growth") || line.contains("growth") {
                Color::Yellow
            } else if line.contains("DevSecOps") || line.contains("devsecops") {
                Color::Green
            } else if line.starts_with('-') || line.starts_with('*') {
                Color::White
            } else {
                Color::DarkGray
            };

            ListItem::new(Line::from(Span::styled(line.clone(), Style::default().fg(col))))
        })
        .collect();

    let list = List::new(items).block(
        Block::default()
            .borders(Borders::ALL)
            .title(format!(" Daily Cost Report — ↑↓ scroll  r refresh  (caps: DevSecOps $3 | Growth $2 | Global $5) ")),
    );
    f.render_widget(list, area);
}
