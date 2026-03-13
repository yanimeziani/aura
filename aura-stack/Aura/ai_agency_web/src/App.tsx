import { useState } from 'react'
import './App.css'

function App() {
  const [email, setEmail] = useState('')
  const [company, setCompany] = useState('')
  const [status, setStatus] = useState<'idle' | 'loading' | 'success' | 'error'>('idle')
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setStatus('loading')
    setErrorMessage(null)

    try {
      // Check access first — redirect if granted.
      const accessRes = await fetch('/api/validate-access', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email }),
      })
      if (accessRes.ok) {
        const accessData = await accessRes.json()
        if (accessData.access) {
          window.location.href = accessData.redirect || '/dashboard'
          return
        }
      }

      // No access — capture as lead.
      const response = await fetch('/api/lead', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, company_name: company }),
      })

      if (response.ok) {
        setStatus('success')
      } else {
        setStatus('error')
        const contentType = response.headers.get('content-type') || ''
        try {
          if (contentType.includes('application/json')) {
            const body = await response.json()
            const detail = typeof body?.detail === 'string' ? body.detail : null
            setErrorMessage(detail ?? `Request failed with status ${response.status}.`)
          } else {
            const bodyText = (await response.text()).trim()
            setErrorMessage(bodyText || `Request failed with status ${response.status}.`)
          }
        } catch {
          setErrorMessage(`Request failed with status ${response.status}.`)
        }
      }
    } catch (err) {
      setStatus('error')
      setErrorMessage(err instanceof Error ? err.message : 'Connection failed.')
    }
  }

  return (
    <div className="container">
      <header>
        <h1>Meziani AI Labs</h1>
        <p className="subtitle">
          Sovereign Digitalisation. Automated Wealth. <br/>
          Scaling Canadian Enterprise with Autonomous Systems.
        </p>
      </header>

      <main>
        {status === 'success' ? (
          <div className="funnel-card">
            <h2>Intent Captured.</h2>
            <p style={{ color: '#888' }}>Aura is analysing your profile for Canadian market fit. Expect a goal-aligned response shortly.</p>
            <button onClick={() => setStatus('idle')}>Submit Another</button>
          </div>
        ) : (
          <div className="funnel-card">
            <h2 style={{ marginBottom: '2rem' }}>Scale Automatically</h2>
            <form onSubmit={handleSubmit}>
              <div className="input-group">
                <label>Company Name</label>
                <input 
                  type="text" 
                  placeholder="e.g. Shopify, DPD Group" 
                  value={company}
                  onChange={(e) => setCompany(e.target.value)}
                  required
                />
              </div>
              <div className="input-group">
                <label>Business Email</label>
                <input 
                  type="email" 
                  placeholder="yani@meziani.ai" 
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                />
              </div>
              <button type="submit" disabled={status === 'loading'}>
                {status === 'loading' ? 'Analysing...' : 'Initiate Aura Funnel'}
              </button>
              {status === 'error' && (
                <p style={{ color: '#ff4d4d', marginTop: '1rem' }}>
                  {errorMessage ?? 'Connection failed. Try again.'}
                </p>
              )}
            </form>
          </div>
        )}

        <div className="features">
          <div className="feature">
            <h3>Sovereign Stack</h3>
            <p>100% self-hosted infrastructure. Your data, your rules, your AI. Compliant with Canadian standards.</p>
          </div>
          <div className="feature">
            <h3>Canadian SMB Focus</h3>
            <p>Directing high-tier automation to the heart of Canadian and North African commerce.</p>
          </div>
          <div className="feature">
            <h3>Mind Protection</h3>
            <p>Autonomous systems that filter the noise and execute the goals. Focused deep work for Canadian founders.</p>
          </div>
        </div>
      </main>

      <footer>
        &copy; 2026 Meziani AI Labs. Powered by Aura.
      </footer>
    </div>
  )
}

export default App
