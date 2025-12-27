import { useState, useEffect } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { Download, Monitor, Apple, Smartphone, CheckCircle2, Calendar, ArrowLeft } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { Link } from "react-router-dom";

interface Release {
  id: string;
  version: string;
  description: string;
  changes: string[];
  status: string;
  windows_url: string | null;
  macos_url: string | null;
  apk_url: string | null;
  deploy_completed_at: string | null;
  created_at: string;
}

interface ReleasesData {
  latest: Release | null;
  previous: Release[];
  total: number;
}

export default function Downloads() {
  const [releases, setReleases] = useState<ReleasesData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchReleases();
  }, []);

  const fetchReleases = async () => {
    try {
      setLoading(true);
      const { data, error: fetchError } = await supabase.functions.invoke('get-releases');
      
      if (fetchError) {
        throw fetchError;
      }

      setReleases(data);
    } catch (err: any) {
      console.error("Error fetching releases:", err);
      setError(err.message || "Erro ao carregar versões");
    } finally {
      setLoading(false);
    }
  };

  const formatDate = (dateString: string | null) => {
    if (!dateString) return "N/A";
    return new Date(dateString).toLocaleDateString('pt-BR', {
      day: '2-digit',
      month: 'long',
      year: 'numeric',
    });
  };

  const handleDownload = (url: string | null, platform: string) => {
    if (url) {
      window.open(url, '_blank');
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center space-y-4">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto"></div>
          <p className="text-muted-foreground">Carregando downloads...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <Card className="max-w-md w-full mx-4">
          <CardContent className="pt-6 text-center">
            <p className="text-destructive mb-4">{error}</p>
            <Button onClick={fetchReleases}>Tentar novamente</Button>
          </CardContent>
        </Card>
      </div>
    );
  }

  const latest = releases?.latest;

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b bg-card/50 backdrop-blur-sm sticky top-0 z-50">
        <div className="container mx-auto px-4 py-4 flex items-center justify-between">
          <div className="flex items-center gap-4">
            <Link to="/" className="text-muted-foreground hover:text-foreground transition-colors">
              <ArrowLeft className="h-5 w-5" />
            </Link>
            <div>
              <h1 className="text-xl font-bold">GerenciaZap</h1>
              <p className="text-sm text-muted-foreground">Downloads</p>
            </div>
          </div>
          {latest && (
            <Badge variant="secondary" className="text-sm">
              v{latest.version}
            </Badge>
          )}
        </div>
      </header>

      <main className="container mx-auto px-4 py-12">
        {!latest ? (
          <Card className="max-w-2xl mx-auto">
            <CardContent className="pt-6 text-center py-12">
              <Download className="h-16 w-16 mx-auto text-muted-foreground mb-4" />
              <h2 className="text-xl font-semibold mb-2">Nenhuma versão disponível</h2>
              <p className="text-muted-foreground">
                Ainda não há versões publicadas para download.
              </p>
            </CardContent>
          </Card>
        ) : (
          <>
            {/* Latest Release Hero */}
            <div className="max-w-4xl mx-auto mb-12">
              <div className="text-center mb-8">
                <Badge className="mb-4" variant="default">
                  Última versão
                </Badge>
                <h2 className="text-4xl font-bold mb-2">Versão {latest.version}</h2>
                <p className="text-xl text-muted-foreground mb-4">{latest.description}</p>
                <div className="flex items-center justify-center gap-2 text-sm text-muted-foreground">
                  <Calendar className="h-4 w-4" />
                  <span>Lançado em {formatDate(latest.deploy_completed_at || latest.created_at)}</span>
                </div>
              </div>

              {/* Download Buttons */}
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4 max-w-2xl mx-auto">
                <Button
                  size="lg"
                  className="h-20 flex flex-col gap-2"
                  disabled={!latest.windows_url}
                  onClick={() => handleDownload(latest.windows_url, 'windows')}
                >
                  <Monitor className="h-6 w-6" />
                  <span>Windows</span>
                  {!latest.windows_url && <span className="text-xs opacity-70">Em breve</span>}
                </Button>

                <Button
                  size="lg"
                  variant="outline"
                  className="h-20 flex flex-col gap-2"
                  disabled={!latest.macos_url}
                  onClick={() => handleDownload(latest.macos_url, 'macos')}
                >
                  <Apple className="h-6 w-6" />
                  <span>macOS</span>
                  {!latest.macos_url && <span className="text-xs opacity-70">Em breve</span>}
                </Button>

                <Button
                  size="lg"
                  variant="outline"
                  className="h-20 flex flex-col gap-2"
                  disabled={!latest.apk_url}
                  onClick={() => handleDownload(latest.apk_url, 'apk')}
                >
                  <Smartphone className="h-6 w-6" />
                  <span>Android</span>
                  {!latest.apk_url && <span className="text-xs opacity-70">Em breve</span>}
                </Button>
              </div>
            </div>

            {/* Changelog */}
            {latest.changes && latest.changes.length > 0 && (
              <Card className="max-w-2xl mx-auto mb-12">
                <CardHeader>
                  <CardTitle className="text-lg">Novidades nesta versão</CardTitle>
                </CardHeader>
                <CardContent>
                  <ul className="space-y-2">
                    {latest.changes.map((change, index) => (
                      <li key={index} className="flex items-start gap-2">
                        <CheckCircle2 className="h-5 w-5 text-primary shrink-0 mt-0.5" />
                        <span>{change}</span>
                      </li>
                    ))}
                  </ul>
                </CardContent>
              </Card>
            )}

            {/* Previous Releases */}
            {releases?.previous && releases.previous.length > 0 && (
              <div className="max-w-2xl mx-auto">
                <Separator className="my-8" />
                <h3 className="text-lg font-semibold mb-4">Versões anteriores</h3>
                <div className="space-y-4">
                  {releases.previous.map((release) => (
                    <Card key={release.id}>
                      <CardHeader className="pb-2">
                        <div className="flex items-center justify-between">
                          <CardTitle className="text-base">Versão {release.version}</CardTitle>
                          <span className="text-sm text-muted-foreground">
                            {formatDate(release.deploy_completed_at || release.created_at)}
                          </span>
                        </div>
                        <CardDescription>{release.description}</CardDescription>
                      </CardHeader>
                      <CardContent>
                        <div className="flex gap-2">
                          {release.windows_url && (
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => handleDownload(release.windows_url, 'windows')}
                            >
                              <Monitor className="h-4 w-4 mr-1" />
                              Windows
                            </Button>
                          )}
                          {release.macos_url && (
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => handleDownload(release.macos_url, 'macos')}
                            >
                              <Apple className="h-4 w-4 mr-1" />
                              macOS
                            </Button>
                          )}
                          {release.apk_url && (
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => handleDownload(release.apk_url, 'apk')}
                            >
                              <Smartphone className="h-4 w-4 mr-1" />
                              Android
                            </Button>
                          )}
                        </div>
                      </CardContent>
                    </Card>
                  ))}
                </div>
              </div>
            )}
          </>
        )}
      </main>

      {/* Footer */}
      <footer className="border-t mt-12">
        <div className="container mx-auto px-4 py-6 text-center text-sm text-muted-foreground">
          <p>© {new Date().getFullYear()} GerenciaZap. Todos os direitos reservados.</p>
        </div>
      </footer>
    </div>
  );
}
