// @ts-check
// End-to-end smoke test: the one flow that cannot break.
//
// Loads the site, runs through the typing test for claude mode, submits to a
// mocked leaderboard, asserts success. The API is intercepted so real runs
// never touch the live sheet.
//
// Run: npx playwright test

const { test, expect } = require('@playwright/test');

const CLAUDE_PHRASES = [
    'claude --dangerously-skip-permissions',
    'claude --yolo',
    'ccy'
];

test.describe('ccy landing page', () => {
    test.beforeEach(async ({ page }) => {
        // Intercept the Apps Script endpoint. GET → empty leaderboard, POST → fake success.
        await page.route(/script\.google\.com\/macros/, async (route) => {
            const req = route.request();
            if (req.method() === 'POST') {
                return route.fulfill({
                    status: 200,
                    contentType: 'application/json',
                    body: JSON.stringify({ ok: true, rank: 1, total: 1, flagged: false })
                });
            }
            return route.fulfill({
                status: 200,
                contentType: 'application/json',
                body: JSON.stringify({ ok: true, entries: [], mode: 'claude' })
            });
        });
    });

    test('loads, renders hero, and shows the three speed tabs', async ({ page }) => {
        await page.goto('/');
        await expect(page).toHaveTitle(/ccy|cxy|pi/);
        await expect(page.locator('#statsHuman')).toBeVisible();
        await expect(page.locator('#statsVim')).toBeVisible();
        await expect(page.locator('#statsYou')).toBeVisible();
        await expect(page.locator('#installCode')).toContainText('install.sh');
    });

    test('typing test: type all phrases, submit, see success', async ({ page }) => {
        await page.goto('/');

        // Enter the test (switches to "you" tab and focuses hidden input).
        await page.locator('#statsYou').click();

        const input = page.locator('#typingInput');
        await expect(input).toBeAttached();

        // Type each phrase — the state machine auto-advances when the typed
        // value equals the target. A small delay between phrases covers the
        // 700ms post-phase reaction window.
        for (let i = 0; i < CLAUDE_PHRASES.length; i++) {
            await input.focus();
            // Use pressSequentially so each char dispatches an input event,
            // matching what the keystroke counter and recording expect.
            // 50ms/char ≈ 240 wpm — fast, but under the 400 wpm cheat threshold.
            await input.pressSequentially(CLAUDE_PHRASES[i], { delay: 50 });
            if (i < CLAUDE_PHRASES.length - 1) {
                // Wait for the reaction window to clear and next phase to mount.
                await page.waitForTimeout(900);
            }
        }

        // After the final phase, finishTypingTest reveals #typingDone with the submit form.
        await expect(page.locator('#typingDone')).toBeVisible({ timeout: 5000 });

        // Submit under a disposable handle.
        const handle = 'smoketest_' + Date.now().toString(36);
        await page.locator('#submitHandle').fill(handle);
        await page.locator('#submitBtn').click();

        const status = page.locator('#submitStatus');
        await expect(status).toBeVisible();
        // Intercepted response says ok:true, so the UI should show a success state
        // (rank/total/handle baked into showSubmitSuccess).
        await expect(status).toContainText(/#1|first|rank|leaderboard/i, { timeout: 5000 });
    });

    test('invite link lands you in the typing test', async ({ page }) => {
        await page.goto('/?h=mochi');
        // openTypingTest fires on invite; the "you" tab should become active.
        await expect(page.locator('#statsYou.active')).toBeVisible({ timeout: 3000 });
    });

    test('pi mode: type pi three times, see strikethrough alternatives', async ({ page }) => {
        await page.goto('/?pi');
        await page.locator('#statsYou').click();

        // First two phases include a decorative struck-through suffix
        // showing what the user is *not* typing. Verify it's rendered.
        await expect(page.locator('#termText .strike-suffix')).toContainText(
            'claude --dangerously-skip-permissions'
        );

        const input = page.locator('#typingInput');
        for (let i = 0; i < 3; i++) {
            await input.focus();
            await input.pressSequentially('pi', { delay: 80 });
            if (i < 2) await page.waitForTimeout(900);
        }
        await expect(page.locator('#typingDone')).toBeVisible({ timeout: 5000 });
    });
});
