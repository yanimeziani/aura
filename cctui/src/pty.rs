use anyhow::Result;
use portable_pty::{CommandBuilder, MasterPty, NativePtySystem, PtySize, PtySystem};
use std::io::{Read, Write};
use std::sync::mpsc::Sender;

pub struct PtyHandle {
    pub writer: Box<dyn Write + Send>,
    pub master: Box<dyn MasterPty + Send>,
}

/// Spawns `claude` inside a PTY of the given dimensions.
/// Raw output bytes are forwarded to `tx` from a background reader thread.
pub fn spawn(tx: Sender<Vec<u8>>, cols: u16, rows: u16) -> Result<PtyHandle> {
    let system = NativePtySystem::default();
    let pair = system.openpty(PtySize {
        rows,
        cols,
        pixel_width: 0,
        pixel_height: 0,
    })?;

    // Destructure now so the partial-move is explicit.
    let master = pair.master;
    let slave  = pair.slave;

    let mut cmd = CommandBuilder::new("claude");
    cmd.env("TERM", "xterm-256color");
    // Inherit the rest of the environment so PATH, HOME, etc. are available.

    let _child = slave.spawn_command(cmd)?;
    drop(slave); // child owns the slave side; dropping here is required on Linux

    let mut reader = master.try_clone_reader()?;
    let writer     = master.take_writer()?;

    std::thread::spawn(move || {
        let mut buf = [0u8; 4096];
        loop {
            match reader.read(&mut buf) {
                Ok(0) | Err(_) => break,
                Ok(n) => {
                    if tx.send(buf[..n].to_vec()).is_err() {
                        break;
                    }
                }
            }
        }
    });

    Ok(PtyHandle { writer, master })
}
