use anyhow::Result;
use std::sync::Arc;
use tokio::process::Command;

use crate::config::Config;

// ── runner ───────────────────────────────────────────────────────────────────

pub struct SshRunner {
    pub config: Arc<Config>,
}

impl SshRunner {
    pub fn new(config: Arc<Config>) -> Self {
        Self { config }
    }

    pub async fn run(&self, remote_cmd: &str) -> Result<String> {
        let mut args = self.config.ssh_args();
        args.push(remote_cmd.to_string());

        let out = Command::new("ssh").args(&args).output().await?;

        if out.status.success() {
            Ok(String::from_utf8_lossy(&out.stdout).into_owned())
        } else {
            let err = String::from_utf8_lossy(&out.stderr).into_owned();
            Err(anyhow::anyhow!("{}", err.trim()))
        }
    }

    // ── high-level queries ────────────────────────────────────────────────

    pub async fn fetch_status(&self) -> Result<StatusData> {
        // Use string replacement so docker Go-template braces survive intact.
        let dir = &self.config.vps.openclaw_dir;
        let script = STATUS_SCRIPT.replace("{DIR}", dir);
        let raw = self.run(&script).await?;
        StatusData::parse(&raw)
    }

    pub async fn fetch_queue(&self) -> Result<Vec<HitlTask>> {
        let dir = &self.config.vps.openclaw_dir;
        let script = format!(
            "set +e; for f in {dir}/hitl-queue/pending/*.json; do \
             [ -f \"$f\" ] || continue; echo '---task---'; cat \"$f\"; echo; done",
        );
        let raw = self.run(&script).await?;
        Ok(HitlTask::parse_all(&raw))
    }

    pub async fn fetch_logs(&self, agent: &str, tail: usize) -> Result<Vec<String>> {
        let dir = &self.config.vps.openclaw_dir;
        // tail the matching log file(s); strip ANSI before sending
        let script = format!(
            "tail -n {tail} {dir}/logs/openclaw-*{agent}*.log 2>/dev/null \
             | grep -v '^==>\\|^$' | cat"
        );
        let raw = self.run(&script).await?;
        Ok(raw.lines().map(|l| strip_ansi(l).trim().to_string()).filter(|l| !l.is_empty()).collect())
    }

    pub async fn fetch_costs(&self) -> Result<Vec<String>> {
        let dir = &self.config.vps.openclaw_dir;
        let script = format!(
            "cat {dir}/artifacts/devsecops/cost_report_$(date +%Y-%m-%d).md 2>/dev/null \
             || echo 'No cost report for today yet.'"
        );
        let raw = self.run(&script).await?;
        Ok(raw.lines().map(|l| strip_ansi(l)).collect())
    }

    // ── control operations ────────────────────────────────────────────────

    pub async fn approve(&self, task_id: &str) -> Result<String> {
        let tid = shell_safe(task_id);
        self.run(&format!("openclaw approve '{tid}'")).await
    }

    pub async fn reject(&self, task_id: &str, reason: &str) -> Result<String> {
        let tid = shell_safe(task_id);
        let rsn = shell_safe(reason);
        self.run(&format!("openclaw reject '{tid}' --reason '{rsn}'")).await
    }

    pub async fn set_panic(&self, on: bool) -> Result<String> {
        self.run(&format!(
            "openclaw panic {}",
            if on { "on" } else { "off" }
        ))
        .await
    }

    #[allow(dead_code)]
    pub async fn agent_action(&self, action: &str, agent: &str) -> Result<String> {
        let act  = shell_safe(action);
        let agnt = shell_safe(agent);
        self.run(&format!("openclaw agent '{act}' '{agnt}'")).await
    }
}

// ── helpers ───────────────────────────────────────────────────────────────────

/// Allow only chars safe to embed in single-quoted shell args.
fn shell_safe(s: &str) -> String {
    s.chars()
        .filter(|c| c.is_alphanumeric() || "-_.:/ ".contains(*c))
        .collect()
}

pub fn strip_ansi(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut chars = s.chars().peekable();
    while let Some(c) = chars.next() {
        if c == '\x1b' && chars.peek() == Some(&'[') {
            chars.next(); // consume '['
            for c2 in chars.by_ref() {
                if c2.is_ascii_alphabetic() {
                    break;
                }
            }
        } else {
            out.push(c);
        }
    }
    out
}

// ── status script (literal — no Rust format substitution on braces) ───────────

/// Placeholder {DIR} is replaced by SshRunner::fetch_status at call time.
const STATUS_SCRIPT: &str = r#"set +e
echo '---containers---'
for c in openclaw agent-devsecops agent-growth caddy vector; do
  s=$(docker inspect --format='{{.State.Status}}' "$c" 2>/dev/null || echo not_found)
  h=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}n/a{{end}}' "$c" 2>/dev/null || echo n/a)
  echo "$c $s $h"
done
echo '---hitl---'
ls {DIR}/hitl-queue/pending/*.json 2>/dev/null | wc -l
echo '---panic---'
test -f {DIR}/state/panic_mode && echo on || echo off
echo '---costs---'
grep -m1 'Global:' {DIR}/artifacts/devsecops/cost_report_$(date +%Y-%m-%d).md 2>/dev/null \
  | sed 's/.*Global: //' | cut -d'/' -f1 | tr -d ' $' || echo '?'
echo '---spend_pct---'
grep -m1 'Global:' {DIR}/artifacts/devsecops/cost_report_$(date +%Y-%m-%d).md 2>/dev/null \
  | grep -oP '\d+(\.\d+)?(?=%)' | head -1 || echo '0'
echo '---uptime---'
uptime | sed 's/^ *//'
echo '---last_alert---'
tail -1 {DIR}/logs/openclaw-system-system.log 2>/dev/null \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('message','')[:80])" 2>/dev/null || echo '—'
echo '---last_deploy---'
ls -1t {DIR}/artifacts/devsecops/deploy_*.md 2>/dev/null | head -1 \
  | xargs basename 2>/dev/null | sed 's/deploy_//;s/.md//' || echo 'none'
"#;

// ── data models ───────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Default)]
pub struct StatusData {
    pub containers:   Vec<ContainerState>,
    pub hitl_pending: usize,
    pub panic_mode:   bool,
    pub cost_today:   String,
    pub spend_pct:    f64,       // 0–100
    pub uptime:       String,
    pub last_alert:   String,
    pub last_deploy:  String,
}

#[derive(Debug, Clone)]
pub struct ContainerState {
    pub name:   String,
    pub status: String, // running | exited | paused | not_found
    pub health: String, // healthy | unhealthy | starting | n/a
}

impl StatusData {
    fn parse(raw: &str) -> Result<Self> {
        let mut data = StatusData::default();
        let mut section = "";
        for line in raw.lines() {
            let l = line.trim();
            match l {
                "---containers---"  => section = "containers",
                "---hitl---"        => section = "hitl",
                "---panic---"       => section = "panic",
                "---costs---"       => section = "costs",
                "---spend_pct---"   => section = "spend_pct",
                "---uptime---"      => section = "uptime",
                "---last_alert---"  => section = "last_alert",
                "---last_deploy---" => section = "last_deploy",
                "" => {}
                _ => match section {
                    "containers" => {
                        let p: Vec<&str> = l.splitn(3, ' ').collect();
                        data.containers.push(ContainerState {
                            name:   p.first().unwrap_or(&"?").to_string(),
                            status: p.get(1).unwrap_or(&"?").to_string(),
                            health: p.get(2).unwrap_or(&"n/a").to_string(),
                        });
                    }
                    "hitl"        => data.hitl_pending = l.parse().unwrap_or(0),
                    "panic"       => data.panic_mode   = l == "on",
                    "costs"       => data.cost_today   = l.to_string(),
                    "spend_pct"   => data.spend_pct    = l.parse().unwrap_or(0.0),
                    "uptime"      => data.uptime       = l.to_string(),
                    "last_alert"  => data.last_alert   = l.to_string(),
                    "last_deploy" => data.last_deploy  = l.to_string(),
                    _ => {}
                },
            }
        }
        Ok(data)
    }
}

#[derive(Debug, Clone)]
pub struct HitlTask {
    pub task_id:      String,
    pub agent:        String,
    pub action:       String,
    pub blast_radius: String,
    pub reversible:   bool,
    pub gate:         String,
    pub ts:           String,
}

impl HitlTask {
    fn parse_all(raw: &str) -> Vec<Self> {
        let mut tasks = Vec::new();
        let mut buf = String::new();
        let mut active = false;

        for line in raw.lines() {
            if line == "---task---" {
                if active && !buf.trim().is_empty() {
                    if let Ok(t) = Self::from_json(&buf) {
                        tasks.push(t);
                    }
                    buf.clear();
                }
                active = true;
            } else if active {
                buf.push_str(line);
                buf.push('\n');
            }
        }
        if active && !buf.trim().is_empty() {
            if let Ok(t) = Self::from_json(&buf) {
                tasks.push(t);
            }
        }
        tasks
    }

    fn from_json(json: &str) -> Result<Self> {
        let v: serde_json::Value = serde_json::from_str(json.trim())?;
        let s = |f: &str| v.get(f).and_then(|x| x.as_str()).unwrap_or("?").to_string();
        Ok(HitlTask {
            task_id:      s("task_id"),
            agent:        s("agent"),
            action:       s("action"),
            blast_radius: s("blast_radius"),
            reversible:   v.get("reversible").and_then(|x| x.as_bool()).unwrap_or(true),
            gate:         s("gate"),
            ts:           s("ts"),
        })
    }
}
