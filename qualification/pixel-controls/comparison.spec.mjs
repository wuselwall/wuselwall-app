import fs from 'node:fs';
import path from 'node:path';
import sharp from 'sharp';
import { test, expect } from 'playwright/test';

// These are generated mathematical fixtures in build/, never approved UI baselines.
test.beforeEach(async ({}, info) => {
  const file = info.snapshotPath('white.png');
  fs.mkdirSync(path.dirname(file), { recursive: true });
  await sharp({ create: { width: 32, height: 32, channels: 3, background: '#ffffff' } }).png().toFile(file);
});

test('accept measured raster noise of at most nine channel levels', async ({ page }) => {
  await page.setContent('<style>html, body { margin: 0; background: rgb(246, 246, 246); }</style>');
  await expect(page).toHaveScreenshot('white.png');
});

test('reject a real colour change with the same comparison policy', async ({ page }) => {
  await page.setContent('<style>html, body { margin: 0; background: black; }</style>');
  test.fail();
  await expect(page).toHaveScreenshot('white.png');
});
