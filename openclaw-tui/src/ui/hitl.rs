use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, ListState, Paragraph},
    Frame,
};

use crate::app::App;

pub fn render(f: &mut Frame, app: &App, area: Rect) {
    if let Some(err) = &app.queue_err {
        let p = Paragraph::new(format!("SSH error: {err}"))
            .block(Block::default().borders(Borders::ALL).title(" HITL Queue "))
            .style(Style::default().fg(Color::Red));
        f.render_widget(p, area);
        return;
    }

    if app.queue.is_empty() {
        let p = Paragraph::new("\n  ✓  No pending approvals.\n\n  r to refresh")
            .block(Block::default().borders(Borders::ALL).title(" HITL Queue "))
            .style(Style::default().fg(Color::Green));
        f.render_widget(p, area);
        return;
    }

    let cols = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(40), Constraint::Percentage(60)])
        .split(area);

    // ── task list ────────────────────────────────────────────────────────
    let items: Vec<ListItem> = app.queue.iter().enumerate().map(|(i, t)| {
        let col = blast_color(&t.blast_radius);
        let sel = if i == app.queue_sel { "▶ " } else { "  " };
        ListItem::new(Line::from(vec![
            Span::styled(sel, Style::default().fg(Color::Cyan)),
            Span::styled(
                format!("{:<20}", t.task_id),
                Style::default().fg(col).add_modifier(Modifier::BOLD),
            ),
        ]))
    }).collect();

    let mut ls = ListState::default();
    ls.select(Some(app.queue_sel));

    let list = List::new(items)
        .block(Block::default().borders(Borders::ALL)
            .title(format!(" HITL Queue ({}) ", app.queue.len())))
        .highlight_style(Style::default().add_modifier(Modifier::REVERSED));

    f.render_stateful_widget(list, cols[0], &mut ls);

    // ── detail pane ──────────────────────────────────────────────────────
    if let Some(t) = app.queue.get(app.queue_sel) {
        let br_col  = blast_color(&t.blast_radius);
        let rev_col = if t.reversible { Color::Green } else { Color::Red };

        let lines: Vec<Line> = vec![
            kv("Task",       &t.task_id, Color::White),
            Line::from(""),
            kv("Agent",      &t.agent,        Color::Cyan),
            kv("Gate",       &t.gate,         Color::Yellow),
            kv("Action",     &t.action,       Color::White),
            kv("Timestamp",  &t.ts,           Color::DarkGray),
            Line::from(""),
            kv_styled("Risk",       &t.blast_radius,
                Style::default().fg(br_col).add_modifier(Modifier::BOLD)),
            kv_styled("Reversible", if t.reversible { "yes" } else { "NO" },
                Style::default().fg(rev_col)),
            Line::from(""),
            Line::from(Span::styled(
                "─────────────────────────────────",
                Style::default().fg(Color::DarkGray),
            )),
            Line::from(vec![
                Span::styled("[y/a] ", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD)),
                Span::raw("Approve   "),
                Span::styled("[n/d] ", Style::default().fg(Color::Red).add_modifier(Modifier::BOLD)),
                Span::raw("Reject (prompts reason)"),
            ]),
        ];

        let detail = Paragraph::new(lines)
            .block(Block::default().borders(Borders::ALL).title(" Task Detail "));
        f.render_widget(detail, cols[1]);
    }
}

fn blast_color(br: &str) -> Color {
    match br {
        "critical" => Color::Red,
        "high"     => Color::Yellow,
        "medium"   => Color::Cyan,
        _          => Color::White,
    }
}

fn kv<'a>(label: &'static str, val: &'a str, col: Color) -> Line<'a> {
    Line::from(vec![
        Span::styled(
            format!("{:<12}", format!("{label}:")),
            Style::default().add_modifier(Modifier::BOLD),
        ),
        Span::styled(val.to_string(), Style::default().fg(col)),
    ])
}

fn kv_styled<'a>(label: &'static str, val: &'a str, style: Style) -> Line<'a> {
    Line::from(vec![
        Span::styled(
            format!("{:<12}", format!("{label}:")),
            Style::default().add_modifier(Modifier::BOLD),
        ),
        Span::styled(val.to_string(), style),
    ])
}
