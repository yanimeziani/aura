import { useState, useEffect, useRef, useCallback } from 'react'
import '@fontsource/roboto/300.css'
import '@fontsource/roboto/400.css'
import '@fontsource/roboto/500.css'
import '@fontsource/roboto/700.css'
import '@fontsource-variable/fraunces/index.css'
import './App.css'

interface Offer {
  title: string;
  description: string;
  price_usd: number;
  features: string[];
}

interface Stats {
  saas_sales: number;
  agency_income: number;
  total_gross_cad: number;
  active_licenses: number;
  emergency_fund: number;
  ops_fund: number;
}

interface AgentStatus {
  id: string;
  name: string;
  vertical: string;
  status: 'running' | 'idle' | 'error' | 'cooldown';
  lastRun: string;
  cyclesCompleted: number;
}

const MOCK_AGENTS: AgentStatus[] = [
  { id: 'research', name: 'Research Dept', vertical: 'Intelligence', status: 'running', lastRun: '2m ago', cyclesCompleted: 247 },
  { id: 'trading', name: 'Trading Engine', vertical: 'Wealth', status: 'idle', lastRun: '12m ago', cyclesCompleted: 1842 },
  { id: 'crypto', name: 'Crypto Arbitrage', vertical: 'Wealth', status: 'running', lastRun: '0m ago', cyclesCompleted: 3901 },
  { id: 'outreach', name: 'Outreach Engine', vertical: 'Sales', status: 'cooldown', lastRun: '5m ago', cyclesCompleted: 89 },
  { id: 'newsletter', name: 'Newsletter Dept', vertical: 'Content', status: 'idle', lastRun: '1h ago', cyclesCompleted: 14 },
  { id: 'accounting', name: 'Accounting Agent', vertical: 'Finance', status: 'idle', lastRun: '30m ago', cyclesCompleted: 412 },
  { id: 'health', name: 'Health Monitor', vertical: 'Ops', status: 'running', lastRun: '0m ago', cyclesCompleted: 8820 },
];

type View = 'dashboard' | 'agents' | 'logs' | 'settings';

function App() {
  const [logs, setLogs] = useState<string>('System initializing...')
  const [isRunning, setIsRunning] = useState<boolean>(false)
  const [hasAccess, setHasAccess] = useState<boolean>(false)
  const [email, setEmail] = useState<string>(localStorage.getItem('user_email') || '')
  const [isCheckingAccess, setIsCheckingAccess] = useState<boolean>(false)
  const [stats, setStats] = useState<Stats>({
    saas_sales: 0, agency_income: 0, total_gross_cad: 0,
    active_licenses: 0, emergency_fund: 0, ops_fund: 0
  })
  const [offer, setOffer] = useState<Offer | null>(null)
  const [activeView, setActiveView] = useState<View>('dashboard')
  const [agents] = useState<AgentStatus[]>(MOCK_AGENTS)
  const logEndRef = useRef<HTMLDivElement>(null)

  const API_BASE = '/api';

  const fetchOffer = useCallback(async () => {
    try {
      const res = await fetch(`${API_BASE}/current-offer`)
      if (res.ok) { const data = await res.json(); setOffer(data) }
    } catch (e) { console.error('Failed to load offer', e) }
  }, [])

  const fetchLogs = useCallback(async () => {
    if (!hasAccess) return;
    try {
      const res = await fetch(`${API_BASE}/log`)
      if (res.ok) { const text = await res.text(); setLogs(text) }
    } catch (e) { console.error(e) }
  }, [hasAccess])

  const fetchStats = useCallback(async () => {
    try {
      const res = await fetch(`${API_BASE}/stats`)
      if (res.ok) { const data = await res.json(); setStats(data) }
    } catch (e) { console.error(e) }
  }, [])

  const checkAccess = async (targetEmail: string) => {
    if (!targetEmail) return;
    setIsCheckingAccess(true);
    try {
      const res = await fetch(`${API_BASE}/check-access/${targetEmail}`)
      const data = await res.json()
      if (data.access) { setHasAccess(true); localStorage.setItem('user_email', targetEmail) }
      else { setHasAccess(false) }
    } catch (e) { console.error('Access verification failed', e) }
    finally { setIsCheckingAccess(false) }
  }

  const handleUnlock = async () => {
    if (!email) { alert("Please enter email"); return; }
    try {
      const res = await fetch(`${API_BASE}/create-checkout-session`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ client_name: email })
      });
      const data = await res.json();
      if (data.checkout_url) window.location.href = data.checkout_url;
    } catch (e) { console.error('Checkout error:', e); }
  }

  useEffect(() => {
    fetchStats(); fetchOffer();
    const urlParams = new URLSearchParams(window.location.search);
    const urlEmail = urlParams.get('email');
    const storedEmail = localStorage.getItem('user_email');
    if (urlEmail) { setEmail(urlEmail); checkAccess(urlEmail); }
    else if (storedEmail) { checkAccess(storedEmail); }
  }, [fetchStats, fetchOffer]);

  useEffect(() => {
    if (hasAccess) {
      fetchLogs(); fetchStats();
      const interval = setInterval(() => { fetchLogs(); fetchStats(); }, 5000);
      return () => clearInterval(interval)
    }
  }, [hasAccess, fetchLogs, fetchStats])

  useEffect(() => {
    if (logEndRef.current) logEndRef.current.scrollIntoView({ behavior: 'smooth' })
  }, [logs])

  const runAgency = async () => {
    if (!hasAccess) return;
    setIsRunning(true)
    try {
      await fetch(`${API_BASE}/run?email=${email}`, { method: 'POST' })
      setTimeout(() => setIsRunning(false), 2000)
    } catch (e) { console.error(e); setIsRunning(false) }
  }

  if (!hasAccess) {
    /* Auth: Hick (2 choices only); Serial Position (primary first); Proximity (chunked regions) */
    return (
      <div className="m3-auth-container">
        <div className="m3-hero-card">
          <header style={{ marginBottom: '4px' }}>
            <h1 className="m3-display-large">AURA</h1>
            <p className="m3-body-large">Autonomous Command System</p>
          </header>

          {offer && (
            <section className="m3-card" style={{ textAlign: 'left', marginTop: 0 }}>
              <p className="m3-label-medium">Included</p>
              <ul style={{ margin: '8px 0 0', paddingLeft: '1.25rem', listStyle: 'none' }}>
                {offer.features.slice(0, 5).map((f, i) => (
                  <li key={i} className="m3-body-medium" style={{ marginBottom: '4px', position: 'relative', paddingLeft: '8px' }}>
                    <span style={{ position: 'absolute', left: '-1rem' }}>✓</span>
                    {f}
                  </li>
                ))}
              </ul>
            </section>
          )}

          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            <label className="m3-label-medium" style={{ textAlign: 'left' }} htmlFor="auth-email">Email</label>
            <input
              id="auth-email"
              type="email"
              className="m3-input"
              placeholder="you@example.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && handleUnlock()}
              autoComplete="email"
            />
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '8px' }}>
            <button
              className="m3-button m3-button-filled"
              onClick={handleUnlock}
              disabled={!email || isCheckingAccess}
              aria-busy={isCheckingAccess}
            >
              {offer ? `Deploy — $${(offer.price_usd / 100).toFixed(0)}` : 'Deploy'}
            </button>
            <button
              className="m3-button m3-button-tonal"
              onClick={() => checkAccess(email)}
              disabled={!email || isCheckingAccess}
              aria-busy={isCheckingAccess}
            >
              {isCheckingAccess ? 'Verifying…' : 'Already paid? Verify access'}
            </button>
          </div>
        </div>
      </div>
    );
  }

  const NAV_ITEMS = [
    { id: 'dashboard' as View, label: 'Dashboard', icon: 'home' },
    { id: 'agents'    as View, label: 'Agents',    icon: 'adb' },
    { id: 'logs'      as View, label: 'Logs',      icon: 'terminal' },
    { id: 'settings'  as View, label: 'Config',    icon: 'settings' },
  ];

  const runningAgents = agents.filter(a => a.status === 'running').length;

  return (
    <div className="m3-app">
      {/* Top App Bar (Mobile) */}
      <header className="m3-top-app-bar" style={{ display: window.innerWidth < 600 ? 'flex' : 'none' }}>
        <h1 className="m3-title-large brand-wordmark">AURA</h1>
        <div data-sign-out role="button" tabIndex={0} onClick={() => { localStorage.removeItem('user_email'); setHasAccess(false); }} onKeyDown={(e) => e.key === 'Enter' && (localStorage.removeItem('user_email'), setHasAccess(false))}>Sign out</div>
      </header>

      {/* Nav Rail (Tablet/Fold Outer Open) */}
      <nav className="m3-nav-rail" aria-label="Main">
        <div className="m3-title-large brand-wordmark" style={{ color: 'var(--accent)', fontSize: '1rem' }}>AURA</div>
        {NAV_ITEMS.map(v => (
          <button key={v.id} className={`m3-nav-item ${activeView === v.id ? 'active' : ''}`} onClick={() => setActiveView(v.id)}>
            <div className="m3-nav-icon-container">
               <span className="material-symbols-outlined" style={{fontFamily: 'sans-serif', fontStyle:'normal'}}>{v.icon === 'home' ? '⌂' : v.icon === 'adb' ? '🤖' : v.icon === 'terminal' ? '⌨' : '⚙'}</span>
            </div>
            <span className="m3-nav-label">{v.label}</span>
          </button>
        ))}
        <div style={{flex: 1}} />
        <button className="m3-nav-item" onClick={() => { localStorage.removeItem('user_email'); setHasAccess(false); }}>
           <span className="m3-nav-label">Logout</span>
        </button>
      </nav>

      <nav className="m3-bottom-nav" aria-label="Main">
        {NAV_ITEMS.map(v => (
          <button key={v.id} className={`m3-nav-item ${activeView === v.id ? 'active' : ''}`} onClick={() => setActiveView(v.id)}>
            <div className="m3-nav-icon-container">
               <span style={{fontSize:'18px'}}>{v.icon === 'home' ? '⌂' : v.icon === 'adb' ? '🤖' : v.icon === 'terminal' ? '⌨' : '⚙'}</span>
            </div>
            <span className="m3-nav-label">{v.label}</span>
          </button>
        ))}
      </nav>

      <main className="m3-main-content">
        {activeView === 'dashboard' && (
          <>
            <header>
              <h1 className="m3-headline-medium">Overview</h1>
              <p className="m3-body-large">System operational</p>
            </header>

            <section className="m3-kpi-grid" aria-label="Key metrics">
              <div className="m3-card m3-card-elevated">
                <span className="m3-label-medium">Total gross (CAD)</span>
                <span className="m3-display-large" style={{ color: 'var(--accent)' }}>${stats.total_gross_cad.toLocaleString()}</span>
              </div>
              <div className="m3-card">
                <span className="m3-label-medium">Emergency (60%)</span>
                <span className="m3-headline-medium">${stats.emergency_fund.toLocaleString()}</span>
              </div>
              <div className="m3-card">
                <span className="m3-label-medium">Ops (40%)</span>
                <span className="m3-headline-medium">${stats.ops_fund.toLocaleString()}</span>
              </div>
            </section>

            <section aria-label="Agent fleet">
              <h2 className="m3-title-large" style={{ marginBottom: '12px' }}>Agents · {runningAgents} active</h2>
              <div className="m3-list">
                {[...agents]
                  .sort((a, b) => (a.status === 'running' ? -1 : 0) - (b.status === 'running' ? -1 : 0))
                  .slice(0, 7)
                  .map(a => (
                    <div key={a.id} className="m3-list-item">
                      <div>
                        <div className="m3-list-item-title">{a.name}</div>
                        <div className="m3-list-item-sub">{a.vertical} · {a.cyclesCompleted} cycles</div>
                      </div>
                      <span className={`m3-status-chip ${a.status === 'running' ? 'running' : ''}`}>
                        {a.status === 'running' && <span className="m3-status-dot" aria-hidden />}
                        {a.status}
                      </span>
                    </div>
                  ))}
              </div>
            </section>

            <div style={{ position: 'fixed', bottom: '88px', right: '16px' }}>
              <button
                className="m3-fab-extended"
                onClick={runAgency}
                disabled={isRunning}
                aria-busy={isRunning}
              >
                {isRunning ? 'Running…' : 'Run orchestrator'}
              </button>
            </div>
          </>
        )}

        {activeView === 'agents' && (
          <>
            <header>
              <h1 className="m3-headline-medium">Agents</h1>
              <p className="m3-body-large">Autonomous operations</p>
            </header>
            <section className="m3-kpi-grid" style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))' }}>
              {agents.map(a => (
                <div key={a.id} className="m3-card">
                  <span className="m3-title-large">{a.name}</span>
                  <span className="m3-body-medium" style={{ color: 'var(--accent)' }}>{a.vertical}</span>
                  <div style={{ marginTop: '12px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span className="m3-label-medium">Last run {a.lastRun}</span>
                    <span className={`m3-status-chip ${a.status === 'running' ? 'running' : ''}`}>
                      {a.status === 'running' && <span className="m3-status-dot" aria-hidden />}
                      {a.status}
                    </span>
                  </div>
                </div>
              ))}
            </section>
          </>
        )}

        {activeView === 'logs' && (
          <>
            <header style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
              <h1 className="m3-headline-medium">Logs</h1>
              <span className="m3-status-chip running"><span className="m3-status-dot" aria-hidden /> Live</span>
            </header>
            <div className="m3-log-viewer" role="log" aria-live="polite">
              {logs}
              <div ref={logEndRef} />
            </div>
          </>
        )}

        {activeView === 'settings' && (
          <>
            <header>
              <h1 className="m3-headline-medium">Config</h1>
              <p className="m3-body-large">Infrastructure</p>
            </header>
            <section className="m3-card" style={{ marginBottom: '16px' }}>
              <h2 className="m3-title-large" style={{ marginBottom: '12px' }}>Payment</h2>
              <div className="m3-list">
                <div className="m3-list-item">
                  <span className="m3-list-item-title">Provider</span>
                  <span className="m3-list-item-sub">Stripe</span>
                </div>
                <div className="m3-list-item">
                  <span className="m3-list-item-title">Split</span>
                  <span className="m3-list-item-sub">60% reserve / 40% ops</span>
                </div>
              </div>
            </section>
            <section className="m3-card">
              <h2 className="m3-title-large" style={{ marginBottom: '12px' }}>Stack</h2>
              <div className="m3-list">
                <div className="m3-list-item">
                  <span className="m3-list-item-title">Frontend</span>
                  <span className="m3-list-item-sub">Vite, React</span>
                </div>
                <div className="m3-list-item">
                  <span className="m3-list-item-title">Backend</span>
                  <span className="m3-list-item-sub">FastAPI, CrewAI</span>
                </div>
              </div>
            </section>
          </>
        )}
      </main>
    </div>
  )
}

export default App