'use client'

import Link from 'next/link'
import { useState } from 'react'

import styles from './page.module.css'

type Segment = 'ca' | 'mena'
type Status = 'idle' | 'loading' | 'success' | 'error'

// For self-hosted deploys, set NEXT_PUBLIC_ACCESS_ENDPOINT, NEXT_PUBLIC_LEAD_ENDPOINT, NEXT_PUBLIC_WEBHOOK_ENDPOINT
const ACCESS_ENDPOINT =
  process.env.NEXT_PUBLIC_ACCESS_ENDPOINT ?? 'https://meziani.org/api/validate-access'
const LEAD_ENDPOINT =
  process.env.NEXT_PUBLIC_LEAD_ENDPOINT ?? 'https://meziani.org/api/lead'
const WEBHOOK_ENDPOINT =
  process.env.NEXT_PUBLIC_WEBHOOK_ENDPOINT ?? 'https://meziani.org/ops/webhook/landing'

const CA_INDUSTRIES = [
  'Logistics & Distribution',
  'Manufacturing',
  'Legal Services',
  'Medical & Healthcare',
  'Financial Services',
  'Retail & Commerce',
  'Construction & Trades',
  'Technology',
  'Other',
]

const MENA_INDUSTRIES = [
  'Commerce de detail / Retail',
  'Logistique & Transport',
  'Import / Export',
  'Services professionnels',
  'Restauration & Hotellerie',
  'Fabrication industrielle',
  'Distribution medicale',
  'Technologie',
  'Autre',
]

const COPY = {
  ca: {
    navLabel: 'Canada',
    heroEyebrow: 'Meziani AI Labs',
    heroTitle: 'Sovereign automation for companies that need real operations, not demos.',
    heroLead:
      'We design and deploy operator-controlled AI systems for invoicing, intake, collections, outreach, and reporting. Fast frontends on Vercel. Sensitive logic and data flows kept under your control.',
    primaryCta: 'Request Infrastructure Brief',
    secondaryCta: 'See Operating Model',
    trust: ['Operator controlled', 'Audit friendly', 'No cloud lock-in'],
    intakeTitle: 'Phase 1: Infrastructure Brief',
    intakeBody:
      'Tell us what you run today. We return a deployment map, risk notes, and the first automation lane worth shipping.',
    companyLabel: 'Company Name',
    companyPlaceholder: 'Apex Logistics, RocLaw, Northbridge Health',
    emailLabel: 'Business Email',
    emailPlaceholder: 'you@company.ca',
    industryLabel: 'Industry',
    industryPlaceholder: 'Select industry',
    loading: 'Submitting...',
    successTitle: 'Brief request received.',
    successBody:
      'Your company profile is in the queue. Meziani AI will return a fit assessment and deployment direction within 48 hours.',
    proofTitle: 'Built for high-consequence workflows',
    proofBody:
      'Collections, compliance, handoff queues, and document-heavy operations need structure, auditability, and human override paths. Aura is built around those constraints.',
    systemTitle: 'What we deploy',
    systemCards: [
      {
        title: 'Revenue Infrastructure',
        body: 'Lead capture, qualification, follow-up, quoting, payment links, and collections handoff in one operating surface.',
      },
      {
        title: 'Backoffice Automation',
        body: 'Document routing, intake classification, customer operations, status updates, and repeatable internal workflows.',
      },
      {
        title: 'Governed AI Layers',
        body: 'Human override, audit logs, constrained automation, and system boundaries designed before production launch.',
      },
    ],
    deliveryTitle: 'Deployment arc',
    deliverySteps: [
      {
        step: '01',
        title: 'Assess',
        body: 'Map current tools, hidden manual work, and where risk appears when automation touches customers or money.',
      },
      {
        step: '02',
        title: 'Architect',
        body: 'Define control plane, data boundaries, review gates, and Vercel-facing product surfaces.',
      },
      {
        step: '03',
        title: 'Ship',
        body: 'Launch the first working lane fast: landing page, intake flow, workflow engine, or operator dashboard.',
      },
      {
        step: '04',
        title: 'Stabilize',
        body: 'Add monitoring, escalation paths, incident handling, and the next automations without losing control.',
      },
    ],
    railsTitle: 'Safety rails from day one',
    rails: [
      'Consent-first automation and verified user paths',
      'Manual override for high-risk steps and customer-facing actions',
      'Separation between frontend speed and sensitive backend logic',
      'Security and ethics review for systems that touch money or legal exposure',
    ],
    footerNote:
      'Canadian-focused deployments with sovereign operating discipline and no dependency on generic SaaS lock-in.',
  },
  mena: {
    navLabel: 'Algerie / MENA',
    heroEyebrow: 'Meziani AI Labs',
    heroTitle: 'Automatisez l entreprise. Gardez le controle. Accelerez sans exposer vos donnees.',
    heroLead:
      'Nous construisons des systemes d automation souverains pour la facturation, le CRM, le suivi client, les operations et les flux metier. Interface rapide sur Vercel. Logique sensible et donnees sous controle.',
    primaryCta: 'Demarrer le Brief',
    secondaryCta: 'Voir le modele',
    trust: ['Controle operateur', 'Piste d audit', 'Sans lock-in cloud'],
    intakeTitle: 'Phase 1: Brief d infrastructure',
    intakeBody:
      'Expliquez votre activite actuelle. Nous renvoyons une carte de deploiement, les risques critiques, et la premiere boucle d automation a lancer.',
    companyLabel: 'Nom de l entreprise',
    companyPlaceholder: 'DPD Algerie, MedDistrib, Tiba',
    emailLabel: 'Email professionnel',
    emailPlaceholder: 'vous@entreprise.dz',
    industryLabel: 'Secteur',
    industryPlaceholder: 'Choisir un secteur',
    loading: 'Envoi en cours...',
    successTitle: 'Demande recue.',
    successBody:
      'Votre brief est en file. Meziani AI preparera une recommandation de deploiement et une trajectoire de lancement sous 48 heures.',
    proofTitle: 'Concu pour les operations serieuses',
    proofBody:
      'Facturation, relance, routage documentaire, suivi commercial et operations critiques demandent des systemes clairs, controles, et auditables. C est le cadre Aura.',
    systemTitle: 'Ce que nous deployons',
    systemCards: [
      {
        title: 'Infrastructure commerciale',
        body: 'Capture de leads, qualification, relance, devis, paiement, et suivi operateur dans une meme surface.',
      },
      {
        title: 'Automation backoffice',
        body: 'Classement des demandes, routage documentaire, CRM, suivi client et reduction du travail repetitif.',
      },
      {
        title: 'Couches IA gouvernees',
        body: 'Override humain, journaux d audit, automatisation contrainte, et frontieres systeme posees avant la prod.',
      },
    ],
    deliveryTitle: 'Arc de deploiement',
    deliverySteps: [
      {
        step: '01',
        title: 'Audit',
        body: 'Identifier les goulets, les taches manuelles, et les zones ou l automation peut creer du risque.',
      },
      {
        step: '02',
        title: 'Architecture',
        body: 'Definir le control plane, les limites de donnees, les validations, et la surface produit Vercel.',
      },
      {
        step: '03',
        title: 'Mise en ligne',
        body: 'Lancer vite une premiere boucle utile: landing page, intake, workflow, ou dashboard operateur.',
      },
      {
        step: '04',
        title: 'Stabilisation',
        body: 'Ajouter la supervision, les escalades, la gestion d incident, puis etendre les automatisations.',
      },
    ],
    railsTitle: 'Garde-fous integres',
    rails: [
      'Usage legitime et flux consentis',
      'Override humain pour les actions sensibles',
      'Separation entre frontend rapide et logique metier critique',
      'Validation securite et ethique pour les systemes a risque',
    ],
    footerNote:
      'Deploiements souverains pour Algerie et MENA, avec discipline produit, controle local, et adoption responsable.',
  },
} as const

export default function LandingPage() {
  const [segment, setSegment] = useState<Segment>('ca')
  const [email, setEmail] = useState('')
  const [company, setCompany] = useState('')
  const [industry, setIndustry] = useState('')
  const [status, setStatus] = useState<Status>('idle')
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  const copy = COPY[segment]
  const industries = segment === 'ca' ? CA_INDUSTRIES : MENA_INDUSTRIES

  const switchSegment = (nextSegment: Segment) => {
    setSegment(nextSegment)
    setIndustry('')
    setStatus('idle')
    setErrorMessage(null)
  }

  const resetForm = () => {
    setEmail('')
    setCompany('')
    setIndustry('')
    setStatus('idle')
    setErrorMessage(null)
  }

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    setStatus('loading')
    setErrorMessage(null)

    try {
      const accessRes = await fetch(ACCESS_ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email }),
      })

      if (accessRes.ok) {
        const accessData = (await accessRes.json()) as { access?: boolean }
        if (accessData.access) {
          setStatus('success')
          return
        }
      }

      const response = await fetch(LEAD_ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email,
          company_name: company,
          industry,
          segment,
        }),
      })

      try {
        await fetch(WEBHOOK_ENDPOINT, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          mode: 'no-cors',
          body: JSON.stringify({
            event: 'landing_form_submission',
            email,
            company,
            industry,
            segment,
            timestamp: new Date().toISOString(),
          }),
        })
      } catch (webhookError) {
        console.warn('Landing webhook deferred:', webhookError)
      }

      if (response.ok) {
        setStatus('success')
        return
      }

      setStatus('error')
      const contentType = response.headers.get('content-type') ?? ''
      if (contentType.includes('application/json')) {
        const body = (await response.json()) as { detail?: string }
        setErrorMessage(body.detail ?? `Error ${response.status}.`)
        return
      }

      const bodyText = (await response.text()).trim()
      setErrorMessage(bodyText || `Error ${response.status}.`)
    } catch (error) {
      setStatus('error')
      setErrorMessage(error instanceof Error ? error.message : 'Connection failed.')
    }
  }

  return (
    <main className={styles.pageShell}>
      <div className={styles.backgroundMesh} aria-hidden="true" />

      <header className={styles.topbar}>
        <div className={styles.wordmarkBlock}>
          <span className={styles.wordmark}>{copy.heroEyebrow}</span>
          <span className={styles.wordsub}>meziani.ai</span>
        </div>

        <nav className={styles.nav}>
          <a href="#system">System</a>
          <a href="#rails">Safety</a>
          <a href="#brief">Brief</a>
        </nav>

        <div className={styles.segmentToggle} aria-label="Market segment toggle">
          <button
            type="button"
            className={`${styles.toggleButton} ${segment === 'ca' ? styles.toggleActive : ''}`}
            onClick={() => switchSegment('ca')}
          >
            Canada
          </button>
          <button
            type="button"
            className={`${styles.toggleButton} ${segment === 'mena' ? styles.toggleActive : ''}`}
            onClick={() => switchSegment('mena')}
          >
            Algerie / MENA
          </button>
        </div>
      </header>

      <section className={styles.heroSection}>
        <div className={styles.heroCopy}>
          <div className={styles.eyebrowRow}>
            <span className={styles.eyebrowChip}>{copy.navLabel}</span>
            <span className={styles.eyebrowChip}>Aura-powered</span>
            <span className={styles.eyebrowChip}>Vercel-ready</span>
          </div>

          <h1 className={styles.heroTitle}>{copy.heroTitle}</h1>
          <p className={styles.heroLead}>{copy.heroLead}</p>

          <div className={styles.heroActions}>
            <a className={styles.primaryButton} href="#brief">
              {copy.primaryCta}
            </a>
            <a className={styles.secondaryButton} href="#model">
              {copy.secondaryCta}
            </a>
          </div>

          <div className={styles.trustRow}>
            {copy.trust.map((item) => (
              <span key={item} className={styles.trustPill}>
                {item}
              </span>
            ))}
          </div>

          <article className={styles.proofPanel}>
            <div className={styles.panelLabel}>Operating Premise</div>
            <h2>{copy.proofTitle}</h2>
            <p>{copy.proofBody}</p>
            <div className={styles.metricGrid}>
              <div className={styles.metricCard}>
                <span className={styles.metricValue}>1</span>
                <span className={styles.metricLabel}>control plane for operators</span>
              </div>
              <div className={styles.metricCard}>
                <span className={styles.metricValue}>48h</span>
                <span className={styles.metricLabel}>assessment turnaround</span>
              </div>
              <div className={styles.metricCard}>
                <span className={styles.metricValue}>0</span>
                <span className={styles.metricLabel}>interest in generic lock-in</span>
              </div>
            </div>
          </article>
        </div>

        <aside className={styles.intakeRail} id="brief">
          {status === 'success' ? (
            <div className={styles.formCard}>
              <div className={styles.successBadge}>Ready</div>
              <h2>{copy.successTitle}</h2>
              <p className={styles.cardLead}>{copy.successBody}</p>
              <button type="button" className={styles.primaryButton} onClick={resetForm}>
                Submit Another
              </button>
            </div>
          ) : (
            <div className={styles.formCard}>
              <div className={styles.panelLabel}>Deployment Intake</div>
              <h2>{copy.intakeTitle}</h2>
              <p className={styles.cardLead}>{copy.intakeBody}</p>

              <form className={styles.formStack} onSubmit={handleSubmit}>
                <label className={styles.field}>
                  <span>{copy.companyLabel}</span>
                  <input
                    type="text"
                    placeholder={copy.companyPlaceholder}
                    value={company}
                    onChange={(event) => setCompany(event.target.value)}
                    required
                  />
                </label>

                <label className={styles.field}>
                  <span>{copy.emailLabel}</span>
                  <input
                    type="email"
                    placeholder={copy.emailPlaceholder}
                    value={email}
                    onChange={(event) => setEmail(event.target.value)}
                    required
                  />
                </label>

                <label className={styles.field}>
                  <span>{copy.industryLabel}</span>
                  <select
                    value={industry}
                    onChange={(event) => setIndustry(event.target.value)}
                    required
                  >
                    <option value="" disabled>
                      {copy.industryPlaceholder}
                    </option>
                    {industries.map((item) => (
                      <option key={item} value={item}>
                        {item}
                      </option>
                    ))}
                  </select>
                </label>

                <button type="submit" className={styles.submitButton} disabled={status === 'loading'}>
                  {status === 'loading' ? copy.loading : copy.primaryCta}
                </button>

                {status === 'error' ? (
                  <p className={styles.errorText}>{errorMessage ?? 'Connection failed. Try again.'}</p>
                ) : null}
              </form>

              <p className={styles.formFootnote}>
                Endpoints can be overridden at build time with `NEXT_PUBLIC_ACCESS_ENDPOINT`,
                `NEXT_PUBLIC_LEAD_ENDPOINT`, and `NEXT_PUBLIC_WEBHOOK_ENDPOINT`.
              </p>
            </div>
          )}
        </aside>
      </section>

      <section className={styles.bandSection} id="system">
        <div className={styles.sectionHeading}>
          <span className={styles.sectionTag}>System</span>
          <h2>{copy.systemTitle}</h2>
        </div>

        <div className={styles.cardGrid}>
          {copy.systemCards.map((card) => (
            <article key={card.title} className={styles.infoCard}>
              <h3>{card.title}</h3>
              <p>{card.body}</p>
            </article>
          ))}
        </div>
      </section>

      <section className={styles.splitSection} id="model">
        <div className={styles.sectionHeading}>
          <span className={styles.sectionTag}>Delivery</span>
          <h2>{copy.deliveryTitle}</h2>
        </div>

        <div className={styles.timeline}>
          {copy.deliverySteps.map((item) => (
            <article key={item.step} className={styles.stepCard}>
              <div className={styles.stepNumber}>{item.step}</div>
              <div>
                <h3>{item.title}</h3>
                <p>{item.body}</p>
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className={styles.bandSection} id="rails">
        <div className={styles.sectionHeading}>
          <span className={styles.sectionTag}>Safety</span>
          <h2>{copy.railsTitle}</h2>
        </div>

        <div className={styles.railsGrid}>
          {copy.rails.map((item, index) => (
            <article key={item} className={styles.railCard}>
              <span className={styles.railIndex}>0{index + 1}</span>
              <p>{item}</p>
            </article>
          ))}
        </div>
      </section>

      <section className={styles.finalSection}>
        <div className={styles.finalCard}>
          <div>
            <span className={styles.sectionTag}>Launch Surface</span>
            <h2>Ship the first serious page, then the system behind it.</h2>
            <p>
              This landing page is built for Vercel deployment, but the product story is bigger:
              fast acquisition, clear trust framing, and a route into governed automation.
            </p>
          </div>

          <div className={styles.finalActions}>
            <a className={styles.primaryButton} href="#brief">
              Open the brief
            </a>
            <Link className={styles.secondaryButton} href="/brand/index.html">
              Brand assets
            </Link>
          </div>
        </div>
      </section>

      <footer className={styles.footer}>
        <span>Meziani AI Labs</span>
        <span>{copy.footerNote}</span>
      </footer>
    </main>
  )
}
