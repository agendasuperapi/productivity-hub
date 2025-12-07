import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/saved_tab.dart';
import '../services/saved_tabs_service.dart';

/// Dialog para salvar uma aba como favorito
class SaveTabDialog extends StatefulWidget {
  final String currentUrl;
  final String currentTitle;
  final SavedTab? existingTab; // Se fornecido, está editando uma aba existente

  const SaveTabDialog({
    super.key,
    required this.currentUrl,
    required this.currentTitle,
    this.existingTab,
  });

  @override
  State<SaveTabDialog> createState() => _SaveTabDialogState();
}

class _SaveTabDialogState extends State<SaveTabDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _savedTabsService = SavedTabsService();
  File? _iconFile;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.existingTab?.name ?? widget.currentTitle;
    _urlController.text = widget.existingTab?.url ?? widget.currentUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowedExtensions: ['png'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _iconFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _saveTab() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      SavedTab savedTab;
      if (widget.existingTab != null) {
        // Atualiza aba existente
        savedTab = await _savedTabsService.updateTab(
          id: widget.existingTab!.id!,
          name: _nameController.text.trim(),
          url: _urlController.text.trim(),
          iconFile: _iconFile,
        );
      } else {
        // Cria nova aba salva
        savedTab = await _savedTabsService.saveTab(
          name: _nameController.text.trim(),
          url: _urlController.text.trim(),
          iconFile: _iconFile,
        );
      }

      if (mounted) {
        // Retorna o SavedTab criado/atualizado
        Navigator.of(context).pop(savedTab);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingTab != null ? 'Editar Aba' : 'Salvar Aba'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, insira um nome';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'URL',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, insira uma URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickIcon,
                      icon: const Icon(Icons.image),
                      label: Text(_iconFile != null ? 'Ícone selecionado' : 'Selecionar Ícone (.png)'),
                    ),
                  ),
                  if (_iconFile != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _iconFile = null;
                        });
                      },
                    ),
                  ],
                ],
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[300]!),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveTab,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.existingTab != null ? 'Salvar' : 'Criar'),
        ),
      ],
    );
  }
}

