use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Gauge, List, ListItem, Paragraph},
    Frame,
};

use crate::app::App;

pub fn render(f: &mut Frame, app: &App, area: Rect) {
    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(9), // agents + status panel
            Constraint::Length(3), // cost gauge
            Constraint::Min(4),    // ops summary
        ])
        .split(area);

    render_agents_panel(f, app, rows[0]);
    render_cost_gauge(f, app, rows[1]);
    render_ops_panel(f, app, rows[2]);
}

fn render_agents_panel(f: &mut Frame, app: &App, area: Rect) {
    let cols = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(62), Constraint::Percentage(38)])
        .split(area);

    // ── container list ──────────────────────────────────────────────────
    let mut items: Vec<ListItem> = Vec::new();

    if app.loading && app.status.is_none() {
        items.push(ListItem::new(Line::from(Span::styled(
            "  Connecting to VPS…",
            Style::default().fg(Color::Yellow),
        ))));
    } else if let Some(err) = &app.status_err {
        items.push(ListItem::new(Line::from(Span::styled(
            format!("  SSH error: {}", &err[..err.len().min(55)]),
            Style::default().fg(Color::Red),
        ))));
    } else if let Some(s) = &app.status {
        for c in &s.containers {
            let (icon, col) = match c.status.as_str() {
                "running" => ("● ", Color::Green),
                "exited"  => ("✗ ", Color::Red),
                "paused"  => ("⏸ ", Color::Yellow),
                _         => ("? ", Color::DarkGray),
            };
            let health_col = match c.health.as_str() {
                "healthy"   => Color::Green,
                "unhealthy" => Color::Red,
                "starting"  => Color::Yellow,
                _           => Color::DarkGray,
            };
            items.push(ListItem::new(Line::from(vec![
                Span::styled(icon, Style::default().fg(col)),
                Span::styled(
                    format!("{:<22}", c.name),
                    Style::default().fg(Color::White),
                ),
                Span::styled(
                    format!("{:<10}", c.status),
                    Style::default().fg(col),
                ),
                Span::styled(
                    format!("({})", c.health),
                    Style::default().fg(health_col).add_modifier(Modifier::DIM),
                ),
            ])));
        }
    }

    let list = List::new(items).block(
        Block::default()
            .borders(Borders::ALL)
            .title(" Agents "),
    );
    f.render_widget(list, cols[0]);

    // ── status panel ────────────────────────────────────────────────────
    let mut lines: Vec<Line> = Vec::new();

    if let Some(s) = &app.status {
        // HITL
        let (hitl_icon, hitl_col, hitl_txt) = if s.hitl_pending > 0 {
            ("⚠ ", Color::Yellow, format!("{} pending  [→ tab 2]", s.hitl_pending))
        } else {
            ("✓ ", Color::Green, "clear".to_string())
        };
        lines.push(Line::from(vec![
            Span::styled("HITL   ", Style::default().add_modifier(Modifier::BOLD)),
            Span::styled(hitl_icon, Style::default().fg(hitl_col)),
            Span::styled(hitl_txt, Style::default().fg(hitl_col)),
        ]));
        lines.push(Line::from(""));

        // Panic
        let (p_col, p_txt) = if s.panic_mode {
            (Color::Red, "ON  ← [p] to deactivate")
        } else {
            (Color::Green, "off    [p] to activate")
        };
        lines.push(Line::from(vec![
            Span::styled("Panic  ", Style::default().add_modifier(Modifier::BOLD)),
            Span::styled(p_txt, Style::default().fg(p_col).add_modifier(Modifier::BOLD)),
        ]));
        lines.push(Line::from(""));

        // Uptime
        lines.push(Line::from(vec![
            Span::styled("Uptime ", Style::default().add_modifier(Modifier::BOLD)),
            Span::styled(&s.uptime, Style::default().fg(Color::DarkGray)),
        ]));
    }

    let panel = Paragraph::new(lines)
        .block(Block::default().borders(Borders::ALL).title(" Status "));
    f.render_widget(panel, cols[1]);
}

fn render_cost_gauge(f: &mut Frame, app: &App, area: Rect) {
    let (spend, pct) = app
        .status
        .as_ref()
        .map(|s| (s.cost_today.clone(), s.spend_pct))
        .unwrap_or_else(|| ("?".to_string(), 0.0));

    let ratio = (pct / 100.0).clamp(0.0, 1.0);
    let col = if ratio > 0.9 {
        Color::Red
    } else if ratio > 0.7 {
        Color::Yellow
    } else {
        Color::Green
    };

    let gauge = Gauge::default()
        .block(Block::default().borders(Borders::ALL).title(" Daily Cost (global cap $5.00) "))
        .gauge_style(Style::default().fg(col).bg(Color::DarkGray))
        .label(format!("${spend} / $5.00  ({pct:.0}%)"))
        .ratio(ratio);

    f.render_widget(gauge, area);
}

fn render_ops_panel(f: &mut Frame, app: &App, area: Rect) {
    let mut lines: Vec<Line> = Vec::new();

    if let Some(s) = &app.status {
        lines.push(Line::from(vec![
            Span::styled("Last deploy  ", Style::default().add_modifier(Modifier::BOLD)),
            Span::styled(&s.last_deploy, Style::default().fg(Color::Cyan)),
        ]));
        lines.push(Line::from(vec![
            Span::styled("Last alert   ", Style::default().add_modifier(Modifier::BOLD)),
            Span::styled(&s.last_alert, Style::default().fg(Color::DarkGray)),
        ]));

        let ago = app.last_refresh.map(|t| {
            let s = t.elapsed().as_secs();
            if s < 60 { format!("{s}s ago") } else { format!("{}m ago", s / 60) }
        }).unwrap_or_else(|| "never".to_string());

        lines.push(Line::from(""));
        lines.push(Line::from(vec![
            Span::styled(
                format!("Auto-refresh every 10s  (last: {ago})  r=now  p=panic  Tab=switch  q=quit"),
                Style::default().fg(Color::DarkGray),
            ),
        ]));
    }

    let panel = Paragraph::new(lines)
        .block(Block::default().borders(Borders::ALL).title(" Ops "));
    f.render_widget(panel, area);
}
