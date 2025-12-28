// Simple encryption/decryption for credentials
// Uses AES-GCM with a key derived from user ID and app secret

const APP_SECRET = 'gerenciazap-secure-key-2024';

async function getKey(userId: string): Promise<CryptoKey> {
  const keyMaterial = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(APP_SECRET + userId),
    { name: 'PBKDF2' },
    false,
    ['deriveBits', 'deriveKey']
  );

  return crypto.subtle.deriveKey(
    {
      name: 'PBKDF2',
      salt: new TextEncoder().encode('gerenciazap-salt'),
      iterations: 100000,
      hash: 'SHA-256',
    },
    keyMaterial,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt']
  );
}

export async function encryptPassword(password: string, userId: string): Promise<string> {
  const key = await getKey(userId);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encodedPassword = new TextEncoder().encode(password);

  const encryptedContent = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    key,
    encodedPassword
  );

  // Combine IV and encrypted content
  const combined = new Uint8Array(iv.length + encryptedContent.byteLength);
  combined.set(iv);
  combined.set(new Uint8Array(encryptedContent), iv.length);

  // Convert to base64
  return btoa(String.fromCharCode(...combined));
}

export async function decryptPassword(encryptedPassword: string, userId: string): Promise<string> {
  try {
    const key = await getKey(userId);
    
    // Decode from base64
    const combined = new Uint8Array(
      atob(encryptedPassword)
        .split('')
        .map((c) => c.charCodeAt(0))
    );

    // Extract IV and encrypted content
    const iv = combined.slice(0, 12);
    const encryptedContent = combined.slice(12);

    const decryptedContent = await crypto.subtle.decrypt(
      { name: 'AES-GCM', iv },
      key,
      encryptedContent
    );

    return new TextDecoder().decode(decryptedContent);
  } catch (error) {
    console.error('Error decrypting password:', error);
    return '';
  }
}

// Extract domain from URL
export function extractDomain(url: string): string {
  try {
    const urlObj = new URL(url);
    return urlObj.hostname;
  } catch {
    return url;
  }
}
