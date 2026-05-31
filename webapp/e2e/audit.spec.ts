import { test, expect } from '@playwright/test';

const BE = 'http://127.0.0.1:11022';
const FE = 'http://127.0.0.1:11023';

test.describe('Fleet Audit', () => {
    test('Backend health', async ({ request }) => {
        const resp = await request.get(BE + '/api/v1/status');
        expect(resp.status()).toBe(200);
        const body = await resp.json();
        expect(body.server).toBe('chip-design-mcp');
    });

    test('Backend tools list', async ({ request }) => {
        const resp = await request.get(BE + '/api/v1/tools');
        expect(resp.status()).toBe(200);
        const body = await resp.json();
        expect(body.count).toBeGreaterThan(0);
        expect(body.tools).toContain('chip_status');
    });

    test('Frontend loads', async ({ page }) => {
        await page.goto(FE, { timeout: 15000 });
        await page.waitForTimeout(3000);
        await expect(page.locator('#root')).toBeAttached();
    });

    test('Dashboard renders', async ({ page }) => {
        await page.goto(FE, { timeout: 15000 });
        await page.waitForTimeout(2000);
        await expect(page.locator('text=Chip Design Dashboard')).toBeVisible({ timeout: 5000 });
    });

    test('Navigation works', async ({ page }) => {
        await page.goto(FE, { timeout: 15000 });
        await page.waitForTimeout(2000);

        const navLinks = ['Synthesis', 'Simulation', 'Place & Route', 'Verification', 'Standard Cells', 'Depot', 'Status'];
        for (const label of navLinks) {
            const link = page.locator(`text=${label}`).first();
            if (await link.isVisible({ timeout: 2000 })) {
                await link.click();
                await page.waitForTimeout(500);
            }
        }
    });
});
