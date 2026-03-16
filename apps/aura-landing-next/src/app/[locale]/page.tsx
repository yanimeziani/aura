import Link from "next/link";

import styles from "../docs.module.css";
import { getDocsIndex, type DocEntry } from "../../lib/docs";

const LOCALE_LABELS: Record<string, string> = {
  "en-CA": "EN (CA)",
  "en-US": "EN (US)",
  "en-AU": "EN (AU)",
  "fr-CA": "FR (CA)",
  "ar-DZ": "AR (DZ)",
};

const FEATURED = new Set(["QUICKSTART", "ARCHITECTURE", "PROTOCOL", "TRUST_MODEL"]);

function groupDocs(entries: DocEntry[]) {
  return entries.reduce<Record<string, DocEntry[]>>((acc, entry) => {
    const key = entry.section;
    acc[key] ??= [];
    acc[key].push(entry);
    return acc;
  }, {});
}

export default async function LocaleDocsIndex({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  const docs = getDocsIndex();
  const grouped = groupDocs(docs);
  const featured = docs.filter((entry) => FEATURED.has(entry.basename)).slice(0, 4);
  const isRtl = locale.startsWith("ar");

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
          <a href="#featured">Featured</a>
          <a href="#catalog">Catalog</a>
          <a href="/gw/docs/nexa">Live bundle</a>
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
            <span className={styles.eyebrowChip}>Public Documentation</span>
            <span className={styles.eyebrowChip}>Static Export</span>
            <span className={styles.eyebrowChip}>Hostinger VPS</span>
          </div>
          <h1 className={styles.heroTitle}>Nexa documentation from the repository source tree.</h1>
          <p className={styles.heroLead}>
            This frontend is built directly from the repository <code>docs/</code> folder and
            exported as a static site for <code>nexa.meziani.ai</code>. Pushes to <code>main</code>
            rebuild and deploy it through the mesh workflow.
          </p>
          <div className={styles.heroActions}>
            <a className={styles.primaryButton} href="#featured">
              Read featured docs
            </a>
            <a className={styles.secondaryButton} href="/gw/docs/nexa">
              Open live bundle
            </a>
          </div>
        </div>

        <aside className={styles.statusPanel}>
          <div className={styles.panelLabel}>Source of truth</div>
          <h2>Repository-backed docs frontend</h2>
          <ul className={styles.metricList}>
            <li>
              <span>{docs.length}</span>
              <strong>documents indexed</strong>
            </li>
            <li>
              <span>{Object.keys(grouped).length}</span>
              <strong>sections available</strong>
            </li>
            <li>
              <span>CI/CD</span>
              <strong>push to main deploys Hostinger VPS</strong>
            </li>
          </ul>
        </aside>
      </section>

      <section id="featured" className={styles.sectionBlock}>
        <div className={styles.sectionHeader}>
          <span className={styles.sectionTag}>Featured</span>
          <h2>Core references</h2>
        </div>
        <div className={styles.cardGrid}>
          {featured.map((entry) => (
            <Link key={entry.href} href={`/${locale}${entry.href}`} className={styles.docCard}>
              <span className={styles.docMeta}>{entry.sectionLabel}</span>
              <h3>{entry.title}</h3>
              <p>{entry.summary}</p>
            </Link>
          ))}
        </div>
      </section>

      <section id="catalog" className={styles.sectionBlock}>
        <div className={styles.sectionHeader}>
          <span className={styles.sectionTag}>Catalog</span>
          <h2>Documentation index</h2>
        </div>
        <div className={styles.sectionGrid}>
          {Object.entries(grouped)
            .sort(([a], [b]) => a.localeCompare(b))
            .map(([section, entries]) => (
              <section key={section} className={styles.catalogSection}>
                <div className={styles.catalogHeader}>
                  <h3>{entries[0]?.sectionLabel ?? section}</h3>
                  <span>{entries.length} docs</span>
                </div>
                <div className={styles.catalogList}>
                  {entries.map((entry) => (
                    <Link
                      key={entry.href}
                      href={`/${locale}${entry.href}`}
                      className={styles.catalogItem}
                    >
                      <strong>{entry.title}</strong>
                      <span>{entry.summary}</span>
                    </Link>
                  ))}
                </div>
              </section>
            ))}
        </div>
      </section>
    </main>
  );
}
