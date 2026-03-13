use anyhow::{bail, Result};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub vps: VpsConfig,
    #[serde(default)]
    pub ui: UiConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VpsConfig {
    pub host: String,
    pub user: String,
    #[serde(default = "default_port")]
    pub port: u16,
    /// Path to SSH private key (optional; uses ssh-agent / default if absent)
    pub identity_file: Option<String>,
    #[serde(default = "default_openclaw_dir")]
    pub openclaw_dir: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct UiConfig {
    #[serde(default = "default_refresh")]
    pub refresh_secs: u64,
}

fn default_port() -> u16 { 22 }
fn default_openclaw_dir() -> String { "/data/openclaw".to_string() }
fn default_refresh() -> u64 { 10 }

fn config_path() -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
    PathBuf::from(home)
        .join(".config")
        .join("openclaw-tui")
        .join("config.toml")
}

impl Config {
    pub fn load() -> Result<Self> {
        let path = config_path();

        if path.exists() {
            let s = std::fs::read_to_string(&path)?;
            return Ok(toml::from_str(&s)?);
        }

        // Env-var fallback (good for cockpit.conf sourcing)
        if let Ok(host) = std::env::var("OPENCLAW_VPS_HOST") {
            return Ok(Config {
                vps: VpsConfig {
                    host,
                    user: std::env::var("OPENCLAW_VPS_USER")
                        .unwrap_or_else(|_| "openclaw".to_string()),
                    port: std::env::var("OPENCLAW_VPS_PORT")
                        .ok()
                        .and_then(|p| p.parse().ok())
                        .unwrap_or(22),
                    identity_file: std::env::var("OPENCLAW_SSH_KEY").ok(),
                    openclaw_dir: std::env::var("OPENCLAW_DIR")
                        .unwrap_or_else(|_| "/data/openclaw".to_string()),
                },
                ui: UiConfig::default(),
            });
        }

        bail!(
            "No config found.\n\
             Create {path} or set OPENCLAW_VPS_HOST.\n\
             See config.example.toml for reference.",
            path = path.display()
        )
    }

    /// Returns the ssh(1) argument list up to and including user@host.
    pub fn ssh_args(&self) -> Vec<String> {
        let mut args = vec![
            "-p".to_string(), self.vps.port.to_string(),
            "-o".to_string(), "StrictHostKeyChecking=accept-new".to_string(),
            "-o".to_string(), "ConnectTimeout=10".to_string(),
            "-o".to_string(), "BatchMode=yes".to_string(),
        ];
        if let Some(ref key) = self.vps.identity_file {
            args.extend(["-i".to_string(), key.clone()]);
        }
        args.push(format!("{}@{}", self.vps.user, self.vps.host));
        args
    }
}
