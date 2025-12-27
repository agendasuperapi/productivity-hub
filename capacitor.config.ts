import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'app.lovable.0efa12d059c14ad7bfcfa56f3aa9eeea',
  appName: 'gerenciazap01',
  webDir: 'dist',
  server: {
    url: 'https://0efa12d0-59c1-4ad7-bfcf-a56f3aa9eeea.lovableproject.com?forceHideBadge=true',
    cleartext: true
  },
  plugins: {
    Clipboard: {
      writeEnabled: true,
      readEnabled: true
    }
  }
};

export default config;
