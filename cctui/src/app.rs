use anyhow::Result;
use crossterm::event::{self, Event, KeyCode, KeyModifiers};
use portable_pty::PtySize;
use ratatui::{backend::Backend, Terminal};
use std::io::Write;
use std::sync::mpsc::{self, Receiver};
use std::time::Duration;

use crate::pty::{self, PtyHandle};
use crate::ui;

pub struct App {
    /// All lines received from claude (ANSI stripped, \r cleaned).
    pub lines: Vec<String>,
    /// Index of the first visible line in the viewport.
    pub scroll: usize,
    /// When true, new output pins scroll to the bottom automatically.
    pub auto_scroll: bool,
    /// Current user input buffer.
    pub input: String,
    /// Byte-offset cursor inside `input`.
    pub cursor: usize,
    pub quit: bool,
    pty: PtyHandle,
    rx: Receiver<Vec<u8>>,
    /// Incomplete line fragment waiting for a newline.
    partial: String,
}

impl App {
    pub fn new(cols: u16, rows: u16) -> Result<Self> {
        let (tx, rx) = mpsc::channel();
        let pty = pty::spawn(tx, cols, rows)?;
        Ok(Self {
            lines: Vec::new(),
            scroll: 0,
            auto_scroll: true,
            input: String::new(),
            cursor: 0,
            quit: false,
            pty,
            rx,
            partial: String::new(),
        })
    }

    /// Drain all pending PTY output into `self.lines`.
    pub fn drain_pty(&mut self) {
        let mut got_new = false;
        while let Ok(chunk) = self.rx.try_recv() {
            let stripped = strip_ansi_escapes::strip(&chunk);
            let text = String::from_utf8_lossy(&stripped).replace('\r', "");
            self.partial.push_str(&text);
            while let Some(pos) = self.partial.find('\n') {
                let line = self.partial[..pos].trim_end().to_string();
                self.lines.push(line);
                self.partial = self.partial[pos + 1..].to_string();
                got_new = true;
            }
        }
        if got_new && self.auto_scroll {
            self.scroll = self.lines.len().saturating_sub(1);
        }
    }

    /// Send `self.input` to the PTY and echo it locally with a `>` prefix.
    pub fn send_input(&mut self) {
        if self.input.is_empty() {
            return;
        }
        let mut line = self.input.clone();
        line.push('\n');
        let _ = self.pty.writer.write_all(line.as_bytes());
        // Local echo so the user can see what was sent even before claude replies.
        self.lines.push(format!("> {}", self.input));
        self.input.clear();
        self.cursor = 0;
        self.auto_scroll = true;
        self.scroll = self.lines.len().saturating_sub(1);
    }

    pub fn scroll_up(&mut self, n: usize) {
        self.scroll = self.scroll.saturating_sub(n);
        self.auto_scroll = false;
    }

    pub fn scroll_down(&mut self, n: usize, viewport_h: usize) {
        let max = self.lines.len().saturating_sub(viewport_h);
        self.scroll = (self.scroll + n).min(max);
        if self.scroll >= max {
            self.auto_scroll = true;
        }
    }

    pub fn resize_pty(&self, cols: u16, rows: u16) {
        let _ = self.pty.master.resize(PtySize {
            rows,
            cols,
            pixel_width: 0,
            pixel_height: 0,
        });
    }
}

pub fn run<B: Backend>(terminal: &mut Terminal<B>) -> Result<()> {
    let size = terminal.size()?;
    let mut app = App::new(size.width, size.height)?;

    loop {
        app.drain_pty();
        terminal.draw(|f| ui::draw(f, &app))?;

        if !event::poll(Duration::from_millis(16))? {
            continue;
        }

        match event::read()? {
            Event::Key(key) => match (key.code, key.modifiers) {
                // Quit
                (KeyCode::Char('c'), KeyModifiers::CONTROL)
                | (KeyCode::Char('q'), KeyModifiers::CONTROL) => {
                    app.quit = true;
                }

                // Send
                (KeyCode::Enter, _) => app.send_input(),

                // Typing
                (KeyCode::Char(c), _) => {
                    app.input.insert(app.cursor, c);
                    app.cursor += 1;
                }
                (KeyCode::Backspace, _) => {
                    if app.cursor > 0 {
                        app.cursor -= 1;
                        app.input.remove(app.cursor);
                    }
                }
                (KeyCode::Left, _) => {
                    app.cursor = app.cursor.saturating_sub(1);
                }
                (KeyCode::Right, _) => {
                    app.cursor = (app.cursor + 1).min(app.input.len());
                }

                // Scrolling — Up/Down arrows scroll by 1, PgUp/PgDn by 10.
                // Alt+Up/Down mirror PgUp/PgDn for convenience in Termux.
                (KeyCode::Up, KeyModifiers::NONE) => app.scroll_up(1),
                (KeyCode::Down, KeyModifiers::NONE) => {
                    let vh = terminal.size()?.height.saturating_sub(6) as usize;
                    app.scroll_down(1, vh);
                }
                (KeyCode::PageUp, _)
                | (KeyCode::Up, KeyModifiers::ALT) => app.scroll_up(10),
                (KeyCode::PageDown, _)
                | (KeyCode::Down, KeyModifiers::ALT) => {
                    let vh = terminal.size()?.height.saturating_sub(6) as usize;
                    app.scroll_down(10, vh);
                }

                _ => {}
            },

            Event::Resize(cols, rows) => {
                app.resize_pty(cols, rows);
            }

            _ => {}
        }

        if app.quit {
            break;
        }
    }

    Ok(())
}
