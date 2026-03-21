#!/usr/bin/env node
import { chromium } from "playwright";
import fs from "node:fs";
import path from "node:path";

const notebookUrl = process.env.NOTEBOOKLM_NOTEBOOK_URL || "";
const sourceMode = (process.env.NOTEBOOKLM_SOURCE_MODE || "url").toLowerCase();
const sourceUrl = process.env.NOTEBOOKLM_SOURCE_URL || "http://127.0.0.1:8765/docs/nexa";
const sourceFile = process.env.NOTEBOOKLM_SOURCE_FILE || path.resolve(process.cwd(), "nexa-docs-notebooklm.txt");
const userDataDir = process.env.NOTEBOOKLM_USER_DATA_DIR || path.resolve(process.cwd(), ".nexa/playwright/notebooklm");
const headless = (process.env.NOTEBOOKLM_HEADLESS || "0") === "1";

if (!notebookUrl) {
  console.error("Set NOTEBOOKLM_NOTEBOOK_URL to the target notebook URL.");
  process.exit(1);
}
if (sourceMode === "file" && !fs.existsSync(sourceFile)) {
  console.error(`Source file does not exist: ${sourceFile}`);
  process.exit(1);
}

const addSourceLabels = [
  "Add source",
  "Add sources",
  "Create new source",
];
const sourceTypeLabels = {
  url: ["Website", "Link", "Web link", "Website URL"],
  file: ["Upload", "Upload source", "PDF, website, text or audio file", "File"],
};

async function clickFirst(page, labels) {
  for (const label of labels) {
    const button = page.getByRole("button", { name: label }).first();
    if (await button.count()) {
      await button.click({ timeout: 5000 });
      return true;
    }
    const text = page.getByText(label, { exact: true }).first();
    if (await text.count()) {
      await text.click({ timeout: 5000 });
      return true;
    }
  }
  return false;
}

async function waitForManualLogin(page) {
  const current = page.url();
  if (!current.includes("accounts.google.com")) return;
  console.log("Waiting for manual Google login in the opened browser...");
  await page.waitForURL(/notebooklm\.google\.com/, { timeout: 0 });
}

const context = await chromium.launchPersistentContext(userDataDir, {
  headless,
  channel: "chromium",
  viewport: { width: 1440, height: 1024 },
});

try {
  const page = context.pages()[0] || await context.newPage();
  await page.goto(notebookUrl, { waitUntil: "domcontentloaded" });
  await waitForManualLogin(page);
  await page.waitForLoadState("networkidle");

  const openedAddSource = await clickFirst(page, addSourceLabels);
  if (!openedAddSource) {
    throw new Error("Could not find an Add source control in NotebookLM.");
  }

  const openedSourceType = await clickFirst(page, sourceTypeLabels[sourceMode] || []);
  if (!openedSourceType && sourceMode === "url") {
    const input = page.locator('input[type="url"], input[placeholder*="https"], textarea').first();
    await input.waitFor({ state: "visible", timeout: 10000 });
    await input.fill(sourceUrl);
  } else if (!openedSourceType && sourceMode === "file") {
    const fileInput = page.locator('input[type="file"]').first();
    await fileInput.setInputFiles(sourceFile);
  }

  if (sourceMode === "url") {
    const input = page.locator('input[type="url"], input[placeholder*="https"], textarea').first();
    await input.waitFor({ state: "visible", timeout: 10000 });
    await input.fill(sourceUrl);
    const submitted = await clickFirst(page, ["Insert", "Add", "Upload", "Save"]);
    if (!submitted) {
      await input.press("Enter");
    }
  } else {
    const fileInput = page.locator('input[type="file"]').first();
    await fileInput.setInputFiles(sourceFile);
  }

  await page.waitForLoadState("networkidle");
  console.log(`NotebookLM upload flow executed in ${sourceMode} mode.`);
  console.log(`Notebook: ${notebookUrl}`);
  console.log(sourceMode === "url" ? `Source URL: ${sourceUrl}` : `Source file: ${sourceFile}`);
} finally {
  await context.close();
}
