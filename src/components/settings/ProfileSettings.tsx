import { useState, useRef, useEffect } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Dialog, DialogContent } from '@/components/ui/dialog';
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle } from '@/components/ui/alert-dialog';
import { User, Loader2, Save, Pencil, X, Trash2 } from 'lucide-react';
import { useAuth } from '@/hooks/useAuth';
import { useToast } from '@/hooks/use-toast';
import { supabase } from '@/integrations/supabase/client';
import { ImageCropDialog } from '@/components/ui/image-crop-dialog';

interface ProfileData {
  full_name: string | null;
  avatar_url: string | null;
}

interface ProfileSettingsProps {
  profile: ProfileData | null;
  onProfileUpdate: (profile: ProfileData) => void;
}

export function ProfileSettings({ profile, onProfileUpdate }: ProfileSettingsProps) {
  const { user } = useAuth();
  const { toast } = useToast();
  const [fullName, setFullName] = useState(profile?.full_name || '');
  const [avatarUrl, setAvatarUrl] = useState(profile?.avatar_url || '');
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [cropDialogOpen, setCropDialogOpen] = useState(false);
  const [tempImageSrc, setTempImageSrc] = useState<string>('');
  const [previewOpen, setPreviewOpen] = useState(false);
  const [removeConfirmOpen, setRemoveConfirmOpen] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Sync state when profile prop changes (after async load)
  useEffect(() => {
    if (profile) {
      setFullName(profile.full_name || '');
      setAvatarUrl(profile.avatar_url || '');
    }
  }, [profile]);

  const getInitials = (name: string | null) => {
    if (!name) return user?.email?.charAt(0).toUpperCase() || 'U';
    return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2);
  };

  const handleSave = async () => {
    if (!user) return;
    
    setSaving(true);
    try {
      const { error } = await supabase
        .from('profiles')
        .update({ 
          full_name: fullName || null,
          avatar_url: avatarUrl || null,
        })
        .eq('user_id', user.id);

      if (error) throw error;

      onProfileUpdate({ full_name: fullName, avatar_url: avatarUrl });
      toast({ title: 'Perfil atualizado!' });
    } catch (error) {
      console.error('Error updating profile:', error);
      toast({ title: 'Erro ao atualizar perfil', variant: 'destructive' });
    } finally {
      setSaving(false);
    }
  };

  const handleAvatarClick = () => {
    // Open preview if there's an avatar
    if (avatarUrl) {
      setPreviewOpen(true);
    } else {
      // If no avatar, open file picker directly
      fileInputRef.current?.click();
    }
  };

  const handleEditClick = (e?: React.MouseEvent) => {
    e?.stopPropagation();
    fileInputRef.current?.click();
  };

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !user) return;

    // Reset input value to allow selecting the same file again
    e.target.value = '';

    // Validate file type
    if (!file.type.startsWith('image/')) {
      toast({ title: 'Por favor, selecione uma imagem', variant: 'destructive' });
      return;
    }

    // Validate file size (max 5MB for original, will be compressed after crop)
    if (file.size > 5 * 1024 * 1024) {
      toast({ title: 'A imagem deve ter no máximo 5MB', variant: 'destructive' });
      return;
    }

    // Read file and open crop dialog
    const reader = new FileReader();
    reader.onloadend = () => {
      const base64 = reader.result as string;
      setTempImageSrc(base64);
      setCropDialogOpen(true);
    };
    reader.onerror = () => {
      toast({ title: 'Erro ao ler arquivo', variant: 'destructive' });
    };
    reader.readAsDataURL(file);
  };

  const handleCropComplete = (croppedImage: string) => {
    setAvatarUrl(croppedImage);
    setTempImageSrc('');
    toast({ title: 'Foto ajustada com sucesso!' });
  };

  const hasChanges = fullName !== (profile?.full_name || '') || avatarUrl !== (profile?.avatar_url || '');

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <User className="h-5 w-5" />
          Perfil
        </CardTitle>
        <CardDescription>
          Gerencie suas informações pessoais
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-6">
        {/* Avatar */}
        <div className="flex items-center gap-4">
          <div className="relative">
            <Avatar className="h-20 w-20 cursor-pointer hover:opacity-80 transition-opacity" onClick={handleAvatarClick}>
              <AvatarImage src={avatarUrl || undefined} alt={fullName || 'Avatar'} />
              <AvatarFallback className="text-lg bg-primary text-primary-foreground">
                {getInitials(fullName)}
              </AvatarFallback>
            </Avatar>
            <button
              onClick={handleEditClick}
              className="absolute bottom-0 right-0 p-1.5 rounded-full bg-primary text-primary-foreground hover:bg-primary/90 transition-colors"
              disabled={uploading}
              title="Alterar foto"
            >
              {uploading ? (
                <Loader2 className="h-3 w-3 animate-spin" />
              ) : (
                <Pencil className="h-3 w-3" />
              )}
            </button>
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              className="hidden"
              onChange={handleFileChange}
            />
          </div>
          <div className="flex-1 space-y-1">
            <p className="text-sm text-muted-foreground">Foto de perfil</p>
            <p className="text-xs text-muted-foreground">
              Clique na foto para ampliar. Use o ícone para alterar.
            </p>
          </div>
        </div>

        {/* Full Name */}
        <div className="space-y-2">
          <Label htmlFor="full_name">Nome de exibição</Label>
          <Input
            id="full_name"
            placeholder="Seu nome completo"
            value={fullName}
            onChange={(e) => setFullName(e.target.value)}
          />
        </div>

        {/* Email (read-only) */}
        <div className="space-y-2">
          <Label>Email</Label>
          <p className="text-sm font-medium text-muted-foreground bg-muted/50 px-3 py-2 rounded-md">
            {user?.email}
          </p>
        </div>

        {/* Save Button */}
        {hasChanges && (
          <Button onClick={handleSave} disabled={saving} className="w-full">
            {saving ? (
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            ) : (
              <Save className="mr-2 h-4 w-4" />
            )}
            Salvar Alterações
          </Button>
        )}
      </CardContent>

      {/* Image Preview Dialog */}
      <Dialog open={previewOpen} onOpenChange={setPreviewOpen}>
        <DialogContent className="max-w-fit p-0 overflow-hidden bg-background/95 backdrop-blur-sm border-none">
          <div className="relative flex flex-col items-center justify-center p-6">
            {/* Close button */}
            <button
              onClick={() => setPreviewOpen(false)}
              className="absolute top-3 right-3 p-2 rounded-full bg-background/80 hover:bg-background transition-colors z-10"
            >
              <X className="h-5 w-5" />
            </button>

            {/* Large avatar image */}
            <div className="w-72 h-72 sm:w-80 sm:h-80 rounded-full overflow-hidden border-2 border-border/50 shadow-2xl">
              {avatarUrl ? (
                <img 
                  src={avatarUrl} 
                  alt={fullName || 'Avatar'} 
                  className="w-full h-full object-cover"
                />
              ) : (
                <div className="w-full h-full bg-primary flex items-center justify-center">
                  <span className="text-6xl font-semibold text-primary-foreground">
                    {getInitials(fullName)}
                  </span>
                </div>
              )}
            </div>

            {/* Name and email */}
            <div className="mt-4 text-center">
              {fullName && (
                <p className="text-lg font-medium text-foreground">{fullName}</p>
              )}
              {user?.email && (
                <p className="text-sm text-muted-foreground">{user.email}</p>
              )}
            </div>

            {/* Action buttons - centered below name */}
            <div className="mt-4 flex gap-3">
              {/* Remove photo button */}
              {avatarUrl && (
                <button
                  onClick={() => setRemoveConfirmOpen(true)}
                  className="p-3 rounded-full bg-destructive text-destructive-foreground hover:bg-destructive/90 transition-colors shadow-lg"
                  title="Remover foto"
                >
                  <Trash2 className="h-5 w-5" />
                </button>
              )}
              
              {/* Edit button */}
              <button
                onClick={() => {
                  setPreviewOpen(false);
                  handleEditClick();
                }}
                className="p-3 rounded-full bg-primary text-primary-foreground hover:bg-primary/90 transition-colors shadow-lg"
                title="Alterar foto"
              >
                <Pencil className="h-5 w-5" />
              </button>
            </div>
          </div>
        </DialogContent>
      </Dialog>

      {/* Remove Photo Confirmation Dialog */}
      <AlertDialog open={removeConfirmOpen} onOpenChange={setRemoveConfirmOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Remover foto de perfil?</AlertDialogTitle>
            <AlertDialogDescription>
              Tem certeza que deseja remover sua foto de perfil? Você precisará salvar as alterações para confirmar.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction
              onClick={() => {
                setAvatarUrl('');
                setPreviewOpen(false);
                toast({ title: 'Foto removida. Salve para confirmar.' });
              }}
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
            >
              Remover
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* Image Crop Dialog */}
      <ImageCropDialog
        open={cropDialogOpen}
        onOpenChange={setCropDialogOpen}
        imageSrc={tempImageSrc}
        onCropComplete={handleCropComplete}
        aspectRatio={1}
        circularCrop={true}
      />
    </Card>
  );
}
