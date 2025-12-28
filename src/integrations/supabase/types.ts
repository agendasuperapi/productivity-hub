export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.1"
  }
  public: {
    Tables: {
      app_versions: {
        Row: {
          apk_url: string | null
          changes: Json
          created_at: string | null
          created_by: string
          deploy_completed_at: string | null
          deploy_started_at: string | null
          description: string
          id: string
          macos_url: string | null
          status: string
          version: string
          windows_url: string | null
          workflow_run_id: string | null
        }
        Insert: {
          apk_url?: string | null
          changes?: Json
          created_at?: string | null
          created_by: string
          deploy_completed_at?: string | null
          deploy_started_at?: string | null
          description: string
          id?: string
          macos_url?: string | null
          status?: string
          version: string
          windows_url?: string | null
          workflow_run_id?: string | null
        }
        Update: {
          apk_url?: string | null
          changes?: Json
          created_at?: string | null
          created_by?: string
          deploy_completed_at?: string | null
          deploy_started_at?: string | null
          description?: string
          id?: string
          macos_url?: string | null
          status?: string
          version?: string
          windows_url?: string | null
          workflow_run_id?: string | null
        }
        Relationships: []
      }
      clipboard_domains: {
        Row: {
          created_at: string
          domain: string
          id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          domain: string
          id?: string
          user_id: string
        }
        Update: {
          created_at?: string
          domain?: string
          id?: string
          user_id?: string
        }
        Relationships: []
      }
      keywords: {
        Row: {
          created_at: string | null
          id: string
          key: string
          updated_at: string | null
          user_id: string
          value: string
        }
        Insert: {
          created_at?: string | null
          id?: string
          key: string
          updated_at?: string | null
          user_id: string
          value: string
        }
        Update: {
          created_at?: string | null
          id?: string
          key?: string
          updated_at?: string | null
          user_id?: string
          value?: string
        }
        Relationships: []
      }
      profiles: {
        Row: {
          avatar_url: string | null
          background_color: Json | null
          created_at: string
          full_name: string | null
          id: string
          primary_color: Json | null
          settings: Json | null
          theme_preference: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          avatar_url?: string | null
          background_color?: Json | null
          created_at?: string
          full_name?: string | null
          id?: string
          primary_color?: Json | null
          settings?: Json | null
          theme_preference?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          avatar_url?: string | null
          background_color?: Json | null
          created_at?: string
          full_name?: string | null
          id?: string
          primary_color?: Json | null
          settings?: Json | null
          theme_preference?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      saved_credentials: {
        Row: {
          created_at: string
          domain: string
          encrypted_password: string
          id: string
          site_name: string | null
          updated_at: string
          user_id: string
          username: string
        }
        Insert: {
          created_at?: string
          domain: string
          encrypted_password: string
          id?: string
          site_name?: string | null
          updated_at?: string
          user_id: string
          username: string
        }
        Update: {
          created_at?: string
          domain?: string
          encrypted_password?: string
          id?: string
          site_name?: string | null
          updated_at?: string
          user_id?: string
          username?: string
        }
        Relationships: []
      }
      split_layouts: {
        Row: {
          created_at: string
          id: string
          is_favorite: boolean | null
          layout_type: string
          name: string
          panels: Json
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          is_favorite?: boolean | null
          layout_type?: string
          name: string
          panels?: Json
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          is_favorite?: boolean | null
          layout_type?: string
          name?: string
          panels?: Json
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      tab_groups: {
        Row: {
          color: string | null
          created_at: string
          icon: string | null
          id: string
          name: string
          position: number
          updated_at: string
          user_id: string
        }
        Insert: {
          color?: string | null
          created_at?: string
          icon?: string | null
          id?: string
          name: string
          position?: number
          updated_at?: string
          user_id: string
        }
        Update: {
          color?: string | null
          created_at?: string
          icon?: string | null
          id?: string
          name?: string
          position?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      tabs: {
        Row: {
          color: string | null
          created_at: string
          group_id: string
          icon: string | null
          id: string
          keyboard_shortcut: string | null
          layout_type: string | null
          name: string
          open_as_window: boolean | null
          panel_sizes: Json | null
          position: number
          updated_at: string
          url: string
          urls: Json | null
          user_id: string
          window_height: number | null
          window_width: number | null
          window_x: number | null
          window_y: number | null
          zoom: number | null
        }
        Insert: {
          color?: string | null
          created_at?: string
          group_id: string
          icon?: string | null
          id?: string
          keyboard_shortcut?: string | null
          layout_type?: string | null
          name: string
          open_as_window?: boolean | null
          panel_sizes?: Json | null
          position?: number
          updated_at?: string
          url: string
          urls?: Json | null
          user_id: string
          window_height?: number | null
          window_width?: number | null
          window_x?: number | null
          window_y?: number | null
          zoom?: number | null
        }
        Update: {
          color?: string | null
          created_at?: string
          group_id?: string
          icon?: string | null
          id?: string
          keyboard_shortcut?: string | null
          layout_type?: string | null
          name?: string
          open_as_window?: boolean | null
          panel_sizes?: Json | null
          position?: number
          updated_at?: string
          url?: string
          urls?: Json | null
          user_id?: string
          window_height?: number | null
          window_width?: number | null
          window_x?: number | null
          window_y?: number | null
          zoom?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "tabs_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "tab_groups"
            referencedColumns: ["id"]
          },
        ]
      }
      text_shortcuts: {
        Row: {
          auto_send: boolean | null
          category: string | null
          command: string
          created_at: string
          description: string | null
          expanded_text: string
          id: string
          messages: Json | null
          updated_at: string
          user_id: string
        }
        Insert: {
          auto_send?: boolean | null
          category?: string | null
          command: string
          created_at?: string
          description?: string | null
          expanded_text: string
          id?: string
          messages?: Json | null
          updated_at?: string
          user_id: string
        }
        Update: {
          auto_send?: boolean | null
          category?: string | null
          command?: string
          created_at?: string
          description?: string | null
          expanded_text?: string
          id?: string
          messages?: Json | null
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      user_roles: {
        Row: {
          created_at: string | null
          id: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Insert: {
          created_at?: string | null
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Update: {
          created_at?: string | null
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      has_role: {
        Args: {
          _role: Database["public"]["Enums"]["app_role"]
          _user_id: string
        }
        Returns: boolean
      }
    }
    Enums: {
      app_role: "super_admin" | "admin" | "user"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      app_role: ["super_admin", "admin", "user"],
    },
  },
} as const
