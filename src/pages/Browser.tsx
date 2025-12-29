import { TabViewer } from '@/components/electron/TabViewer';

export default function Browser() {
  return (
    <div className="h-full overflow-hidden">
      <TabViewer className="h-full" />
    </div>
  );
}
