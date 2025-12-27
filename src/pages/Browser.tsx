import { TabViewer } from '@/components/electron/TabViewer';
import { TabViewerMobile } from '@/components/mobile/TabViewerMobile';
import { useCapacitor } from '@/hooks/useCapacitor';
import { useElectron } from '@/hooks/useElectron';

export default function Browser() {
  const { isCapacitor } = useCapacitor();
  const { isElectron } = useElectron();

  // Use mobile viewer on Capacitor, desktop viewer on Electron/Web
  const ViewerComponent = isCapacitor && !isElectron 
    ? TabViewerMobile 
    : TabViewer;

  return (
    <div className="h-[calc(100vh-3.5rem)]">
      <ViewerComponent className="h-full" />
    </div>
  );
}
