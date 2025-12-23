"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.supabase = void 0;
exports.fetchUserConfig = fetchUserConfig;
const supabase_js_1 = require("@supabase/supabase-js");
const electron_store_1 = __importDefault(require("electron-store"));
// Storage adapter para Electron usando electron-store
class ElectronStorage {
    constructor() {
        this.store = new electron_store_1.default({
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
exports.supabase = (0, supabase_js_1.createClient)(SUPABASE_URL, SUPABASE_ANON_KEY, {
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
async function fetchUserConfig() {
    const { data: { session } } = await exports.supabase.auth.getSession();
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
        const error = await response.json();
        throw new Error(error.error || 'Erro ao buscar configurações');
    }
    return await response.json();
}
