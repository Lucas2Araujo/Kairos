import 'package:flutter/material.dart';
import '../../../data/repositories/comparativo_repository.dart';

class HymnComparativoDialog extends StatefulWidget {
  final String numero;
  final String titulo;
  final bool isNovo;

  const HymnComparativoDialog({
    super.key,
    required this.numero,
    required this.titulo,
    this.isNovo = true,
  });

  static Future<void> show(
    BuildContext context, {
    required String numero,
    required String titulo,
    bool isNovo = true,
  }) async {
    await showDialog(
      context: context,
      builder: (_) => HymnComparativoDialog(
        numero: numero,
        titulo: titulo,
        isNovo: isNovo,
      ),
    );
  }

  @override
  State<HymnComparativoDialog> createState() => _HymnComparativoDialogState();
}

class _HymnComparativoDialogState extends State<HymnComparativoDialog> {
  final ComparativoRepository _repository = ComparativoRepository();
  ComparativoItem? _item;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadComparativo();
  }

  Future<void> _loadComparativo() async {
    try {
      final res = await _repository.getByNumero(widget.numero, isNovo: widget.isNovo);
      if (mounted) {
        setState(() {
          _item = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar comparativo: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho
              Row(
                children: [
                  Icon(Icons.compare, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Comparativo Hinário (HA1996 vs HA2022)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),

              // Conteúdo
              Expanded(child: _buildBody(theme)),

              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fechar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }

    final item = _item;
    if (item == null) {
      return const Center(
        child: Text(
          'Este hino é novo ou não possui correspondência direta catalogada na outra edição.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner de Status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: item.modificado
                  ? Colors.amber.withValues(alpha: 0.15)
                  : Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: item.modificado
                    ? Colors.amber.withValues(alpha: 0.4)
                    : Colors.green.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  item.modificado ? Icons.difference : Icons.check_circle_outline,
                  color: item.modificado ? Colors.amber[800] : Colors.green,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status: ${item.statusComparacao} • Similaridade: ${item.similaridadePct.toStringAsFixed(1)}%',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (item.resumoAlteracoes != null && item.resumoAlteracoes!.isNotEmpty)
                        Text(
                          item.resumoAlteracoes!,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tabela Lado a Lado de Metadados
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edição Antiga (1996)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text('Número: #${item.numeroAntigo}'),
                        Text('Título: ${item.tituloAntigo}'),
                        if (item.categoriaAntiga.isNotEmpty)
                          Text('Categoria: ${item.categoriaAntiga}'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edição Nova (2022)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text('Número: #${item.numeroNovo}'),
                        Text('Título: ${item.tituloNovo}'),
                        if (item.categoriaNova.isNotEmpty)
                          Text('Categoria: ${item.categoriaNova}'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Destaque de alterações textuais (Diff)
          if (item.diffTexto != null && item.diffTexto!.isNotEmpty) ...[
            Text(
              'Diferenças Textuais da Letra:',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                item.diffTexto!,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
