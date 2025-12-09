import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/quick_message.dart';
import '../services/quick_messages_service.dart';

/// Tela para gerenciar mensagens rápidas
class QuickMessagesScreen extends StatefulWidget {
  const QuickMessagesScreen({super.key});

  @override
  State<QuickMessagesScreen> createState() => _QuickMessagesScreenState();
}

class _QuickMessagesScreenState extends State<QuickMessagesScreen> {
  final QuickMessagesService _service = QuickMessagesService();
  List<QuickMessage> _messages = [];
  bool _isLoading = true;
  String _activationKey = '/'; // Tecla de ativação padrão

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });
    final messages = await _service.getAllMessages();
    setState(() {
      _messages = messages;
      _isLoading = false;
    });
  }

  Future<void> _showAddEditDialog({QuickMessage? message}) async {
    final titleController = TextEditingController(text: message?.title ?? '');
    final messageController = TextEditingController(text: message?.message ?? '');
    final shortcutController = TextEditingController(text: message?.shortcut ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(message == null ? 'Nova Mensagem Rápida' : 'Editar Mensagem Rápida'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    hintText: 'Ex: Obrigado',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Digite um título';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: shortcutController,
                  decoration: InputDecoration(
                    labelText: 'Atalho',
                    hintText: 'Ex: obr',
                    helperText: 'Digite sem espaços ou caracteres especiais',
                    border: const OutlineInputBorder(),
                    prefixText: '$_activationKey',
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Digite um atalho';
                    }
                    if (value.contains(' ')) {
                      return 'O atalho não pode conter espaços';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Mensagem',
                    hintText: 'Digite a mensagem que será inserida',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Digite uma mensagem';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final shortcut = shortcutController.text.toLowerCase();
                
                // Verifica se o atalho já existe (exceto se estiver editando)
                final exists = await _service.shortcutExists(
                  shortcut,
                  excludeId: message?.id,
                );
                
                if (exists) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Este atalho já está em uso'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (!mounted) return;
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                if (message == null) {
                  // Criar nova mensagem
                  final newMessage = QuickMessage(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleController.text,
                    message: messageController.text,
                    shortcut: shortcut,
                    createdAt: DateTime.now(),
                  );
                  
                  final saved = await _service.saveMessage(newMessage);
                  if (saved != null && mounted) {
                    navigator.pop();
                    _loadMessages();
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Mensagem rápida salva com sucesso!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  // Atualizar mensagem existente
                  final updated = message.copyWith(
                    title: titleController.text,
                    message: messageController.text,
                    shortcut: shortcut,
                  );
                  
                  final saved = await _service.updateMessage(updated);
                  if (saved != null && mounted) {
                    navigator.pop();
                    _loadMessages();
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Mensagem rápida atualizada!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              }
            },
            child: Text(message == null ? 'Salvar' : 'Atualizar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(QuickMessage message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir a mensagem "${message.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final deleted = await _service.deleteMessage(message.id);
      if (deleted && mounted) {
        _loadMessages();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mensagem rápida excluída!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensagens Rápidas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configurar tecla de ativação',
            onPressed: () => _showActivationKeyDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Informação sobre como usar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue[50],
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Digite "$_activationKey" + atalho em qualquer campo de texto para inserir a mensagem rapidamente.',
                          style: TextStyle(color: Colors.blue[900]),
                        ),
                      ),
                    ],
                  ),
                ),
                // Lista de mensagens
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.message_outlined,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'Nenhuma mensagem rápida cadastrada',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue,
                                  child: Text(
                                    message.shortcut[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(message.title),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      'Atalho: $_activationKey${message.shortcut}',
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      message.message,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _showAddEditDialog(message: message),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteMessage(message),
                                    ),
                                  ],
                                ),
                                onTap: () => _showAddEditDialog(message: message),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showActivationKeyDialog() async {
    final controller = TextEditingController(text: _activationKey);
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tecla de Ativação'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Escolha a tecla que ativará os atalhos:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLength: 1,
              decoration: const InputDecoration(
                labelText: 'Tecla',
                hintText: 'Ex: /',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _activationKey = controller.text;
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Tecla de ativação alterada para ${controller.text}'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

