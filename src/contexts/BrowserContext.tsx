import { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';

interface TabUrl {
  url: string;
  shortcut_enabled?: boolean;
  zoom?: number;
}

interface Tab {
  id: string;
  name: string;
  url: string;
  urls?: TabUrl[];
  layout_type?: string;
  zoom?: number;
  icon?: string;
  color?: string;
  keyboard_shortcut?: string;
  open_as_window?: boolean;
  position: number;
}

interface TabGroup {
  id: string;
  name: string;
  icon?: string;
  color?: string;
  position: number;
  tabs: Tab[];
}

interface BrowserContextType {
  groups: TabGroup[];
  activeGroup: TabGroup | null;
  activeTab: Tab | null;
  loading: boolean;
  setActiveGroup: (group: TabGroup | null) => void;
  setActiveTab: (tab: Tab | null) => void;
}

const BrowserContext = createContext<BrowserContextType | undefined>(undefined);

export function BrowserProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  const [groups, setGroups] = useState<TabGroup[]>([]);
  const [activeGroup, setActiveGroup] = useState<TabGroup | null>(null);
  const [activeTab, setActiveTab] = useState<Tab | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchData() {
      if (!user) return;

      const [groupsRes, tabsRes] = await Promise.all([
        supabase.from('tab_groups').select('*').order('position'),
        supabase.from('tabs').select('*').order('position'),
      ]);

      const groupsData = groupsRes.data || [];
      const tabsData = tabsRes.data || [];

      const groupsWithTabs: TabGroup[] = groupsData.map(group => ({
        ...group,
        tabs: tabsData
          .filter(tab => tab.group_id === group.id)
          .map(tab => ({
            ...tab,
            urls: Array.isArray(tab.urls) ? (tab.urls as unknown as TabUrl[]) : [],
          }))
      }));

      setGroups(groupsWithTabs);
      
      if (groupsWithTabs.length > 0) {
        setActiveGroup(groupsWithTabs[0]);
        if (groupsWithTabs[0].tabs.length > 0) {
          setActiveTab(groupsWithTabs[0].tabs[0]);
        }
      }
      
      setLoading(false);
    }

    fetchData();
  }, [user]);

  const handleSetActiveGroup = (group: TabGroup | null) => {
    setActiveGroup(group);
    if (group && group.tabs.length > 0) {
      const firstTab = group.tabs[0];
      if (!firstTab.open_as_window) {
        setActiveTab(firstTab);
      }
    }
  };

  return (
    <BrowserContext.Provider value={{
      groups,
      activeGroup,
      activeTab,
      loading,
      setActiveGroup: handleSetActiveGroup,
      setActiveTab,
    }}>
      {children}
    </BrowserContext.Provider>
  );
}

export function useBrowser() {
  const context = useContext(BrowserContext);
  if (!context) {
    throw new Error('useBrowser must be used within a BrowserProvider');
  }
  return context;
}
