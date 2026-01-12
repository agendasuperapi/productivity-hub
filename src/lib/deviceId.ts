// Generates and persists a unique device ID for this installation
// This allows multiple sessions for the same user across different devices

const DEVICE_ID_KEY = 'gerenciazap_device_id';

function generateDeviceId(): string {
  const timestamp = Date.now().toString(36);
  const randomPart = Math.random().toString(36).substring(2, 15);
  const randomPart2 = Math.random().toString(36).substring(2, 15);
  return `${timestamp}-${randomPart}-${randomPart2}`;
}

export function getDeviceId(): string {
  let deviceId = localStorage.getItem(DEVICE_ID_KEY);
  
  if (!deviceId) {
    deviceId = generateDeviceId();
    localStorage.setItem(DEVICE_ID_KEY, deviceId);
  }
  
  return deviceId;
}

export function getStorageKeyForDevice(): string {
  const deviceId = getDeviceId();
  return `sb-session-${deviceId}`;
}
