import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import { AuthProvider } from "@/hooks/useAuth";
import { ThemeProvider } from "@/hooks/useTheme";
import { AppLayout } from "@/components/layout/AppLayout";
import { ColorInitializer } from "@/components/ColorInitializer";
import Dashboard from "./pages/Dashboard";
import Auth from "./pages/Auth";
import TabGroups from "./pages/TabGroups";
import Shortcuts from "./pages/Shortcuts";
import Layouts from "./pages/Layouts";
import Settings from "./pages/Settings";
import Browser from "./pages/Browser";
import NotFound from "./pages/NotFound";

const queryClient = new QueryClient();

const App = () => (
  <QueryClientProvider client={queryClient}>
    <AuthProvider>
      <ThemeProvider>
        <TooltipProvider>
          <ColorInitializer />
          <Toaster />
          <Sonner />
          <BrowserRouter>
            <Routes>
              <Route path="/auth" element={<Auth />} />
              <Route path="/" element={<AppLayout><Dashboard /></AppLayout>} />
              <Route path="/tab-groups" element={<AppLayout><TabGroups /></AppLayout>} />
              <Route path="/shortcuts" element={<AppLayout><Shortcuts /></AppLayout>} />
              <Route path="/layouts" element={<AppLayout><Layouts /></AppLayout>} />
              <Route path="/settings" element={<AppLayout><Settings /></AppLayout>} />
              <Route path="/browser" element={<AppLayout><Browser /></AppLayout>} />
              <Route path="*" element={<NotFound />} />
            </Routes>
          </BrowserRouter>
        </TooltipProvider>
      </ThemeProvider>
    </AuthProvider>
  </QueryClientProvider>
);

export default App;
