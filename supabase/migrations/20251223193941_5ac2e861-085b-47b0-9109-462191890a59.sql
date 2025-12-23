-- Create profiles table for user data
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create tab_groups table
CREATE TABLE public.tab_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    icon TEXT DEFAULT 'folder',
    color TEXT DEFAULT '#6366f1',
    position INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create tabs table
CREATE TABLE public.tabs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    group_id UUID NOT NULL REFERENCES public.tab_groups(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    url TEXT NOT NULL,
    icon TEXT DEFAULT 'globe',
    color TEXT DEFAULT '#22d3ee',
    zoom INTEGER DEFAULT 100,
    position INTEGER NOT NULL DEFAULT 0,
    open_as_window BOOLEAN DEFAULT false,
    keyboard_shortcut TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create text_shortcuts table
CREATE TABLE public.text_shortcuts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    command TEXT NOT NULL,
    expanded_text TEXT NOT NULL,
    category TEXT DEFAULT 'geral',
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    UNIQUE(user_id, command)
);

-- Create split_layouts table
CREATE TABLE public.split_layouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    layout_type TEXT NOT NULL DEFAULT '50-50',
    panels JSONB NOT NULL DEFAULT '[]'::jsonb,
    is_favorite BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tab_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tabs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.text_shortcuts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.split_layouts ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view their own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own profile" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = user_id);

-- Tab groups policies
CREATE POLICY "Users can view their own tab groups" ON public.tab_groups
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own tab groups" ON public.tab_groups
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own tab groups" ON public.tab_groups
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own tab groups" ON public.tab_groups
    FOR DELETE USING (auth.uid() = user_id);

-- Tabs policies
CREATE POLICY "Users can view their own tabs" ON public.tabs
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own tabs" ON public.tabs
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own tabs" ON public.tabs
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own tabs" ON public.tabs
    FOR DELETE USING (auth.uid() = user_id);

-- Text shortcuts policies
CREATE POLICY "Users can view their own text shortcuts" ON public.text_shortcuts
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own text shortcuts" ON public.text_shortcuts
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own text shortcuts" ON public.text_shortcuts
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own text shortcuts" ON public.text_shortcuts
    FOR DELETE USING (auth.uid() = user_id);

-- Split layouts policies
CREATE POLICY "Users can view their own split layouts" ON public.split_layouts
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own split layouts" ON public.split_layouts
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own split layouts" ON public.split_layouts
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own split layouts" ON public.split_layouts
    FOR DELETE USING (auth.uid() = user_id);

-- Create function to update timestamps
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

-- Create triggers for automatic timestamp updates
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_tab_groups_updated_at
    BEFORE UPDATE ON public.tab_groups
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_tabs_updated_at
    BEFORE UPDATE ON public.tabs
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_text_shortcuts_updated_at
    BEFORE UPDATE ON public.text_shortcuts
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_split_layouts_updated_at
    BEFORE UPDATE ON public.split_layouts
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Create trigger to auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (user_id, full_name)
    VALUES (new.id, new.raw_user_meta_data ->> 'full_name');
    RETURN new;
END;
$$;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();