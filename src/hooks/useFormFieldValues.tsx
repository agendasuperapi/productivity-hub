import { useState, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { toast } from 'sonner';

export interface FormFieldValue {
  id: string;
  user_id: string;
  domain: string;
  field_identifier: string;
  field_label: string | null;
  field_value: string;
  use_count: number;
  created_at: string;
  updated_at: string;
}

export function useFormFieldValues() {
  const { user } = useAuth();
  const [loading, setLoading] = useState(false);

  // Buscar todos os valores salvos para um domínio
  const getValuesForDomain = useCallback(async (domain: string): Promise<FormFieldValue[]> => {
    if (!user) return [];

    const { data, error } = await supabase
      .from('form_field_values')
      .select('*')
      .eq('user_id', user.id)
      .eq('domain', domain)
      .order('use_count', { ascending: false });

    if (error) {
      console.error('[FormFieldValues] Erro ao buscar valores:', error);
      return [];
    }

    return data || [];
  }, [user]);

  // Buscar valores para um campo específico em um domínio
  const getValuesForField = useCallback(async (domain: string, fieldIdentifier: string): Promise<FormFieldValue[]> => {
    if (!user) return [];

    const { data, error } = await supabase
      .from('form_field_values')
      .select('*')
      .eq('user_id', user.id)
      .eq('domain', domain)
      .eq('field_identifier', fieldIdentifier)
      .order('use_count', { ascending: false });

    if (error) {
      console.error('[FormFieldValues] Erro ao buscar valores para campo:', error);
      return [];
    }

    return data || [];
  }, [user]);

  // Salvar novo valor ou incrementar use_count se existir
  const saveFieldValue = useCallback(async (
    domain: string,
    fieldIdentifier: string,
    fieldValue: string,
    fieldLabel?: string
  ): Promise<boolean> => {
    if (!user || !fieldValue.trim()) return false;

    setLoading(true);
    try {
      // Verificar se já existe
      const { data: existing } = await supabase
        .from('form_field_values')
        .select('id, use_count')
        .eq('user_id', user.id)
        .eq('domain', domain)
        .eq('field_identifier', fieldIdentifier)
        .eq('field_value', fieldValue)
        .single();

      if (existing) {
        // Incrementar use_count
        const { error } = await supabase
          .from('form_field_values')
          .update({ use_count: existing.use_count + 1 })
          .eq('id', existing.id);

        if (error) throw error;
      } else {
        // Inserir novo
        const { error } = await supabase
          .from('form_field_values')
          .insert({
            user_id: user.id,
            domain,
            field_identifier: fieldIdentifier,
            field_value: fieldValue,
            field_label: fieldLabel || null,
            use_count: 1
          });

        if (error) throw error;
      }

      return true;
    } catch (error) {
      console.error('[FormFieldValues] Erro ao salvar:', error);
      toast.error('Erro ao salvar valor do campo');
      return false;
    } finally {
      setLoading(false);
    }
  }, [user]);

  // Deletar um valor
  const deleteFieldValue = useCallback(async (id: string): Promise<boolean> => {
    if (!user) return false;

    setLoading(true);
    try {
      const { error } = await supabase
        .from('form_field_values')
        .delete()
        .eq('id', id)
        .eq('user_id', user.id);

      if (error) throw error;
      return true;
    } catch (error) {
      console.error('[FormFieldValues] Erro ao deletar:', error);
      toast.error('Erro ao deletar valor');
      return false;
    } finally {
      setLoading(false);
    }
  }, [user]);

  // Atualizar um valor
  const updateFieldValue = useCallback(async (
    id: string,
    newValue: string,
    newLabel?: string
  ): Promise<boolean> => {
    if (!user) return false;

    setLoading(true);
    try {
      const updates: any = { field_value: newValue };
      if (newLabel !== undefined) updates.field_label = newLabel;

      const { error } = await supabase
        .from('form_field_values')
        .update(updates)
        .eq('id', id)
        .eq('user_id', user.id);

      if (error) throw error;
      return true;
    } catch (error) {
      console.error('[FormFieldValues] Erro ao atualizar:', error);
      toast.error('Erro ao atualizar valor');
      return false;
    } finally {
      setLoading(false);
    }
  }, [user]);

  // Buscar todos os valores agrupados por domínio
  const getAllGroupedByDomain = useCallback(async (): Promise<Record<string, FormFieldValue[]>> => {
    if (!user) return {};

    const { data, error } = await supabase
      .from('form_field_values')
      .select('*')
      .eq('user_id', user.id)
      .order('domain')
      .order('use_count', { ascending: false });

    if (error) {
      console.error('[FormFieldValues] Erro ao buscar todos:', error);
      return {};
    }

    // Agrupar por domínio
    const grouped: Record<string, FormFieldValue[]> = {};
    (data || []).forEach(item => {
      if (!grouped[item.domain]) {
        grouped[item.domain] = [];
      }
      grouped[item.domain].push(item);
    });

    return grouped;
  }, [user]);

  return {
    loading,
    getValuesForDomain,
    getValuesForField,
    saveFieldValue,
    deleteFieldValue,
    updateFieldValue,
    getAllGroupedByDomain
  };
}
