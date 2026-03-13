import { test, expect } from '@playwright/test';

test.describe('Demo UI', () => {
  test.describe('Landing page demo section', () => {
    test('shows demo section on English landing page', async ({ page }) => {
      await page.goto('/en');
      await expect(page.getByRole('heading', { name: /see how it works/i })).toBeVisible();
      await expect(page.locator('#demo')).toBeVisible();
      await expect(page.getByPlaceholder(/type anything to test the agent/i)).toBeVisible();
    });

    test('shows demo section on French landing page', async ({ page }) => {
      await page.goto('/fr');
      await expect(page.getByRole('heading', { name: /voyez comment ça fonctionne/i })).toBeVisible();
      await expect(page.locator('#demo')).toBeVisible();
      await expect(page.getByPlaceholder(/tapez n'importe quoi pour tester l'agent/i)).toBeVisible();
    });

    test('Watch demo button scrolls to demo section', async ({ page }) => {
      await page.goto('/en');
      await page.getByRole('link', { name: /watch.*demo/i }).first().click();
      await expect(page.locator('#demo')).toBeInViewport();
    });
  });

  test.describe('Demo page', () => {
    test('loads demo page in English', async ({ page }) => {
      await page.goto('/en/demo');
      await expect(page).toHaveTitle(/Live Demo.*Dragun/);
      await expect(page.getByRole('heading', { name: /see how it works/i })).toBeVisible();
      await expect(page.getByRole('link', { name: /back to home/i })).toBeVisible();
      await expect(page.getByPlaceholder(/type anything to test the agent/i)).toBeVisible();
    });

    test('loads demo page in French', async ({ page }) => {
      await page.goto('/fr/demo');
      await expect(page).toHaveTitle(/Démo en direct.*Dragun/);
      await expect(page.getByRole('heading', { name: /voyez comment ça fonctionne/i })).toBeVisible();
      await expect(page.getByRole('link', { name: /retour à l'accueil/i })).toBeVisible();
      await expect(page.getByPlaceholder(/tapez n'importe quoi pour tester l'agent/i)).toBeVisible();
    });

    test('interactive demo responds to quick action', async ({ page }) => {
      await page.goto('/en/demo');
      await page.getByRole('button', { name: /i'd like to pay now/i }).click();
      await expect(page.getByText(/great decision/i)).toBeVisible({ timeout: 5000 });
    });

    test('interactive demo responds to custom input', async ({ page }) => {
      await page.goto('/en/demo');
      const input = page.getByPlaceholder(/type anything to test the agent/i);
      await input.fill('I want to dispute this');
      await input.press('Enter');
      await expect(page.getByText(/understand your concern/i)).toBeVisible({ timeout: 5000 });
    });
  });

  test.describe('Navigation to demo', () => {
    test('Navbar links to demo page', async ({ page }) => {
      await page.goto('/en');
      await page.getByRole('link', { name: /watch demo|demo/i }).first().click();
      await expect(page).toHaveURL(/\/(en\/)?demo/);
    });

    test('Footer links to demo page', async ({ page }) => {
      await page.goto('/en');
      await page.getByRole('link', { name: 'Demo' }).click();
      await expect(page).toHaveURL(/\/(en\/)?demo/);
    });
  });
});
