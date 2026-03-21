import Link from "next/link";
import { notFound } from "next/navigation";

import styles from "../../../docs.module.css";
import { getDocBySlug, getDocsIndex, renderMarkdown } from "../../../../lib/docs";

export function generateStaticParams() {
  return getDocsIndex().map((entry) => ({ slug: entry.slug }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string[] }>;
}) {
  const { slug } = await params;
  const doc = getDocBySlug(slug);
  if (!doc) {
    return {};
  }
  return {
    title: `${doc.title} | Nexa Docs`,
    description: doc.summary,
  };
}

export default async function DocsArticlePage({
  params,
}: {
  params: Promise<{ locale: string; slug: string[] }>;
}) {
  const { locale, slug } = await params;
  const doc = getDocBySlug(slug);
  if (!doc) {
    notFound();
  }

  const related = getDocsIndex()
    .filter((entry) => entry.section === doc.section)
    .slice(0, 10);
  const isRtl = locale.startsWith("ar");

  return (
    <main className={styles.pageShell} dir={isRtl ? "rtl" : "ltr"}>
      <div className={styles.backgroundMesh} aria-hidden="true" />
      <div className={styles.backgroundGrid} aria-hidden="true" />

      <header className={styles.topbar}>
        <div className={styles.wordmarkBlock}>
          <span className={styles.wordmark}>Nexa</span>
          <span className={styles.wordsub}>repository docs</span>
        </div>
        <nav className={styles.nav}>
          <Link href={`/${locale}`}>Index</Link>
          <a href="/gw/docs/nexa">Live bundle</a>
        </nav>
      </header>

      <section className={styles.articleLayout}>
        <aside className={styles.articleSidebar}>
          <div className={styles.sectionTag}>{doc.sectionLabel}</div>
          <h1 className={styles.articleTitle}>{doc.title}</h1>
          <p className={styles.articleSummary}>{doc.summary}</p>
          <div className={styles.sidebarBlock}>
            <div className={styles.panelLabel}>Related</div>
            <div className={styles.sidebarLinks}>
              {related.map((entry) => (
                <Link
                  key={entry.href}
                  href={`/${locale}${entry.href}`}
                  className={`${styles.sidebarLink} ${
                    entry.href === doc.href ? styles.sidebarLinkActive : ""
                  }`}
                >
                  {entry.title}
                </Link>
              ))}
            </div>
          </div>
        </aside>

        <article className={styles.articlePanel}>{renderMarkdown(doc.content)}</article>
      </section>
    </main>
  );
}
