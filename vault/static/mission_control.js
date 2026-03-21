let auto = true;
let timer = null;
let lastRadioSrc = "";

const $ = (id) => document.getElementById(id);

async function fetchJson(url, opts) {
  const response = await fetch(url, opts);
  if (!response.ok) {
    throw new Error(await response.text());
  }
  return await response.json();
}

function classify(value) {
  const text = String(value || "").toLowerCase();
  if (text.includes("active") || text === "ok" || text === "true") return "ok";
  if (text.includes("missing") || text.includes("failed") || text.includes("empty") || text.includes("blocked")) return "bad";
  if (text.includes("inactive") || text.includes("unknown") || text.includes("warning") || text.includes("degraded") || text.includes("false")) return "warn";
  return "";
}

function chip(text, tone) {
  return `<span class="chip ${tone}">${text}</span>`;
}

function setVisualizer(playing) {
  const node = $("visualizer");
  if (!node) return;
  node.classList.toggle("playing", Boolean(playing));
}

function setNowPlaying(entry) {
  $("nowPlayingTitle").textContent = entry?.title || "No live bulletin yet";
  $("nowPlayingCopy").textContent = entry?.bulletin || "Start a broadcast or run the deck to hear the current state.";
}

window.playRadio = async function playRadio(src, title = "", copy = "") {
  const player = $("radioPlayer");
  player.src = src;
  lastRadioSrc = src;
  if (title || copy) {
    setNowPlaying({ title, bulletin: copy });
  }
  try {
    await player.play();
  } catch (_error) {
    // Browser autoplay rules can block playback before user interaction.
  }
};

async function refreshState() {
  const state = await fetchJson("/api/state");
  $("subline").textContent = `${state.owner} | ${state.operating_mode} | profile ${state.profile_sync}`;
  $("modeBadge").innerHTML = chip(state.operating_mode || "unknown", classify(state.operating_mode));
  $("stateOwner").textContent = state.owner || "Unknown";
  $("stateProfile").textContent = state.profile_sync || "unknown";
  $("stateSignal").textContent = (state.high_signal_entities || []).slice(0, 8).join(", ") || "none";
  $("todayList").innerHTML = (state.today_focus || []).length
    ? state.today_focus.map((item) => `<li>${item}</li>`).join("")
    : `<li class="muted">no explicit focus</li>`;
}

async function refreshHealth() {
  const health = await fetchJson("/api/health");
  $("healthTs").textContent = health.at || "unknown";
  $("vaultStatus").innerHTML = chip(health.vault, classify(health.vault));

  const envEntries = (health.envs || []).map((entry) => {
    return `<div class="entry">
      <div class="entry-head">
        <div class="entry-title">${entry.path}</div>
        <div class="entry-meta">${chip(entry.status, classify(entry.status))}</div>
      </div>
    </div>`;
  });
  $("envList").innerHTML = envEntries.join("") || `<div class="entry"><div class="muted">no env targets</div></div>`;

  const serviceEntries = (health.services || []).map((service) => {
    return `<div class="entry">
      <div class="entry-head">
        <div class="entry-title">${service.name}</div>
        <div class="entry-meta">${chip(service.status, classify(service.status))}</div>
      </div>
    </div>`;
  });
  $("serviceList").innerHTML = serviceEntries.join("") || `<div class="entry"><div class="muted">no services</div></div>`;
}

async function refreshPackets() {
  const packets = await fetchJson("/api/packets?limit=8");
  $("packetList").innerHTML = packets.length
    ? packets.map((packet) => {
        const link = `/api/packet/${encodeURIComponent(packet.name)}`;
        return `<div class="entry">
          <div class="entry-head">
            <div>
              <div class="entry-title"><a href="${link}" target="_blank" rel="noopener">${packet.name}</a></div>
              <div class="entry-meta">${packet.mtime}</div>
            </div>
            <div class="entry-meta">${(packet.size / 1024).toFixed(1)} KB</div>
          </div>
        </div>`;
      }).join("")
    : `<div class="entry"><div class="muted">no packets yet</div></div>`;
}

async function refreshRadio() {
  const [radio, deck] = await Promise.all([
    fetchJson("/api/radio?limit=8"),
    fetchJson("/api/radio_deck"),
  ]);

  const deckLabel = deck.running
    ? (deck.requested_source && deck.requested_source !== deck.source
        ? `${deck.requested_source} -> ${deck.source} • ${deck.provider || "auto"} • ${deck.interval || 60}s`
        : `${deck.source || "source"} • ${deck.provider || "auto"} • ${deck.interval || 60}s`)
    : "stopped";
  const deckTone = deck.running ? ((deck.fallback || deck.source_state !== "live") ? "warn" : "ok") : "warn";
  $("radioDeckStatus").innerHTML = chip(deckLabel, deckTone);
  $("radioStatus").textContent = deck.running
    ? (deck.degraded_reason || "constant deck live")
    : "manual mode";

  $("radioList").innerHTML = radio.length
    ? radio.map((entry) => {
        const txt = entry.files?.txt ? `/api/radio_asset/${encodeURIComponent(entry.files.txt)}` : "";
        const mp3 = entry.files?.mp3 ? `/api/radio_asset/${encodeURIComponent(entry.files.mp3)}` : "";
        const actions = mp3
          ? `<button onclick="window.playRadio('${mp3.replace(/'/g, "%27")}', '${entry.title.replace(/'/g, "%27")}', '${entry.bulletin.replace(/'/g, "%27")}')">play</button>`
          : `<span class="muted">text only</span>`;
        return `<div class="entry">
          <div class="entry-head">
            <div>
              <div class="entry-title">${entry.title}</div>
              <div class="entry-meta">${entry.source_name} • ${entry.provider_used}${entry.model ? ` • ${entry.model}` : ""} • ${entry.mtime}</div>
            </div>
            <div class="entry-actions">
              ${actions}
              ${txt ? `<a class="pill" href="${txt}" target="_blank" rel="noopener">transcript</a>` : ""}
            </div>
          </div>
          <div class="entry-copy">${entry.bulletin}</div>
        </div>`;
      }).join("")
    : `<div class="entry"><div class="muted">no radio bulletins yet</div></div>`;

  const latest = radio.find((entry) => entry.files?.mp3);
  if (latest) {
    const latestSrc = `/api/radio_asset/${encodeURIComponent(latest.files.mp3)}`;
    if (!$("radioPlayer").src) {
      $("radioPlayer").src = latestSrc;
      lastRadioSrc = latestSrc;
      setNowPlaying(latest);
    } else if (deck.running && latestSrc !== lastRadioSrc) {
      lastRadioSrc = latestSrc;
      window.playRadio(latestSrc, latest.title, latest.bulletin);
    }
  }
}

async function refreshLog() {
  const source = $("logSel").value;
  const lines = parseInt($("logLines").value, 10);
  const payload = await fetchJson(`/api/log/${encodeURIComponent(source)}?lines=${lines}`);
  $("logMeta").textContent = `${source} • ${payload.path} • tail(${lines})`;
  $("logBox").textContent = payload.text || "(empty)";
}

async function refreshAll() {
  $("tick").textContent = new Date().toISOString().replace("T", " ").slice(0, 19);
  await refreshState();
  await refreshHealth();
  await refreshPackets();
  await refreshRadio();
  await refreshLog();
}

function setAuto(enabled) {
  auto = enabled;
  $("autoBtn").textContent = auto ? "auto: on" : "auto: off";
  if (timer) clearInterval(timer);
  if (auto) timer = setInterval(() => refreshAll().catch(console.error), 2000);
}

async function makePacket() {
  const source = $("packetSource").value;
  $("makePacketBtn").textContent = "working…";
  try {
    await fetchJson("/api/make_packet", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ source, tail: 1500, audio: false }),
    });
    await refreshPackets();
  } finally {
    $("makePacketBtn").textContent = "make packet";
  }
}

async function makeRadio() {
  const source = $("radioSource").value;
  const provider = $("radioProvider").value;
  $("makeRadioBtn").textContent = "broadcasting…";
  try {
    const result = await fetchJson("/api/make_radio", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ source, provider, tail: 240, audio: true }),
    });
    if (result.audio_url) {
      await window.playRadio(result.audio_url, result.entry?.title || "Aura Radio", result.entry?.bulletin || "");
    }
    await refreshRadio();
  } finally {
    $("makeRadioBtn").textContent = "broadcast";
  }
}

async function startDeck() {
  const source = $("radioSource").value;
  const provider = $("radioProvider").value;
  const interval = parseInt($("radioInterval").value, 10);
  $("radioDeckStatus").innerHTML = chip("starting…", "warn");
  await fetchJson("/api/radio_deck", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ source, provider, tail: 240, interval, audio: true }),
  });
  await refreshRadio();
}

async function stopDeck() {
  $("radioDeckStatus").innerHTML = chip("stopping…", "warn");
  await fetchJson("/api/radio_deck", { method: "DELETE" });
  await refreshRadio();
}

document.addEventListener("DOMContentLoaded", () => {
  $("refreshBtn").onclick = () => refreshAll().catch(console.error);
  $("autoBtn").onclick = () => setAuto(!auto);
  $("logSel").onchange = () => refreshLog().catch(console.error);
  $("logLines").onchange = () => refreshLog().catch(console.error);
  $("makePacketBtn").onclick = () => makePacket().catch((error) => alert(`packet failed: ${error}`));
  $("makeRadioBtn").onclick = () => makeRadio().catch((error) => alert(`radio failed: ${error}`));
  $("startDeckBtn").onclick = () => startDeck().catch((error) => alert(`deck failed: ${error}`));
  $("stopDeckBtn").onclick = () => stopDeck().catch((error) => alert(`stop failed: ${error}`));

  $("radioPlayer").addEventListener("play", () => setVisualizer(true));
  $("radioPlayer").addEventListener("pause", () => setVisualizer(false));
  $("radioPlayer").addEventListener("ended", () => setVisualizer(false));

  setAuto(true);
  refreshAll().catch(console.error);
});
