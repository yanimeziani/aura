import fs from "node:fs";
import path from "node:path";
import type { ReactNode } from "react";

import styles from "../app/docs.module.css";

export type DocEntry = {
  basename: string;
  content: string;
  filePath: string;
  href: string;
  section: string;
  sectionLabel: string;
  slug: string[];
  summary: string;
  title: string;
};

function resolveDocsRoot() {
  const candidates = [
    path.resolve(process.cwd(), "docs"),
    path.resolve(process.cwd(), "..", "..", "docs"),
  ];

  const found = candidates.find((candidate) => fs.existsSync(candidate));
  if (!found) {
    throw new Error("Could not resolve repo docs directory.");
  }
  return found;
}

const DOCS_ROOT = resolveDocsRoot();

function prettifySegment(input: string) {
  return input
    .replace(/[-_]/g, " ")
    .replace(/\b\w/g, (char) => char.toUpperCase());
}

function collectMarkdownFiles(dir: string): string[] {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      return collectMarkdownFiles(fullPath);
    }
    return entry.name.endsWith(".md") ? [fullPath] : [];
  });
}

function firstParagraph(content: string) {
  const paragraph = content
    .split(/\n{2,}/)
    .map((block) => block.trim())
    .find((block) => block && !block.startsWith("#") && !block.startsWith("```"));

  return (paragraph ?? "Repository documentation.").replace(/\n/g, " ").slice(0, 220);
}

function titleFromContent(content: string, fallback: string) {
  const heading = content
    .split("\n")
    .find((line) => line.trim().startsWith("# "))
    ?.replace(/^#\s+/, "")
    .trim();

  return heading || prettifySegment(fallback);
}

function inlineMarkdown(text: string, keyPrefix: string): ReactNode[] {
  const nodes: ReactNode[] = [];
  const pattern = /(`[^`]+`)|(\[[^\]]+\]\([^)]+\))|(\*\*[^*]+\*\*)/g;
  let lastIndex = 0;
  let match: RegExpExecArray | null;

  while ((match = pattern.exec(text)) !== null) {
    if (match.index > lastIndex) {
      nodes.push(text.slice(lastIndex, match.index));
    }

    const token = match[0];
    if (token.startsWith("`")) {
      nodes.push(<code key={`${keyPrefix}-${match.index}`}>{token.slice(1, -1)}</code>);
    } else if (token.startsWith("[")) {
      const parts = token.match(/^\[([^\]]+)\]\(([^)]+)\)$/);
      if (parts) {
        nodes.push(
          <a key={`${keyPrefix}-${match.index}`} href={parts[2]}>
            {parts[1]}
          </a>
        );
      } else {
        nodes.push(token);
      }
    } else if (token.startsWith("**")) {
      nodes.push(
        <strong key={`${keyPrefix}-${match.index}`}>{token.slice(2, -2)}</strong>
      );
    }

    lastIndex = match.index + token.length;
  }

  if (lastIndex < text.length) {
    nodes.push(text.slice(lastIndex));
  }

  return nodes;
}

export function getDocsIndex(): DocEntry[] {
  return collectMarkdownFiles(DOCS_ROOT)
    .map((filePath) => {
      const relative = path.relative(DOCS_ROOT, filePath);
      const slug = relative.replace(/\.md$/, "").split(path.sep);
      const content = fs.readFileSync(filePath, "utf8");
      const basename = path.basename(filePath, ".md");
      const section = slug.length > 1 ? slug[0] : "core";

      return {
        basename,
        content,
        filePath,
        href: `/docs/${slug.join("/")}`,
        section,
        sectionLabel: prettifySegment(section),
        slug,
        summary: firstParagraph(content),
        title: titleFromContent(content, basename),
      };
    })
    .sort((a, b) => a.href.localeCompare(b.href));
}

export function getDocBySlug(slug: string[]) {
  return getDocsIndex().find((entry) => entry.slug.join("/") === slug.join("/"));
}

export function renderMarkdown(content: string) {
  const blocks = content.split(/```/);

  return (
    <>
      {blocks.map((block, index) => {
        if (index % 2 === 1) {
          const lines = block.replace(/^\n+|\n+$/g, "").split("\n");
          const language = lines[0]?.trim() || "text";
          const code = lines.slice(1).join("\n");
          return (
            <pre key={`code-${index}`} className={styles.codeBlock}>
              <span className={styles.codeLang}>{language}</span>
              <code>{code}</code>
            </pre>
          );
        }

        return block
          .split(/\n{2,}/)
          .map((section, sectionIndex) => section.trim())
          .filter(Boolean)
          .map((section, sectionIndex) => {
            const key = `block-${index}-${sectionIndex}`;
            const lines = section.split("\n");

            if (lines.every((line) => /^[-*]\s+/.test(line))) {
              return (
                <ul key={key} className={styles.articleList}>
                  {lines.map((line, itemIndex) => (
                    <li key={`${key}-${itemIndex}`}>
                      {inlineMarkdown(line.replace(/^[-*]\s+/, ""), `${key}-${itemIndex}`)}
                    </li>
                  ))}
                </ul>
              );
            }

            if (lines.every((line) => /^\d+\.\s+/.test(line))) {
              return (
                <ol key={key} className={styles.articleList}>
                  {lines.map((line, itemIndex) => (
                    <li key={`${key}-${itemIndex}`}>
                      {inlineMarkdown(line.replace(/^\d+\.\s+/, ""), `${key}-${itemIndex}`)}
                    </li>
                  ))}
                </ol>
              );
            }

            const heading = lines[0];
            if (/^####\s+/.test(heading)) {
              return <h4 key={key}>{heading.replace(/^####\s+/, "")}</h4>;
            }
            if (/^###\s+/.test(heading)) {
              return <h3 key={key}>{heading.replace(/^###\s+/, "")}</h3>;
            }
            if (/^##\s+/.test(heading)) {
              return <h2 key={key}>{heading.replace(/^##\s+/, "")}</h2>;
            }
            if (/^#\s+/.test(heading)) {
              return <h1 key={key}>{heading.replace(/^#\s+/, "")}</h1>;
            }
            if (lines.every((line) => line.startsWith("> "))) {
              return (
                <blockquote key={key} className={styles.blockQuote}>
                  {lines.map((line, lineIndex) => (
                    <p key={`${key}-${lineIndex}`}>
                      {inlineMarkdown(line.replace(/^>\s?/, ""), `${key}-${lineIndex}`)}
                    </p>
                  ))}
                </blockquote>
              );
            }

            return (
              <p key={key}>
                {inlineMarkdown(lines.join(" "), key)}
              </p>
            );
          });
      })}
    </>
  );
}
