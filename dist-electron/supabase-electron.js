import { createClient } from '@supabase/supabase-js';
import Store from 'electron-store';
// Storage adapter para Electron usando electron-store
class ElectronStorage {
    constructor() {
        this.store = new Store({
            name: 'supabase-auth',
            encryptionKey: 'supabase-auth-key',
        });
    }
    getItem(key) {
        const value = this.store.get(key);
        return value ?? null;
    }
    setItem(key, value) {
        this.store.set(key, value);
    }
    removeItem(key) {
        this.store.delete(key);
    }
}
const SUPABASE_URL = 'https://jegjrvglrjnhukxqkxoj.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImplZ2pydmdscmpuaHVreHFreG9qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY1MTA4NTAsImV4cCI6MjA4MjA4Njg1MH0.mhrSxMboDPKan4ez71_f5qjwUhxGMCq61GXvuTo93MU';
const storage = new ElectronStorage();
export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: {
        storage: {
            getItem: (key) => storage.getItem(key),
            setItem: (key, value) => storage.setItem(key, value),
            removeItem: (key) => storage.removeItem(key),
        },
        persistSession: true,
        autoRefreshToken: true,
    },
});
const API_URL = 'https://jegjrvglrjnhukxqkxoj.supabase.co/functions/v1/get-user-config';
export async function fetchUserConfig() {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session?.access_token) {
        throw new Error('Usuário não autenticado');
    }
    const response = await fetch(API_URL, {
        method: 'GET',
        headers: {
            'Authorization': `Bearer ${session.access_token}`,
            'Content-Type': 'application/json',
        },
    });
    if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Erro ao buscar configurações');
    }
    return await response.json();
}
