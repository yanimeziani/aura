use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};

use crate::ssh::{HitlTask, StatusData};

// ── tabs ──────────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Tab {
    Dashboard,
    Hitl,
    Logs,
    Costs,
    Help,
}

impl Tab {
    pub const ALL: &'static [Tab] = &[
        Tab::Dashboard, Tab::Hitl, Tab::Logs, Tab::Costs, Tab::Help,
    ];
    pub fn title(self) -> &'static str {
        match self {
            Tab::Dashboard => "Dashboard",
            Tab::Hitl      => "HITL Queue",
            Tab::Logs      => "Logs",
            Tab::Costs     => "Costs",
            Tab::Help      => "Help",
        }
    }
    pub fn index(self) -> usize {
        Self::ALL.iter().position(|t| *t == self).unwrap_or(0)
    }
}

// ── log sources ───────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LogSource {
    System,
    Orchestrator,
    Devsecops,
    Growth,
}

impl LogSource {
    pub const ALL: &'static [LogSource] = &[
        LogSource::System, LogSource::Orchestrator, LogSource::Devsecops, LogSource::Growth,
    ];
    pub fn name(self) -> &'static str {
        match self {
            LogSource::System       => "system",
            LogSource::Orchestrator => "orchestrator",
            LogSource::Devsecops    => "devsecops",
            LogSource::Growth       => "growth",
        }
    }
    pub fn index(self) -> usize {
        Self::ALL.iter().position(|s| *s == self).unwrap_or(0)
    }
}

// ── input overlay ─────────────────────────────────────────────────────────────

#[derive(Debug, Clone, PartialEq)]
pub enum Overlay {
    None,
    RejectReason,
    ConfirmPanic,
}

// ── pending actions (deferred to main loop so we can draw before awaiting) ────

#[derive(Debug)]
pub enum Pending {
    RefreshAll,
    RefreshQueue,
    RefreshLogs,
    RefreshCosts,
    Approve(String),
    Reject(String, String),
    SetPanic(bool),
}

// ── app state ─────────────────────────────────────────────────────────────────

pub struct App {
    // navigation
    pub tab:            Tab,
    pub overlay:        Overlay,

    // dashboard
    pub status:         Option<StatusData>,
    pub status_err:     Option<String>,
    pub loading:        bool,
    pub last_refresh:   Option<std::time::Instant>,

    // hitl queue
    pub queue:          Vec<HitlTask>,
    pub queue_sel:      usize,
    pub queue_err:      Option<String>,

    // logs
    pub log_src:        LogSource,
    pub log_lines:      Vec<String>,
    pub log_scroll:     usize,
    pub log_follow:     bool,
    pub log_err:        Option<String>,

    // costs
    pub cost_lines:     Vec<String>,
    pub cost_scroll:    usize,
    pub cost_err:       Option<String>,

    // input state
    pub input_buf:      String,

    // status bar message
    pub status_msg:     Option<(String, bool)>, // (text, is_error)

    // deferred async work
    pub pending:        Option<Pending>,
}

impl App {
    pub fn new() -> Self {
        App {
            tab:          Tab::Dashboard,
            overlay:      Overlay::None,
            status:       None,
            status_err:   None,
            loading:      false,
            last_refresh: None,
            queue:        Vec::new(),
            queue_sel:    0,
            queue_err:    None,
            log_src:      LogSource::System,
            log_lines:    Vec::new(),
            log_scroll:   0,
            log_follow:   true,
            log_err:      None,
            cost_lines:   Vec::new(),
            cost_scroll:  0,
            cost_err:     None,
            input_buf:    String::new(),
            status_msg:   None,
            pending:      Some(Pending::RefreshAll),
        }
    }

    /// Take the pending action (if any) for execution in the main loop.
    pub fn take_pending(&mut self) -> Option<Pending> {
        self.pending.take()
    }

    // ── apply results ─────────────────────────────────────────────────────

    pub fn apply_status(&mut self, result: anyhow::Result<StatusData>) {
        self.loading = false;
        match result {
            Ok(s)  => { self.status = Some(s); self.status_err = None; }
            Err(e) => { self.status_err = Some(e.to_string()); }
        }
        self.last_refresh = Some(std::time::Instant::now());
    }

    pub fn apply_queue(&mut self, result: anyhow::Result<Vec<HitlTask>>) {
        match result {
            Ok(q)  => {
                self.queue = q;
                if self.queue_sel >= self.queue.len() {
                    self.queue_sel = self.queue.len().saturating_sub(1);
                }
                self.queue_err = None;
            }
            Err(e) => self.queue_err = Some(e.to_string()),
        }
    }

    pub fn apply_logs(&mut self, result: anyhow::Result<Vec<String>>) {
        match result {
            Ok(lines) => {
                self.log_lines = lines;
                self.log_err = None;
                if self.log_follow {
                    self.log_scroll = self.log_lines.len().saturating_sub(1);
                }
            }
            Err(e) => self.log_err = Some(e.to_string()),
        }
    }

    pub fn apply_costs(&mut self, result: anyhow::Result<Vec<String>>) {
        match result {
            Ok(lines) => { self.cost_lines = lines; self.cost_err = None; }
            Err(e)    => self.cost_err = Some(e.to_string()),
        }
    }

    pub fn set_msg(&mut self, msg: impl Into<String>, err: bool) {
        self.status_msg = Some((msg.into(), err));
    }

    // ── keyboard handling (sync — queues async work via self.pending) ─────

    /// Returns true if the app should quit.
    pub fn handle_key(&mut self, key: KeyEvent) -> bool {
        // Global: Ctrl-C / Ctrl-Q always quit
        if key.modifiers.contains(KeyModifiers::CONTROL) {
            if matches!(key.code, KeyCode::Char('c') | KeyCode::Char('q')) {
                return true;
            }
        }

        match &self.overlay {
            Overlay::RejectReason => self.handle_reject_input(key),
            Overlay::ConfirmPanic => self.handle_panic_confirm(key),
            Overlay::None         => self.handle_normal(key),
        }
        false
    }

    fn handle_normal(&mut self, key: KeyEvent) {
        match key.code {
            KeyCode::Char('q') | KeyCode::Char('Q') => { /* handled above */ }

            // Number keys — jump to tab
            KeyCode::Char('1') => self.switch_tab(Tab::Dashboard),
            KeyCode::Char('2') => self.switch_tab(Tab::Hitl),
            KeyCode::Char('3') => self.switch_tab(Tab::Logs),
            KeyCode::Char('4') => self.switch_tab(Tab::Costs),
            KeyCode::Char('5') => self.switch_tab(Tab::Help),

            // Tab cycling
            KeyCode::Tab => {
                let i = (self.tab.index() + 1) % Tab::ALL.len();
                self.switch_tab(Tab::ALL[i]);
            }
            KeyCode::BackTab => {
                let i = (self.tab.index() + Tab::ALL.len() - 1) % Tab::ALL.len();
                self.switch_tab(Tab::ALL[i]);
            }

            // Global refresh
            KeyCode::Char('r') | KeyCode::Char('R') => {
                self.loading = true;
                self.pending = Some(Pending::RefreshAll);
            }

            // Tab-specific keys
            _ => match self.tab {
                Tab::Dashboard => self.handle_dashboard(key),
                Tab::Hitl      => self.handle_hitl(key),
                Tab::Logs      => self.handle_logs(key),
                Tab::Costs     => self.handle_costs(key),
                Tab::Help      => {}
            },
        }
    }

    fn switch_tab(&mut self, tab: Tab) {
        self.tab = tab;
        self.status_msg = None;
        match tab {
            Tab::Hitl  => self.pending = Some(Pending::RefreshQueue),
            Tab::Logs  => self.pending = Some(Pending::RefreshLogs),
            Tab::Costs => self.pending = Some(Pending::RefreshCosts),
            _          => {}
        }
    }

    fn handle_dashboard(&mut self, key: KeyEvent) {
        if matches!(key.code, KeyCode::Char('p') | KeyCode::Char('P')) {
            self.overlay = Overlay::ConfirmPanic;
        }
    }

    fn handle_hitl(&mut self, key: KeyEvent) {
        match key.code {
            KeyCode::Down | KeyCode::Char('j') => {
                if self.queue_sel + 1 < self.queue.len() {
                    self.queue_sel += 1;
                }
            }
            KeyCode::Up | KeyCode::Char('k') => {
                self.queue_sel = self.queue_sel.saturating_sub(1);
            }
            KeyCode::Char('y') | KeyCode::Char('a') => {
                if let Some(t) = self.queue.get(self.queue_sel) {
                    let tid = t.task_id.clone();
                    self.pending = Some(Pending::Approve(tid));
                }
            }
            KeyCode::Char('n') | KeyCode::Char('d') => {
                if !self.queue.is_empty() {
                    self.overlay = Overlay::RejectReason;
                    self.input_buf.clear();
                }
            }
            _ => {}
        }
    }

    fn handle_logs(&mut self, key: KeyEvent) {
        match key.code {
            KeyCode::Down | KeyCode::Char('j') => {
                if self.log_scroll + 1 < self.log_lines.len() {
                    self.log_scroll += 1;
                    self.log_follow = false;
                }
            }
            KeyCode::Up | KeyCode::Char('k') => {
                self.log_scroll = self.log_scroll.saturating_sub(1);
                self.log_follow = false;
            }
            KeyCode::Char('f') | KeyCode::Char('F') => {
                self.log_follow = !self.log_follow;
                if self.log_follow {
                    self.log_scroll = self.log_lines.len().saturating_sub(1);
                }
            }
            KeyCode::Right | KeyCode::Char('l') => {
                let i = (self.log_src.index() + 1) % LogSource::ALL.len();
                self.log_src = LogSource::ALL[i];
                self.pending = Some(Pending::RefreshLogs);
            }
            KeyCode::Left | KeyCode::Char('h') => {
                let i = (self.log_src.index() + LogSource::ALL.len() - 1) % LogSource::ALL.len();
                self.log_src = LogSource::ALL[i];
                self.pending = Some(Pending::RefreshLogs);
            }
            _ => {}
        }
    }

    fn handle_costs(&mut self, key: KeyEvent) {
        match key.code {
            KeyCode::Down | KeyCode::Char('j') => {
                if self.cost_scroll + 1 < self.cost_lines.len() {
                    self.cost_scroll += 1;
                }
            }
            KeyCode::Up | KeyCode::Char('k') => {
                self.cost_scroll = self.cost_scroll.saturating_sub(1);
            }
            _ => {}
        }
    }

    fn handle_reject_input(&mut self, key: KeyEvent) {
        match key.code {
            KeyCode::Enter => {
                let reason = self.input_buf.clone();
                self.input_buf.clear();
                self.overlay = Overlay::None;
                if let Some(t) = self.queue.get(self.queue_sel) {
                    let tid = t.task_id.clone();
                    self.pending = Some(Pending::Reject(tid, reason));
                }
            }
            KeyCode::Esc => {
                self.overlay = Overlay::None;
                self.input_buf.clear();
            }
            KeyCode::Char(c) => self.input_buf.push(c),
            KeyCode::Backspace => { self.input_buf.pop(); }
            _ => {}
        }
    }

    fn handle_panic_confirm(&mut self, key: KeyEvent) {
        match key.code {
            KeyCode::Char('y') | KeyCode::Char('Y') => {
                self.overlay = Overlay::None;
                let on = !self.status.as_ref().map(|s| s.panic_mode).unwrap_or(false);
                self.pending = Some(Pending::SetPanic(on));
            }
            _ => {
                self.overlay = Overlay::None;
                self.set_msg("Cancelled.", false);
            }
        }
    }
}
