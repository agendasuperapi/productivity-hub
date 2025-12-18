import 'package:flutter/foundation.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:flutter/services.dart';
import '../models/saved_tab.dart';
import '../services/saved_tabs_service.dart';
import 'dart:async';

/// Serviço para gerenciar atalhos de teclado globais para abrir abas/janelas
class KeyboardShortcutsService {
  final SavedTabsService _savedTabsService = SavedTabsService();
  final Map<String, HotKey> _registeredHotKeys = {};
  final Map<String, SavedTab> _hotKeyToTab = {};
  Function(SavedTab)? onTabShortcutPressed;

  /// ✅ Inicializa o serviço e registra todos os atalhos das abas
  Future<void> initialize({Function(SavedTab)? onTabShortcutPressed}) async {
    this.onTabShortcutPressed = onTabShortcutPressed;
    await _registerAllShortcuts();
  }

  /// ✅ Registra todos os atalhos das abas salvas
  Future<void> _registerAllShortcuts() async {
    try {
      // Remove todos os atalhos anteriores
      await unregisterAllShortcuts();

      // Carrega todas as abas
      final tabs = await _savedTabsService.getSavedTabs();
      
      for (final tab in tabs) {
        if (tab.keyboardShortcut != null && tab.keyboardShortcut!.isNotEmpty) {
          await _registerShortcut(tab);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao registrar atalhos: $e');
    }
  }

  /// ✅ Registra um atalho para uma aba
  Future<void> _registerShortcut(SavedTab tab) async {
    try {
      final shortcut = tab.keyboardShortcut!;
      final hotKey = _parseShortcut(shortcut);
      
      if (hotKey != null) {
        // Remove atalho anterior se existir
        if (_registeredHotKeys.containsKey(tab.id)) {
          await hotKeyManager.unregister(_registeredHotKeys[tab.id]!);
        }

        // Registra novo atalho
        await hotKeyManager.register(
          hotKey,
          keyDownHandler: (hotKey) {
            debugPrint('🔑 Atalho pressionado: ${hotKey.toString()} para aba: ${tab.name}');
            onTabShortcutPressed?.call(tab);
          },
        );

        _registeredHotKeys[tab.id!] = hotKey;
        _hotKeyToTab[shortcut] = tab;
        debugPrint('✅ Atalho registrado: $shortcut para aba: ${tab.name}');
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao registrar atalho ${tab.keyboardShortcut} para aba ${tab.name}: $e');
    }
  }

  /// ✅ Remove um atalho
  Future<void> unregisterShortcut(String tabId) async {
    if (_registeredHotKeys.containsKey(tabId)) {
      try {
        await hotKeyManager.unregister(_registeredHotKeys[tabId]!);
        final shortcut = _registeredHotKeys[tabId]!.toString();
        _registeredHotKeys.remove(tabId);
        _hotKeyToTab.remove(shortcut);
        debugPrint('✅ Atalho removido para aba: $tabId');
      } catch (e) {
        debugPrint('⚠️ Erro ao remover atalho: $e');
      }
    }
  }

  /// ✅ Remove todos os atalhos
  Future<void> unregisterAllShortcuts() async {
    for (final hotKey in _registeredHotKeys.values) {
      try {
        await hotKeyManager.unregister(hotKey);
      } catch (e) {
        debugPrint('⚠️ Erro ao remover atalho: $e');
      }
    }
    _registeredHotKeys.clear();
    _hotKeyToTab.clear();
  }

  /// ✅ Recarrega todos os atalhos (útil quando uma aba é salva/atualizada)
  Future<void> reloadShortcuts() async {
    await _registerAllShortcuts();
  }

  /// ✅ Converte string de atalho (ex: "Ctrl+M", "F3") para HotKey
  HotKey? _parseShortcut(String shortcut) {
    try {
      final parts = shortcut.toUpperCase().split('+');
      List<HotKeyModifier> modifiers = [];
      PhysicalKeyboardKey? key;

      // Processa modificadores
      for (var part in parts) {
        part = part.trim();
        if (part == 'CTRL') {
          modifiers.add(HotKeyModifier.control);
        } else if (part == 'ALT') {
          modifiers.add(HotKeyModifier.alt);
        } else if (part == 'SHIFT') {
          modifiers.add(HotKeyModifier.shift);
        } else {
          // É a tecla principal
          key = _parseKeyCode(part);
        }
      }

      if (key == null) {
        debugPrint('⚠️ Não foi possível identificar a tecla principal em: $shortcut');
        return null;
      }

      return HotKey(
        key: key,
        modifiers: modifiers,
      );
    } catch (e) {
      debugPrint('⚠️ Erro ao fazer parse do atalho $shortcut: $e');
      return null;
    }
  }

  /// ✅ Converte string para PhysicalKeyboardKey
  PhysicalKeyboardKey? _parseKeyCode(String key) {
    // Mapa de conversão direto usando PhysicalKeyboardKey
    final keyMap = {
      // Teclas de função
      'F1': PhysicalKeyboardKey.f1, 'F2': PhysicalKeyboardKey.f2, 'F3': PhysicalKeyboardKey.f3, 'F4': PhysicalKeyboardKey.f4,
      'F5': PhysicalKeyboardKey.f5, 'F6': PhysicalKeyboardKey.f6, 'F7': PhysicalKeyboardKey.f7, 'F8': PhysicalKeyboardKey.f8,
      'F9': PhysicalKeyboardKey.f9, 'F10': PhysicalKeyboardKey.f10, 'F11': PhysicalKeyboardKey.f11, 'F12': PhysicalKeyboardKey.f12,
      // Letras
      'A': PhysicalKeyboardKey.keyA, 'B': PhysicalKeyboardKey.keyB, 'C': PhysicalKeyboardKey.keyC, 'D': PhysicalKeyboardKey.keyD,
      'E': PhysicalKeyboardKey.keyE, 'F': PhysicalKeyboardKey.keyF, 'G': PhysicalKeyboardKey.keyG, 'H': PhysicalKeyboardKey.keyH,
      'I': PhysicalKeyboardKey.keyI, 'J': PhysicalKeyboardKey.keyJ, 'K': PhysicalKeyboardKey.keyK, 'L': PhysicalKeyboardKey.keyL,
      'M': PhysicalKeyboardKey.keyM, 'N': PhysicalKeyboardKey.keyN, 'O': PhysicalKeyboardKey.keyO, 'P': PhysicalKeyboardKey.keyP,
      'Q': PhysicalKeyboardKey.keyQ, 'R': PhysicalKeyboardKey.keyR, 'S': PhysicalKeyboardKey.keyS, 'T': PhysicalKeyboardKey.keyT,
      'U': PhysicalKeyboardKey.keyU, 'V': PhysicalKeyboardKey.keyV, 'W': PhysicalKeyboardKey.keyW, 'X': PhysicalKeyboardKey.keyX,
      'Y': PhysicalKeyboardKey.keyY, 'Z': PhysicalKeyboardKey.keyZ,
      // Números
      '0': PhysicalKeyboardKey.digit0, '1': PhysicalKeyboardKey.digit1, '2': PhysicalKeyboardKey.digit2, '3': PhysicalKeyboardKey.digit3,
      '4': PhysicalKeyboardKey.digit4, '5': PhysicalKeyboardKey.digit5, '6': PhysicalKeyboardKey.digit6, '7': PhysicalKeyboardKey.digit7,
      '8': PhysicalKeyboardKey.digit8, '9': PhysicalKeyboardKey.digit9,
    };

    final upperKey = key.toUpperCase();
    return keyMap[upperKey];
  }

  /// ✅ Limpa recursos
  Future<void> dispose() async {
    await unregisterAllShortcuts();
  }
}

