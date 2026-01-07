import { useEffect } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { TabViewer } from '@/components/electron/TabViewer';
import { useBrowser } from '@/contexts/BrowserContext';

type BrowserNavState = {
  virtualTab?: {
    route: string;
    name: string;
    icon: string;
  };
};

export default function Browser() {
  const location = useLocation();
  const navigate = useNavigate();
  const { openVirtualTab } = useBrowser();

  useEffect(() => {
    const state = location.state as BrowserNavState | null;
    if (!state?.virtualTab) return;

    openVirtualTab(state.virtualTab.route, state.virtualTab.name, state.virtualTab.icon);

    // Limpar o state para não reabrir ao recarregar/voltar
    navigate('/browser', { replace: true, state: null });
  }, [location.state, navigate, openVirtualTab]);

  return (
    <div className="h-full overflow-hidden">
      <TabViewer className="h-full" />
    </div>
  );
}
