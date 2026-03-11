import { useState } from 'react'
import './App.css'

type Segment = 'ca' | 'mena'
type Status = 'idle' | 'loading' | 'success' | 'error'

const CA_INDUSTRIES = [
  'Logistics & Distribution',
  'Manufacturing',
  'Legal Services',
  'Medical & Healthcare',
  'Financial Services',
  'Retail & E-Commerce',
  'Construction & Trades',
  'Technology',
  'Other',
]

const MENA_INDUSTRIES = [
  'Commerce de détail / Retail',
  'Logistique & Transport',
  'Import / Export',
  'Services professionnels',
  'Restauration & Hôtellerie',
  'Fabrication industrielle',
  'Distribution médicale',
  'Technologie',
  'Autre',
]

const COPY = {
  ca: {
    hero: 'Autonomous Infrastructure for Canadian Enterprise.',
    sub: 'We deploy sovereign, self-hosted AI systems that execute your operations — invoicing, lead generation, compliance — without cloud lock-in or data exposure.',
    cardTitle: 'Phase 1: Infrastructure Assessment',
    cardSub: 'Free evaluation. No commitment. Delivered within 48 hours.',
    industryLabel: 'Industry',
    cta: 'Request Assessment',
    loading: 'Submitting...',
    success: {
      title: 'Assessment Request Received.',
      body: 'Aura is profiling your infrastructure fit. Expect a goal-aligned response within 48 hours.',
    },
    features: [
      {
        title: 'Canadian Data Sovereignty',
        body: '100% self-hosted on Canadian soil. No AWS, no OpenAI, no third-party exposure. Your data stays yours.',
      },
      {
        title: 'Systematic Execution',
        body: 'Multi-agent systems handle outreach, invoicing, reporting, and compliance. Your team focuses on decisions, not repetition.',
      },
      {
        title: 'Operational Continuity',
        body: '24/7 autonomous operation with real-time monitoring. Built on Zig, Python, and open-source — no vendor risk.',
      },
    ],
  },
  mena: {
    hero: 'Automatisez votre PME. Gérez moins. Grandissez plus.',
    sub: 'Nous déployons des systèmes open-source (n8n, Odoo, Dolibarr) pour automatiser la facturation, la gestion des stocks et le CRM — sans abonnement cloud coûteux.',
    cardTitle: 'Le Pack Automation Algérie',
    cardSub: 'Audit gratuit. Résultats en 48h. En français et en arabe.',
    industryLabel: 'Secteur d\'activité',
    cta: 'Démarrer l\'automatisation',
    loading: 'Envoi en cours...',
    success: {
      title: 'Demande enregistrée.',
      body: 'Notre équipe analyse votre profil pour un plan d\'automatisation adapté à votre secteur. Réponse sous 48h.',
    },
    features: [
      {
        title: 'Facturation Automatisée',
        body: 'Générez, envoyez et suivez vos factures automatiquement. Intégration avec les flux bancaires algériens et MENA.',
      },
      {
        title: 'Gestion des Stocks & CRM',
        body: 'Odoo et Dolibarr configurés pour votre métier. Inventaire en temps réel, suivi client, et alertes automatiques.',
      },
      {
        title: 'Open-Source, Sans Abonnement',
        body: 'Déploiement local ou VPS. Zéro dépendance aux clouds étrangers. Vos données restent dans votre infrastructure.',
      },
    ],
  },
}

function App() {
  const [segment, setSegment] = useState<Segment>('ca')
  const [email, setEmail] = useState('')
  const [company, setCompany] = useState('')
  const [industry, setIndustry] = useState('')
  const [status, setStatus] = useState<Status>('idle')
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  const copy = COPY[segment]
  const industries = segment === 'ca' ? CA_INDUSTRIES : MENA_INDUSTRIES

  const switchSegment = (s: Segment) => {
    setSegment(s)
    setIndustry('')
    setStatus('idle')
    setErrorMessage(null)
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setStatus('loading')
    setErrorMessage(null)

    try {
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

      const response = await fetch('/api/lead', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email,
          company_name: company,
          industry,
          segment,
        }),
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
            setErrorMessage(detail ?? `Error ${response.status}.`)
          } else {
            const bodyText = (await response.text()).trim()
            setErrorMessage(bodyText || `Error ${response.status}.`)
          }
        } catch {
          setErrorMessage(`Error ${response.status}.`)
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
        <div className="wordmark">Meziani AI Labs</div>
        <h1>{copy.hero}</h1>
        <p className="subtitle">{copy.sub}</p>

        <div className="segment-toggle">
          <button
            type="button"
            className={`seg-btn ${segment === 'ca' ? 'active' : ''}`}
            onClick={() => switchSegment('ca')}
          >
            Canada
          </button>
          <button
            type="button"
            className={`seg-btn ${segment === 'mena' ? 'active' : ''}`}
            onClick={() => switchSegment('mena')}
          >
            Algérie / MENA
          </button>
        </div>
      </header>

      <main>
        {status === 'success' ? (
          <div className="funnel-card">
            <div className="success-icon">&#10003;</div>
            <h2>{copy.success.title}</h2>
            <p className="muted">{copy.success.body}</p>
            <button className="btn-secondary" onClick={() => { setStatus('idle'); setEmail(''); setCompany(''); setIndustry('') }}>
              Submit Another
            </button>
          </div>
        ) : (
          <div className="funnel-card">
            <h2>{copy.cardTitle}</h2>
            <p className="card-sub">{copy.cardSub}</p>
            <form onSubmit={handleSubmit}>
              <div className="input-group">
                <label>Company Name</label>
                <input
                  type="text"
                  placeholder={segment === 'ca' ? 'e.g. Apex Logistics, RocLaw' : 'ex. DPD Algérie, MedDistrib'}
                  value={company}
                  onChange={(e) => setCompany(e.target.value)}
                  required
                />
              </div>
              <div className="input-group">
                <label>Business Email</label>
                <input
                  type="email"
                  placeholder={segment === 'ca' ? 'you@company.ca' : 'vous@entreprise.dz'}
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                />
              </div>
              <div className="input-group">
                <label>{copy.industryLabel}</label>
                <select
                  value={industry}
                  onChange={(e) => setIndustry(e.target.value)}
                  required
                >
                  <option value="" disabled>{segment === 'ca' ? 'Select industry' : 'Choisir un secteur'}</option>
                  {industries.map((ind) => (
                    <option key={ind} value={ind}>{ind}</option>
                  ))}
                </select>
              </div>
              <button type="submit" className="btn-primary" disabled={status === 'loading'}>
                {status === 'loading' ? copy.loading : copy.cta}
              </button>
              {status === 'error' && (
                <p className="error-msg">{errorMessage ?? 'Connection failed. Try again.'}</p>
              )}
            </form>
          </div>
        )}

        <div className="features">
          {copy.features.map((f) => (
            <div className="feature" key={f.title}>
              <h3>{f.title}</h3>
              <p>{f.body}</p>
            </div>
          ))}
        </div>
      </main>

      <footer>
        <p>&copy; 2026 Meziani AI Labs &mdash; Powered by Aura</p>
        <p className="footer-note">
          {segment === 'ca'
            ? 'CASL compliant. Canadian data sovereignty. No cloud lock-in.'
            : 'Open-source. Souveraineté des données. Aucun abonnement cloud.'}
        </p>
      </footer>
    </div>
  )
}

export default App
