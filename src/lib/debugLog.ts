// Debug logging utility - controlled by local settings
const STORAGE_KEY = 'local-device-settings';

function isDebugEnabled(): boolean {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored) {
      const parsed = JSON.parse(stored);
      return parsed.debug_mode === true;
    }
  } catch {
    // Ignore errors
  }
  return false;
}

// Cache the debug state and update on storage changes
let debugEnabled = isDebugEnabled();

if (typeof window !== 'undefined') {
  window.addEventListener('storage', (e) => {
    if (e.key === STORAGE_KEY) {
      debugEnabled = isDebugEnabled();
    }
  });
  
  // Also listen for custom event for same-window updates
  window.addEventListener('debug-mode-changed', () => {
    debugEnabled = isDebugEnabled();
  });
}

export function debugLog(...args: any[]) {
  if (debugEnabled || isDebugEnabled()) {
    console.log('[DEBUG]', ...args);
  }
}

export function debugWarn(...args: any[]) {
  if (debugEnabled || isDebugEnabled()) {
    console.warn('[DEBUG]', ...args);
  }
}

export function debugError(...args: any[]) {
  // Errors are always logged
  console.error('[DEBUG]', ...args);
}

export function debugGroup(label: string) {
  if (debugEnabled || isDebugEnabled()) {
    console.group('[DEBUG] ' + label);
  }
}

export function debugGroupEnd() {
  if (debugEnabled || isDebugEnabled()) {
    console.groupEnd();
  }
}

export function refreshDebugState() {
  debugEnabled = isDebugEnabled();
  return debugEnabled;
}

export function getDebugEnabled(): boolean {
  return debugEnabled;
}
