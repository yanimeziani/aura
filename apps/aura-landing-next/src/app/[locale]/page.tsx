"use client";

import Link from "next/link";
import { useState, useEffect } from "react";
import { useTranslations, useLocale } from "next-intl";

import styles from "../page.module.css";

type Segment = "ca" | "mena";
type Status = "idle" | "loading" | "success" | "error";

function runtimeEndpoint(path: string, fallbackEnv?: string): string {
  if (typeof window === "undefined") {
    return (fallbackEnv || "").replace(/\/$/, "");
  }
  const configured = (fallbackEnv || "").replace(/\/$/, "");
  if (configured) {
    return configured;
  }
  return `${window.location.origin.replace(/\/$/, "")}${path}`;
}

const CA_INDUSTRIES = [
  "Logistics & Distribution",
  "Manufacturing",
  "Legal Services",
  "Medical & Healthcare",
  "Financial Services",
  "Retail & Commerce",
  "Construction & Trades",
  "Technology",
  "Other",
];

const MENA_INDUSTRIES = [
  "Commerce de detail / Retail",
  "Logistique & Transport",
  "Import / Export",
  "Services professionnels",
  "Restauration & Hotellerie",
  "Fabrication industrielle",
  "Distribution medicale",
  "Technologie",
  "Autre",
];

const LOCALE_LABELS: Record<string, string> = {
  "en-CA": "EN (CA)",
  "en-US": "EN (US)",
  "en-AU": "EN (AU)",
  "fr-CA": "FR (CA)",
  "ar-DZ": "AR (DZ)",
};

export default function LandingPage() {
  const t = useTranslations();
  const locale = useLocale();
  const [email, setEmail] = useState("");
  const [company, setCompany] = useState("");
  const [industry, setIndustry] = useState("");
  const [status, setStatus] = useState<Status>("idle");
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const segment: Segment = locale === "ar-DZ" ? "mena" : "ca";
  const industries = segment === "ca" ? CA_INDUSTRIES : MENA_INDUSTRIES;

  // Telemetry: ping gateway on visit (locale + country inferred server-side or from locale)
  useEffect(() => {
    const gatewayUrl = runtimeEndpoint("/gw", process.env.NEXT_PUBLIC_GATEWAY_URL);
    if (!gatewayUrl) return;
    fetch(`${gatewayUrl}/telemetry/visit`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ locale }),
      mode: "cors",
    }).catch(() => {});
  }, [locale]);

  const resetForm = () => {
    setEmail("");
    setCompany("");
    setIndustry("");
    setStatus("idle");
    setErrorMessage(null);
  };

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setStatus("loading");
    setErrorMessage(null);

    const gatewayUrl = runtimeEndpoint("/gw", process.env.NEXT_PUBLIC_GATEWAY_URL);
    const accessEndpoint = runtimeEndpoint(
      "/api/validate-access",
      process.env.NEXT_PUBLIC_ACCESS_ENDPOINT || `${gatewayUrl}/api/validate-access`
    );
    const leadEndpoint = runtimeEndpoint(
      "/api/lead",
      process.env.NEXT_PUBLIC_LEAD_ENDPOINT || `${gatewayUrl}/api/lead`
    );
    const webhookEndpoint = runtimeEndpoint(
      "/ops/webhook/landing",
      process.env.NEXT_PUBLIC_WEBHOOK_ENDPOINT
    );

    try {
      const accessRes = await fetch(accessEndpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email }),
      });

      if (accessRes.ok) {
        const accessData = (await accessRes.json()) as { access?: boolean };
        if (accessData.access) {
          setStatus("success");
          return;
        }
      }

      const response = await fetch(leadEndpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          email,
          company_name: company,
          industry,
          segment,
        }),
      });

      try {
        await fetch(webhookEndpoint, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          mode: "no-cors",
          body: JSON.stringify({
            event: "landing_form_submission",
            email,
            company,
            industry,
            segment,
            locale,
            timestamp: new Date().toISOString(),
          }),
        });
      } catch {
        // ignore
      }

      if (response.ok) {
        setStatus("success");
        return;
      }

      setStatus("error");
      const contentType = response.headers.get("content-type") ?? "";
      if (contentType.includes("application/json")) {
        const body = (await response.json()) as { detail?: string };
        setErrorMessage(body.detail ?? `Error ${response.status}.`);
        return;
      }
      const bodyText = (await response.text()).trim();
      setErrorMessage(bodyText || `Error ${response.status}.`);
    } catch (error) {
      setStatus("error");
      setErrorMessage(error instanceof Error ? error.message : "Connection failed.");
    }
  };

  const trust = t.raw("trust") as string[];
  const systemCards = t.raw("systemCards") as Array<{ title: string; body: string }>;
  const deliverySteps = t.raw("deliverySteps") as Array<{ step: string; title: string; body: string }>;
  const rails = t.raw("rails") as string[];
  const journeySteps = t.raw("journeySteps") as string[];
  const phaseTitles = [t("phaseOneTitle"), t("phaseTwoTitle"), t("phaseThreeTitle")];
  const phaseBodies = [t("phaseOneBody"), t("phaseTwoBody"), t("phaseThreeBody")];

  return (
    <main className={styles.pageShell} dir={locale.startsWith("ar") ? "rtl" : "ltr"}>
      <div className={styles.backgroundMesh} aria-hidden="true" />

      <header className={styles.topbar}>
        <div className={styles.wordmarkBlock}>
          <span className={styles.wordmark}>{t("heroEyebrow")}</span>
          <span className={styles.wordsub}>nexa.global</span>
        </div>

        <nav className={styles.nav}>
          <a href="#phases">{t("secondaryCta")}</a>
          <a href="#journey">{t("journeyHeadline")}</a>
          <a href="#brief">{t("primaryCta")}</a>
        </nav>

        <div className={styles.segmentToggle} aria-label="Language / region">
          {(["en-CA", "en-US", "en-AU", "fr-CA", "ar-DZ"] as const).map((loc) => (
            <Link
              key={loc}
              href={`/${loc}`}
              className={`${styles.toggleButton} ${locale === loc ? styles.toggleActive : ""}`}
            >
              {LOCALE_LABELS[loc] ?? loc}
            </Link>
          ))}
        </div>
      </header>

      <section className={styles.heroSection}>
        <div className={styles.heroCopy}>
          <div className={styles.eyebrowRow}>
            <span className={styles.eyebrowChip}>{t("funnelTag")}</span>
            <span className={styles.eyebrowChip}>{t("navLabel")}</span>
            <span className={styles.eyebrowChip}>Safe ops</span>
          </div>

          <h1 className={styles.heroTitle}>{t("heroTitle")}</h1>
          <p className={styles.heroLead}>{t("heroLead")}</p>
          <p className={styles.funnelSubline}>{t("funnelSubline")}</p>

          <div className={styles.heroActions}>
            <a className={styles.primaryButton} href="#brief">
              {t("primaryCta")}
            </a>
            <a className={styles.secondaryButton} href="#phases">
              {t("secondaryCta")}
            </a>
          </div>

          <div className={styles.trustRow}>
            {trust.map((item) => (
              <span key={item} className={styles.trustPill}>
                {item}
              </span>
            ))}
          </div>

          <article className={styles.proofPanel}>
            <div className={styles.panelLabel}>Mental ops</div>
            <h2>{t("problemHeadline")}</h2>
            <p>{t("problemBody")}</p>
            <div className={styles.metricGrid}>
              <div className={styles.metricCard}>
                <span className={styles.metricValue}>1</span>
                <span className={styles.metricLabel}>{t("metricControl")}</span>
              </div>
              <div className={styles.metricCard}>
                <span className={styles.metricValue}>48h</span>
                <span className={styles.metricLabel}>{t("metricTurnaround")}</span>
              </div>
              <div className={styles.metricCard}>
                <span className={styles.metricValue}>0</span>
                <span className={styles.metricLabel}>{t("metricLockin")}</span>
              </div>
            </div>
          </article>
        </div>

        <aside className={styles.intakeRail} id="brief">
          {status === "success" ? (
            <div className={styles.formCard}>
              <div className={styles.successBadge}>{t("ready")}</div>
              <h2>{t("successTitle")}</h2>
              <p className={styles.cardLead}>{t("successBody")}</p>
              <button type="button" className={styles.primaryButton} onClick={resetForm}>
                {t("submitAnother")}
              </button>
            </div>
          ) : (
            <div className={styles.formCard}>
              <div className={styles.panelLabel}>{t("funnelTag")}</div>
              <h2>{t("auditCtaHeadline")}</h2>
              <p className={styles.cardLead}>{t("auditCtaBody")}</p>

              <form className={styles.formStack} onSubmit={handleSubmit}>
                <label className={styles.field}>
                  <span>{t("companyLabel")}</span>
                  <input
                    type="text"
                    placeholder={t("companyPlaceholder")}
                    value={company}
                    onChange={(e) => setCompany(e.target.value)}
                    required
                  />
                </label>
                <label className={styles.field}>
                  <span>{t("emailLabel")}</span>
                  <input
                    type="email"
                    placeholder={t("emailPlaceholder")}
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    required
                  />
                </label>
                <label className={styles.field}>
                  <span>{t("industryLabel")}</span>
                  <select
                    value={industry}
                    onChange={(e) => setIndustry(e.target.value)}
                    required
                  >
                    <option value="" disabled>
                      {t("industryPlaceholder")}
                    </option>
                    {industries.map((item) => (
                      <option key={item} value={item}>
                        {item}
                      </option>
                    ))}
                  </select>
                </label>
                <button type="submit" className={styles.submitButton} disabled={status === "loading"}>
                  {status === "loading" ? t("loading") : t("primaryCta")}
                </button>
                {status === "error" ? (
                  <p className={styles.errorText}>{errorMessage ?? "Connection failed. Try again."}</p>
                ) : null}
              </form>
              <p className={styles.formFootnote}>{t("formFootnote")}</p>
            </div>
          )}
        </aside>
      </section>

      <section className={styles.bandSection} id="phases">
        <div className={styles.sectionHeading}>
          <span className={styles.sectionTag}>{t("funnelTag")}</span>
          <h2>{t("phasesHeadline")}</h2>
        </div>
        <div className={styles.phasesGrid}>
          {[1, 2, 3].map((i) => (
            <article key={i} className={styles.phaseCard}>
              <div className={styles.stepNumber}>0{i}</div>
              <h3>{phaseTitles[i - 1]}</h3>
              <p>{phaseBodies[i - 1]}</p>
            </article>
          ))}
        </div>
      </section>

      <section className={styles.splitSection} id="journey">
        <div className={styles.sectionHeading}>
          <span className={styles.sectionTag}>{t("journeySectionTag")}</span>
          <h2>{t("journeyHeadline")}</h2>
        </div>
        <div className={styles.journeyList}>
          {journeySteps.map((step, idx) => (
            <div key={idx} className={styles.journeyStep}>
              <span className={styles.journeyNum}>{idx + 1}</span>
              <p>{step}</p>
            </div>
          ))}
        </div>
        <div className={styles.heroActions} style={{ marginTop: "1.5rem" }}>
          <a className={styles.primaryButton} href="#brief">
            {t("primaryCta")}
          </a>
        </div>
      </section>

      <section className={styles.bandSection} id="system">
        <div className={styles.sectionHeading}>
          <span className={styles.sectionTag}>{t("sectionSystem")}</span>
          <h2>{t("systemTitle")}</h2>
        </div>
        <div className={styles.cardGrid}>
          {systemCards.map((card) => (
            <article key={card.title} className={styles.infoCard}>
              <h3>{card.title}</h3>
              <p>{card.body}</p>
            </article>
          ))}
        </div>
      </section>

      <section className={styles.splitSection} id="model">
        <div className={styles.sectionHeading}>
          <span className={styles.sectionTag}>{t("sectionDelivery")}</span>
          <h2>{t("deliveryTitle")}</h2>
        </div>
        <div className={styles.timeline}>
          {deliverySteps.map((item) => (
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
          <span className={styles.sectionTag}>{t("sectionSafety")}</span>
          <h2>{t("railsTitle")}</h2>
        </div>
        <div className={styles.railsGrid}>
          {rails.map((item, index) => (
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
            <span className={styles.sectionTag}>Commercial SaaS</span>
            <h2>{t("saasCtaHeadline")}</h2>
            <p>{t("saasCtaBody")}</p>
          </div>
          <div className={styles.finalActions}>
            <a className={styles.primaryButton} href="#brief">
              {t("saasCtaButton")}
            </a>
            <Link className={styles.secondaryButton} href="/brand/index.html">
              {t("brandAssets")}
            </Link>
          </div>
        </div>
      </section>

      <footer className={styles.footer}>
        <span>Nexa</span>
        <span>{t("footerNote")}</span>
      </footer>
    </main>
  );
}
