import { TabViewer } from '@/components/electron/TabViewer';
import { BrowserProvider } from '@/contexts/BrowserContext';

export default function Browser() {
  return (
    <BrowserProvider>
      <div className="h-[calc(100vh-3.5rem)]">
        <TabViewer className="h-full" />
      </div>
    </BrowserProvider>
  );
}
