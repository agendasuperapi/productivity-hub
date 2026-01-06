import { useState, useRef } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { User, Loader2, Camera, Save } from 'lucide-react';
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
  const fileInputRef = useRef<HTMLInputElement>(null);

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
            <Avatar className="h-20 w-20 cursor-pointer" onClick={handleAvatarClick}>
              <AvatarImage src={avatarUrl || undefined} alt={fullName || 'Avatar'} />
              <AvatarFallback className="text-lg bg-primary text-primary-foreground">
                {getInitials(fullName)}
              </AvatarFallback>
            </Avatar>
            <button
              onClick={handleAvatarClick}
              className="absolute bottom-0 right-0 p-1.5 rounded-full bg-primary text-primary-foreground hover:bg-primary/90 transition-colors"
              disabled={uploading}
            >
              {uploading ? (
                <Loader2 className="h-3 w-3 animate-spin" />
              ) : (
                <Camera className="h-3 w-3" />
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
              Clique para alterar. Formatos: JPG, PNG. Máximo: 2MB
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
