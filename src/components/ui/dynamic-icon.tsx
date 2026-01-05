import { icons } from 'lucide-react';

interface DynamicIconProps {
  icon?: string | null;
  fallback?: string;
  className?: string;
}

// Check if string is an emoji
function isEmoji(str: string): boolean {
  const emojiRegex = /[\u{1F300}-\u{1FAD6}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]|[\u{2B50}]|[\u{2764}]|[\u{FE0F}]/u;
  return emojiRegex.test(str);
}

// Convert icon name to PascalCase for Lucide lookup
function toPascalCase(str: string): string {
  return str
    .split(/[-_\s]/)
    .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join('');
}

export function DynamicIcon({ icon, fallback = '📁', className }: DynamicIconProps) {
  if (!icon) {
    return <span className={className}>{fallback}</span>;
  }

  // If it's an emoji, render directly
  if (isEmoji(icon)) {
    return <span className={className}>{icon}</span>;
  }

  // Try to find Lucide icon
  const pascalName = toPascalCase(icon);
  const LucideIcon = icons[pascalName as keyof typeof icons];

  if (LucideIcon) {
    return <LucideIcon className={className || "h-4 w-4"} />;
  }

  // Fallback to text or default
  return <span className={className}>{fallback}</span>;
}
