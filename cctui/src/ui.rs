use ratatui::{
    layout::{Constraint, Direction, Layout},
    style::{Color, Modifier, Style},
    widgets::{Block, Borders, List, ListItem, Paragraph},
    Frame,
};

use crate::app::App;

pub fn draw(f: &mut Frame, app: &App) {
    let area = f.area();

    // Three rows: [output | input (3) | status bar (1)]
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Min(3),
            Constraint::Length(3),
            Constraint::Length(1),
        ])
        .split(area);

    // ── Output area ─────────────────────────────────────────────────────────
    let viewport_h = chunks[0].height.saturating_sub(2) as usize; // minus borders
    let total      = app.lines.len();
    let start      = app.scroll.min(total.saturating_sub(viewport_h));
    let end        = (start + viewport_h).min(total);

    let items: Vec<ListItem> = app.lines[start..end]
        .iter()
        .map(|l| ListItem::new(l.as_str()))
        .collect();

    let pin_indicator = if app.auto_scroll { "↓ live" } else { "↑ paused" };
    let scroll_label  = if total == 0 {
        format!(" [empty] ")
    } else {
        format!(" [{}/{}] {} ", end, total, pin_indicator)
    };

    let output_block = Block::default()
        .borders(Borders::ALL)
        .title(scroll_label)
        .title_style(
            Style::default()
                .fg(Color::Cyan)
                .add_modifier(Modifier::BOLD),
        );

    f.render_widget(List::new(items).block(output_block), chunks[0]);

    // ── Input area ───────────────────────────────────────────────────────────
    let input_block = Block::default()
        .borders(Borders::ALL)
        .title(" send ")
        .title_style(Style::default().fg(Color::Yellow));

    f.render_widget(
        Paragraph::new(app.input.as_str()).block(input_block),
        chunks[1],
    );

    // Place cursor inside the input box.
    f.set_cursor_position((
        chunks[1].x + 1 + app.cursor as u16,
        chunks[1].y + 1,
    ));

    // ── Status bar ───────────────────────────────────────────────────────────
    f.render_widget(
        Paragraph::new(
            "  ↑↓ scroll line   pgup/pgdn scroll page   enter send   ctrl-c quit",
        )
        .style(Style::default().fg(Color::DarkGray)),
        chunks[2],
    );
}
