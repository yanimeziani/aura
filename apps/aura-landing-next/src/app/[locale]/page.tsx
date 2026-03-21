import { getTranslations } from "next-intl/server";
import { setRequestLocale } from "next-intl/server";
import Link from "next/link";
import styles from "../docs.module.css";

const LOCALE_LABELS: Record<string, string> = {
  en: "EN",
  es: "ES",
  zh: "ZH",
  hi: "HI",
  ar: "AR",
  pt: "PT",
  fr: "FR",
  ru: "RU",
};

export default async function LandingPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations();
  const isRtl = locale === "ar";

  return (
    <main className={styles.pageShell} dir={isRtl ? "rtl" : "ltr"}>
      <div className={styles.backgroundMesh} aria-hidden="true" />
      <div className={styles.backgroundGrid} aria-hidden="true" />

      <header className={styles.topbar}>
        <div className={styles.wordmarkBlock}>
          <span className={styles.wordmark}>Nexa</span>
          <span className={styles.wordsub}>nexa.meziani.ai</span>
        </div>

        <nav className={styles.nav}>
          <a href="#protocol">{t("navSystem")}</a>
          <a href="#safety">{t("navSafety")}</a>
          <a href="#brief">{t("navBrief")}</a>
        </nav>

        <div className={styles.segmentToggle} aria-label="Locale">
          {Object.entries(LOCALE_LABELS).map(([targetLocale, label]) => (
            <Link
              key={targetLocale}
              href={`/${targetLocale}`}
              className={`${styles.toggleButton} ${
                locale === targetLocale ? styles.toggleActive : ""
              }`}
            >
              {label}
            </Link>
          ))}
        </div>
      </header>

      <section className={styles.docsHero}>
        <div className={styles.heroCopy}>
          <div className={styles.eyebrowRow}>
            <span className={styles.eyebrowChip}>{t("heroEyebrow")}</span>
            <span className={styles.eyebrowChip}>{t("funnelTag")}</span>
          </div>
          <h1 className={styles.heroTitle}>{t("heroTitle")}</h1>
          <p className={styles.heroLead}>{t("heroLead")}</p>
          <div className={styles.heroActions}>
            <a className={styles.primaryButton} href="#brief">
              {t("primaryCta")}
            </a>
            <a className={styles.secondaryButton} href="/docs">
              {t("secondaryCta")}
            </a>
          </div>
        </div>

        <aside className={styles.statusPanel}>
          <div className={styles.panelLabel}>{t("operatingPremise")}</div>
          <h2>{t("phasesHeadline")}</h2>
          <ul className={styles.metricList}>
            <li>
              <span>1.0</span>
              <strong>{t("metricControl")}</strong>
            </li>
            <li>
              <span>48h</span>
              <strong>{t("metricTurnaround")}</strong>
            </li>
            <li>
              <span>0%</span>
              <strong>{t("metricLockin")}</strong>
            </li>
          </ul>
        </aside>
      </section>

      <section id="protocol" className={styles.sectionBlock}>
        <div className={styles.sectionHeader}>
          <span className={styles.sectionTag}>{t("sectionSystem")}</span>
          <h2>{t("systemTitle")}</h2>
        </div>
        <div className={styles.cardGrid}>
          {(t.raw("systemCards") as any[]).map((card, idx) => (
            <div key={idx} className={styles.docCard}>
              <h3>{card.title}</h3>
              <p>{card.body}</p>
            </div>
          ))}
        </div>
      </section>

      <section id="mesh" className={styles.sectionBlock}>
        <div className={styles.sectionHeader}>
          <span className={styles.sectionTag}>{t("sectionDelivery")}</span>
          <h2>{t("deliveryTitle")}</h2>
        </div>
        <div className={styles.catalogList}>
          {(t.raw("deliverySteps") as any[]).map((step, idx) => (
            <div key={idx} className={styles.catalogItem}>
              <strong>{step.step} · {step.title}</strong>
              <span>{step.body}</span>
            </div>
          ))}
        </div>
      </section>

      <section id="safety" className={styles.sectionBlock}>
        <div className={styles.sectionHeader}>
          <span className={styles.sectionTag}>{t("sectionSafety")}</span>
          <h2>{t("railsTitle")}</h2>
        </div>
        <ul className={styles.metricList} style={{ display: "grid", gap: "1rem" }}>
          {(t.raw("rails") as string[]).map((rail, idx) => (
            <li key={idx} style={{ textAlign: isRtl ? "right" : "left" }}>
              <strong>{rail}</strong>
            </li>
          ))}
        </ul>
      </section>

      <footer className={styles.topbar} style={{ marginTop: "4rem", borderTop: "1px solid var(--border-subtle)", paddingTop: "2rem" }}>
         <p style={{ opacity: 0.6 }}>{t("footerNote")}</p>
         <p style={{ opacity: 0.4, fontSize: "0.8rem" }}>{t("formFootnote")}</p>
      </footer>
    </main>
  );
}
