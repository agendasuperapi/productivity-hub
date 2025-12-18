import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/keyword.dart';
import '../services/keywords_service.dart';
import '../widgets/draggable_resizable_dialog.dart';

/// Tela para gerenciar palavras-chave customizáveis
class KeywordsScreen extends StatefulWidget {
  const KeywordsScreen({super.key});

  @override
  State<KeywordsScreen> createState() => _KeywordsScreenState();
}

class _KeywordsScreenState extends State<KeywordsScreen> {
  final KeywordsService _service = KeywordsService();
  List<Keyword> _keywords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadKeywords();
  }

  Future<void> _loadKeywords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final keywords = await _service.getAllKeywords();
      if (mounted) {
        setState(() {
          _keywords = keywords;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar palavras-chave: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAddEditDialog({Keyword? keyword}) async {
    final keyController = TextEditingController(
      text: keyword?.key ?? '',
    );
    final valueController = TextEditingController(
      text: keyword?.value ?? '',
    );
    final formKey = GlobalKey<FormState>();

    // ✅ Detecta se é tela pequena (mobile)
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600 || screenSize.height < 800;

    // Função auxiliar para salvar palavra-chave
    Future<void> _saveKeyword(
      TextEditingController keyController,
      TextEditingController valueController,
      Keyword? keyword,
    ) async {
      final key = keyController.text.trim().toUpperCase();
      
      // Verifica se a chave já existe
      final exists = await _service.keyExists(
        key,
        excludeId: keyword?.id,
      );
      
      if (exists) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Chave já existe'),
            content: Text('A palavra-chave "$key" já está cadastrada!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
      
      if (keyword == null) {
        // Criar nova palavra-chave
        final newKeyword = Keyword(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          key: key,
          value: valueController.text.trim(),
          createdAt: DateTime.now(),
        );
        
        final saved = await _service.saveKeyword(newKeyword);
        if (saved != null && mounted) {
          Navigator.of(context).pop();
          _loadKeywords();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Palavra-chave salva com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Atualizar palavra-chave existente
        final updated = keyword.copyWith(
          key: key,
          value: valueController.text.trim(),
          updatedAt: DateTime.now(),
        );
        
        final saved = await _service.updateKeyword(updated);
        if (saved != null && mounted) {
          Navigator.of(context).pop();
          _loadKeywords();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Palavra-chave atualizada!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }

    // Widget do formulário (reutilizável)
    Widget buildFormContent({bool isDesktop = false}) {
      return SingleChildScrollView(
        child: Padding(
          // ✅ Padding superior maior em desktop para não sobrepor o título do DraggableResizableDialog
          padding: isDesktop 
              ? const EdgeInsets.fromLTRB(24, 50, 24, 24)
              : const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Campo Palavra-Chave
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Palavra-Chave',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: keyController,
                      decoration: InputDecoration(
                        hintText: 'Ex: PIX, NOME, TELEFONE',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF00a4a4), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      inputFormatters: [
                        // ✅ Permite letras, números e caracteres especiais (exceto < e >)
                        FilteringTextInputFormatter.allow(RegExp(r'[^<>]')),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Digite uma palavra-chave';
                        }
                        if (value.length > 20) {
                          return 'A palavra-chave não pode ter mais de 20 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Digite sem os símbolos < >. Exemplo: PIX (será usado como <PIX>)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                // Campo Valor
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Valor',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: valueController,
                      decoration: InputDecoration(
                        hintText: 'Ex: 123.456.789-00',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF00a4a4), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      maxLines: 4,
                      minLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Digite um valor';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Valor que será substituído quando usar <PALAVRA_CHAVE>',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Botões de ação
                isSmallScreen
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                await _saveKeyword(keyController, valueController, keyword);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00a4a4),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            child: Text(
                              keyword == null ? 'Salvar' : 'Atualizar',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                await _saveKeyword(keyController, valueController, keyword);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00a4a4),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            child: Text(
                              keyword == null ? 'Salvar' : 'Atualizar',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      );
    }

    if (isSmallScreen) {
      // ✅ Para telas pequenas, usa bottom sheet
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            height: screenSize.height * 0.9,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Barra de título
                Container(
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00a4a4),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 20),
                        child: Icon(Icons.tag, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          keyword == null ? 'Nova Palavra-Chave' : 'Editar Palavra-Chave',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 24),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Fechar',
                      ),
                    ],
                  ),
                ),
                // Conteúdo
                Expanded(
                  child: buildFormContent(),
                ),
              ],
            ),
          );
        },
      );
    } else {
      // ✅ Para telas grandes, usa diálogo normal
      await showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (context) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
            backgroundColor: Colors.transparent,
            child: DraggableResizableDialog(
              initialWidth: 550,
              initialHeight: 500,
              minWidth: 450,
              minHeight: 400,
              titleBar: Container(
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFF00a4a4),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 20),
                      child: Icon(Icons.tag, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        keyword == null ? 'Nova Palavra-Chave' : 'Editar Palavra-Chave',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 24),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Fechar',
                    ),
                  ],
                ),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: buildFormContent(isDesktop: true),
              ),
            ),
          );
        },
      );
    }
  }

  Future<void> _deleteKeyword(Keyword keyword) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir a palavra-chave "<${keyword.key}>"?'),
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
      final deleted = await _service.deleteKeyword(keyword.id);
      if (deleted && mounted) {
        _loadKeywords();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Palavra-chave excluída!'),
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
        title: const Text('Palavras-Chave'),
        backgroundColor: const Color(0xFF00a4a4),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Informação sobre palavras-chave
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue[50],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Palavras-Chave Customizáveis',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cadastre palavras-chave que serão substituídas automaticamente nas mensagens rápidas. '
                        'Exemplo: <PIX> será substituído pelo valor cadastrado. '
                        'A palavra-chave <SAUDACAO> é padrão do sistema e não precisa ser cadastrada.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[800],
                        ),
                      ),
                    ],
                  ),
                ),
                // Lista de palavras-chave
                Expanded(
                  child: _keywords.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.tag,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Nenhuma palavra-chave cadastrada',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Clique no botão + para adicionar uma nova',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _keywords.length,
                          itemBuilder: (context, index) {
                            final keyword = _keywords[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF00a4a4),
                                  child: Text(
                                    keyword.key[0],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  '<${keyword.key}>',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(keyword.value),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _showAddEditDialog(keyword: keyword),
                                      tooltip: 'Editar',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteKeyword(keyword),
                                      tooltip: 'Excluir',
                                    ),
                                  ],
                                ),
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
}

