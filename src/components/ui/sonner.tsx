import { useTheme } from "next-themes";
import { Toaster as Sonner, toast } from "sonner";
import { useEffect, useState } from "react";

type ToasterProps = React.ComponentProps<typeof Sonner>;

type ToastPosition = 'top-left' | 'top-center' | 'top-right' | 'bottom-left' | 'bottom-center' | 'bottom-right';

const Toaster = ({ ...props }: ToasterProps) => {
  const { theme = "system" } = useTheme();
  const [position, setPosition] = useState<ToastPosition>('bottom-right');

  // Load position from localStorage
  useEffect(() => {
    const loadPosition = () => {
      try {
        const settings = localStorage.getItem('user-settings');
        if (settings) {
          const parsed = JSON.parse(settings);
          if (parsed.notifications?.toast_position) {
            setPosition(parsed.notifications.toast_position);
          }
        }
      } catch {
        // Use default position
      }
    };

    loadPosition();

    // Listen for storage changes
    const handleStorageChange = (e: StorageEvent) => {
      if (e.key === 'user-settings') {
        loadPosition();
      }
    };

    window.addEventListener('storage', handleStorageChange);
    
    // Also poll for changes (for same-tab updates)
    const interval = setInterval(loadPosition, 1000);

    return () => {
      window.removeEventListener('storage', handleStorageChange);
      clearInterval(interval);
    };
  }, []);

  return (
    <Sonner
      theme={theme as ToasterProps["theme"]}
      className="toaster group"
      position={position}
      toastOptions={{
        classNames: {
          toast:
            "group toast group-[.toaster]:bg-background group-[.toaster]:text-foreground group-[.toaster]:border-border group-[.toaster]:shadow-lg",
          description: "group-[.toast]:text-muted-foreground",
          actionButton: "group-[.toast]:bg-primary group-[.toast]:text-primary-foreground",
          cancelButton: "group-[.toast]:bg-muted group-[.toast]:text-muted-foreground",
        },
      }}
      {...props}
    />
  );
};

export { Toaster, toast };
