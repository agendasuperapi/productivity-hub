import { TabViewer } from '@/components/electron/TabViewer';

export default function Browser() {
  return (
    <div className="h-[calc(100vh-3.5rem)]">
      <TabViewer className="h-full" />
    </div>
  );
}
