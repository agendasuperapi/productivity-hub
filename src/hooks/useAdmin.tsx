import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';

interface AdminState {
  isAdmin: boolean;
  isSuperAdmin: boolean;
  loading: boolean;
}

export function useAdmin(): AdminState {
  const { user } = useAuth();
  const [state, setState] = useState<AdminState>({
    isAdmin: false,
    isSuperAdmin: false,
    loading: true,
  });

  useEffect(() => {
    if (!user) {
      setState({ isAdmin: false, isSuperAdmin: false, loading: false });
      return;
    }

    const checkRole = async () => {
      try {
        const { data, error } = await supabase
          .from('user_roles')
          .select('role')
          .eq('user_id', user.id);

        if (error) {
          console.error('Error checking user role:', error);
          setState({ isAdmin: false, isSuperAdmin: false, loading: false });
          return;
        }

        const roles = data?.map(r => r.role) || [];
        const isSuperAdmin = roles.includes('super_admin');
        const isAdmin = isSuperAdmin || roles.includes('admin');

        setState({ isAdmin, isSuperAdmin, loading: false });
      } catch (err) {
        console.error('Error checking role:', err);
        setState({ isAdmin: false, isSuperAdmin: false, loading: false });
      }
    };

    checkRole();
  }, [user]);

  return state;
}
