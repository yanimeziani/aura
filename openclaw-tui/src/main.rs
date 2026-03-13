use std::io;
use std::sync::Arc;
use std::time::{Duration, Instant};

use anyhow::Result;
use crossterm::{
    event::{self, DisableMouseCapture, EnableMouseCapture, Event},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{backend::CrosstermBackend, Terminal};

mod app;
mod config;
mod ssh;
mod ui;

use app::{App, Pending};
use config::Config;
use ssh::SshRunner;

#[tokio::main(flavor = "current_thread")]
async fn main() -> Result<()> {
    let cfg = Arc::new(Config::load()?);
    let runner = Arc::new(SshRunner::new(cfg.clone()));
    let refresh = Duration::from_secs(cfg.ui.refresh_secs.max(5));

    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let mut app = App::new();
    let result = run(&mut terminal, &mut app, &runner, refresh).await;

    // Always restore terminal even on error
    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )?;
    terminal.show_cursor()?;

    result
}

async fn run<B: ratatui::backend::Backend>(
    terminal: &mut Terminal<B>,
    app: &mut App,
    runner: &SshRunner,
    refresh_interval: Duration,
) -> Result<()> {
    let mut last_tick = Instant::now();

    loop {
        // ── 1. Execute any queued async action (draw loading state first) ──
        if let Some(action) = app.take_pending() {
            app.loading = true;
            terminal.draw(|f| ui::render(f, app))?;

            execute_action(action, app, runner).await;

            app.loading = false;
            // Clear status bar hint after action completes (keep error msgs)
        }

        // ── 2. Draw ────────────────────────────────────────────────────────
        terminal.draw(|f| ui::render(f, app))?;

        // ── 3. Poll keyboard (short timeout for responsiveness) ───────────
        if event::poll(Duration::from_millis(80))? {
            if let Event::Key(key) = event::read()? {
                if app.handle_key(key) {
                    return Ok(());
                }
            }
        }

        // ── 4. Auto-refresh tick ──────────────────────────────────────────
        if last_tick.elapsed() >= refresh_interval && app.pending.is_none() {
            app.pending = Some(Pending::RefreshAll);
            last_tick = Instant::now();
        }
    }
}

async fn execute_action(action: Pending, app: &mut App, runner: &SshRunner) {
    match action {
        Pending::RefreshAll => {
            let r = runner.fetch_status().await;
            app.apply_status(r);
            // Also refresh active data tab in background
            match app.tab {
                app::Tab::Hitl => {
                    app.apply_queue(runner.fetch_queue().await);
                }
                app::Tab::Logs => {
                    app.apply_logs(runner.fetch_logs(app.log_src.name(), 200).await);
                }
                app::Tab::Costs => {
                    app.apply_costs(runner.fetch_costs().await);
                }
                _ => {}
            }
        }
        Pending::RefreshQueue => {
            app.apply_queue(runner.fetch_queue().await);
        }
        Pending::RefreshLogs => {
            app.apply_logs(runner.fetch_logs(app.log_src.name(), 200).await);
        }
        Pending::RefreshCosts => {
            app.apply_costs(runner.fetch_costs().await);
        }
        Pending::Approve(tid) => {
            match runner.approve(&tid).await {
                Ok(_)  => app.set_msg(format!("✓ Approved: {tid}"), false),
                Err(e) => app.set_msg(format!("✗ Approve failed: {e}"), true),
            }
            app.apply_queue(runner.fetch_queue().await);
            // Refresh status so HITL badge updates
            app.apply_status(runner.fetch_status().await);
        }
        Pending::Reject(tid, reason) => {
            match runner.reject(&tid, &reason).await {
                Ok(_)  => app.set_msg(format!("✓ Rejected: {tid}"), false),
                Err(e) => app.set_msg(format!("✗ Reject failed: {e}"), true),
            }
            app.apply_queue(runner.fetch_queue().await);
            app.apply_status(runner.fetch_status().await);
        }
        Pending::SetPanic(on) => {
            match runner.set_panic(on).await {
                Ok(_)  => app.set_msg(
                    format!("Panic mode: {}", if on { "ON" } else { "off" }),
                    on,
                ),
                Err(e) => app.set_msg(format!("✗ Panic failed: {e}"), true),
            }
            app.apply_status(runner.fetch_status().await);
        }
    }
}
