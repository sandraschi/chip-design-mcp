import { defineConfig } from '@playwright/test';

export default defineConfig({
    testDir: './e2e',
    timeout: 60000,
    retries: 1,
    use: {
        baseURL: 'http://localhost:11023',
        headless: true,
        screenshot: 'only-on-failure',
    },
    webServer: {
        command: 'uv run python -m chip_design_mcp.server --mode dual --port 11022',
        port: 11022,
        cwd: '../',
        timeout: 30000,
        reuseExistingServer: false,
    },
});
