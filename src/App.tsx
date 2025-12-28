import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { HashRouter, Routes, Route, useLocation } from "react-router-dom";
import { AuthProvider } from "@/hooks/useAuth";
import { ThemeProvider } from "@/hooks/useTheme";
import { AppLayout } from "@/components/layout/AppLayout";
import { ColorInitializer } from "@/components/ColorInitializer";
import { FloatingShortcutsButton } from "@/components/mobile/FloatingShortcutsButton";
import Dashboard from "./pages/Dashboard";
import Auth from "./pages/Auth";
import TabGroups from "./pages/TabGroups";
import Shortcuts from "./pages/Shortcuts";
import Settings from "./pages/Settings";
import Browser from "./pages/Browser";
import NotFound from "./pages/NotFound";
import Downloads from "./pages/Downloads";
import AdminDashboard from "./pages/admin/AdminDashboard";
import AdminUsers from "./pages/admin/AdminUsers";
import AdminVersions from "./pages/admin/AdminVersions";
import Passwords from "./pages/Passwords";

const queryClient = new QueryClient();

function AppRoutes() {
  const location = useLocation();
  const isBrowserRoute = location.pathname === '/browser';

  return (
    <>
      {/* Browser sempre montado, apenas escondido */}
      <div style={{ display: isBrowserRoute ? 'block' : 'none', height: '100%' }}>
        <AppLayout>
          <Browser />
        </AppLayout>
      </div>

      {/* Outras rotas renderizadas normalmente */}
      {!isBrowserRoute && (
        <Routes>
          <Route path="/auth" element={<Auth />} />
          <Route path="/downloads" element={<Downloads />} />
          <Route path="/" element={<AppLayout><Dashboard /></AppLayout>} />
          <Route path="/tab-groups" element={<AppLayout><TabGroups /></AppLayout>} />
          <Route path="/shortcuts" element={<AppLayout><Shortcuts /></AppLayout>} />
          <Route path="/passwords" element={<Passwords />} />
          <Route path="/settings" element={<AppLayout><Settings /></AppLayout>} />
          <Route path="/admin" element={<AdminDashboard />} />
          <Route path="/admin/users" element={<AdminUsers />} />
          <Route path="/admin/versions" element={<AdminVersions />} />
          <Route path="*" element={<NotFound />} />
        </Routes>
      )}
    </>
  );
}

const App = () => (
  <QueryClientProvider client={queryClient}>
    <AuthProvider>
      <ThemeProvider>
        <TooltipProvider>
          <ColorInitializer />
          <Toaster />
          <Sonner />
          <HashRouter>
            <AppRoutes />
            {/* Floating shortcuts button for mobile/tablet */}
            <FloatingShortcutsButton />
          </HashRouter>
        </TooltipProvider>
      </ThemeProvider>
    </AuthProvider>
  </QueryClientProvider>
);

export default App;
