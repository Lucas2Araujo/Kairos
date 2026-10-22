import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;
import '../../core/constants/app_constants.dart';
import '../../core/database/database_manager.dart';
import '../../models/sabbath_school_models.dart';
import '../../services/theme_service.dart';

/// Nó individual do mapa mental
class MindMapNode {
  final String id;
  String? parentId;
  String text;
  Offset position;

  MindMapNode({
    required this.id,
    this.parentId,
    required this.text,
    required this.position,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'parentId': parentId,
    'text': text,
    'x': position.dx,
    'y': position.dy,
  };

  factory MindMapNode.fromJson(Map<String, dynamic> json) {
    return MindMapNode(
      id: json['id'] as String,
      parentId: json['parentId'] as String?,
      text: (json['text'] ?? '').toString(),
      position: Offset(
        (json['x'] as num?)?.toDouble() ?? 1400.0,
        (json['y'] as num?)?.toDouble() ?? 1450.0,
      ),
    );
  }
}

/// Painter com curvas de Bézier cúbicas conectando nós pais aos nós filhos
class MindMapConnectionsPainter extends CustomPainter {
  final List<MindMapNode> nodes;
  final Color lineColor;

  MindMapConnectionsPainter({
    required this.nodes,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final nodeMap = {for (final n in nodes) n.id: n};

    for (final node in nodes) {
      if (node.parentId == null) continue;
      final parent = nodeMap[node.parentId];
      if (parent == null) continue;

      final isRight = node.position.dx >= parent.position.dx;
      // Âncoras laterais calculadas a partir da posição dos cartões
      final p1 = Offset(
        isRight ? parent.position.dx + 160 : parent.position.dx,
        parent.position.dy + 26,
      );
      final p2 = Offset(
        isRight ? node.position.dx : node.position.dx + 160,
        node.position.dy + 26,
      );

      final path = Path();
      path.moveTo(p1.dx, p1.dy);

      final dx = (p2.dx - p1.dx).abs() * 0.5;
      final cp1 = Offset(p1.dx + (isRight ? dx : -dx), p1.dy);
      final cp2 = Offset(p2.dx - (isRight ? dx : -dx), p2.dy);

      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant MindMapConnectionsPainter oldDelegate) => true;
}

/// Estúdio interativo de Mapa Mental para a Lição da Escola Sabatina
class MindMapStudioView extends StatefulWidget {
  final SSDay day;
  final CommonDatabase? db;

  const MindMapStudioView({
    super.key,
    required this.day,
    this.db,
  });

  @override
  State<MindMapStudioView> createState() => _MindMapStudioViewState();
}

class _MindMapStudioViewState extends State<MindMapStudioView> {
  static const double canvasSize = 3000.0;
  static const Offset rootInitPos = Offset(1400.0, 1450.0);

  final TransformationController _transController = TransformationController();
  CommonDatabase? _db;
  List<MindMapNode> _nodes = [];
  bool _isLoading = true;
  bool _hasCentered = false;

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  @override
  void dispose() {
    _transController.dispose();
    super.dispose();
  }

  Future<void> _initAndLoad() async {
    try {
      _db = widget.db ?? await DatabaseManager().getDatabase(AppConstants.dbHymns);
      _ensureTable();
      _loadMap();
    } catch (e) {
      debugPrint('[MindMapStudio] Erro de inicialização: $e');
      _initDefaultNodes();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _ensureTable() {
    _db?.execute('''
      CREATE TABLE IF NOT EXISTS ss_mind_maps (
        day_id TEXT PRIMARY KEY,
        root_word TEXT NOT NULL,
        nodes_json TEXT NOT NULL,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    ''');
  }

  void _initDefaultNodes() {
    final rootTitle = widget.day.title.trim().isNotEmpty ? widget.day.title.trim() : 'Lição do Dia';
    _nodes = [
      MindMapNode(
        id: 'root',
        parentId: null,
        text: rootTitle,
        position: rootInitPos,
      ),
      MindMapNode(
        id: 'child_1',
        parentId: 'root',
        text: 'Ponto Principal',
        position: rootInitPos + const Offset(230, -50),
      ),
      MindMapNode(
        id: 'child_2',
        parentId: 'root',
        text: 'Aplicação Prática',
        position: rootInitPos + const Offset(230, 60),
      ),
    ];
  }

  void _loadMap() {
    if (_db == null) {
      _initDefaultNodes();
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final rows = _db!.select(
        'SELECT root_word, nodes_json FROM ss_mind_maps WHERE day_id = ? LIMIT 1;',
        [widget.day.id],
      );

      if (rows.isNotEmpty) {
        final jsonStr = rows.first['nodes_json'] as String;
        final decoded = jsonDecode(jsonStr);
        if (decoded is List && decoded.isNotEmpty) {
          _nodes = decoded
              .map((item) => MindMapNode.fromJson(item as Map<String, dynamic>))
              .toList();
        } else {
          _initDefaultNodes();
        }
      } else {
        _initDefaultNodes();
      }
    } catch (e) {
      debugPrint('[MindMapStudio] Erro ao carregar mapa mental: $e');
      _initDefaultNodes();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _saveMap({bool showFeedback = false}) {
    if (_nodes.isEmpty || _db == null) return;
    try {
      _ensureTable();
      final rootNode = _nodes.firstWhere((n) => n.parentId == null, orElse: () => _nodes.first);
      final jsonStr = jsonEncode(_nodes.map((n) => n.toJson()).toList());

      _db!.execute('''
        INSERT INTO ss_mind_maps (day_id, root_word, nodes_json, updated_at)
        VALUES (?, ?, ?, CURRENT_TIMESTAMP)
        ON CONFLICT(day_id) DO UPDATE SET
          root_word = excluded.root_word,
          nodes_json = excluded.nodes_json,
          updated_at = CURRENT_TIMESTAMP;
      ''', [widget.day.id, rootNode.text, jsonStr]);

      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mapa mental salvo com sucesso!')),
        );
      }
    } catch (e) {
      debugPrint('[MindMapStudio] Erro ao salvar mapa mental: $e');
    }
  }

  void _centerView(Size screenSize) {
    final root = _nodes.firstWhere((n) => n.parentId == null, orElse: () => _nodes.first);
    final targetX = root.position.dx + 80;
    final targetY = root.position.dy + 30;

    final tx = -(targetX - screenSize.width / 2);
    final ty = -(targetY - screenSize.height / 2);

    _transController.value = Matrix4.identity()
      ..setTranslationRaw(tx, ty, 0.0);
  }

  void _addNode(MindMapNode parent) {
    final siblings = _nodes.where((n) => n.parentId == parent.id).length;
    final newId = 'node_${DateTime.now().microsecondsSinceEpoch}';
    final offset = Offset(
      parent.position.dx + 230,
      parent.position.dy + (siblings * 70) - 35,
    );

    setState(() {
      _nodes.add(MindMapNode(
        id: newId,
        parentId: parent.id,
        text: 'Novo Tópico',
        position: offset,
      ));
    });
    _saveMap();
  }

  void _editNodeText(MindMapNode node) {
    final textController = TextEditingController(text: node.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Tópico'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Texto do Nó',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (val) {
            Navigator.of(ctx).pop();
            if (val.trim().isNotEmpty) {
              setState(() => node.text = val.trim());
              _saveMap();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (textController.text.trim().isNotEmpty) {
                setState(() => node.text = textController.text.trim());
                _saveMap();
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _deleteNode(MindMapNode node) {
    if (node.parentId == null) return; // Raiz protegida

    // Remove recursivamente o nó e todos os filhos
    final toRemove = <String>{node.id};
    bool added;
    do {
      added = false;
      for (final n in _nodes) {
        if (n.parentId != null && toRemove.contains(n.parentId) && !toRemove.contains(n.id)) {
          toRemove.add(n.id);
          added = true;
        }
      }
    } while (added);

    setState(() {
      _nodes.removeWhere((n) => toRemove.contains(n.id));
    });
    _saveMap();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = ThemeService();
    final isGlass = themeService.isAnyGlass;

    return Scaffold(
      backgroundColor: isGlass ? Colors.transparent : null,
      appBar: AppBar(
        backgroundColor: isGlass ? Colors.transparent : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hub_outlined, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Mapa Mental • ${widget.day.title}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_center_focus),
            tooltip: 'Centralizar',
            onPressed: () => _centerView(MediaQuery.of(context).size),
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Salvar',
            onPressed: () => _saveMap(showFeedback: true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                if (!_hasCentered) {
                  _hasCentered = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _centerView(Size(constraints.maxWidth, constraints.maxHeight));
                  });
                }

                return InteractiveViewer(
                  constrained: false,
                  minScale: 0.3,
                  maxScale: 2.5,
                  transformationController: _transController,
                  boundaryMargin: const EdgeInsets.all(500),
                  child: SizedBox(
                    width: canvasSize,
                    height: canvasSize,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Grade de fundo sutil
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _CanvasGridPainter(
                              gridColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                            ),
                          ),
                        ),

                        // Linhas conectando os nós com curvas de Bézier
                        Positioned.fill(
                          child: CustomPaint(
                            painter: MindMapConnectionsPainter(
                              nodes: _nodes,
                              lineColor: theme.colorScheme.primary.withValues(alpha: 0.7),
                            ),
                          ),
                        ),

                        // Nós interativos e arrastáveis
                        for (final node in _nodes)
                          Positioned(
                            left: node.position.dx,
                            top: node.position.dy,
                            child: GestureDetector(
                              onPanUpdate: (details) {
                                setState(() {
                                  node.position += details.delta;
                                });
                              },
                              onPanEnd: (_) => _saveMap(),
                              child: _buildNodeCard(node, theme),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildNodeCard(MindMapNode node, ThemeData theme) {
    final isRoot = node.parentId == null;
    final cardBg = isRoot
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = isRoot
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    return Material(
      elevation: isRoot ? 4 : 2,
      borderRadius: BorderRadius.circular(14),
      color: cardBg,
      child: Container(
        width: 175,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRoot
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: isRoot ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Texto do nó (toque para editar)
            Expanded(
              child: InkWell(
                onTap: () => _editNodeText(node),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    node.text,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: isRoot ? FontWeight.bold : FontWeight.w600,
                      fontSize: isRoot ? 14 : 13,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),

            // Botão Adicionar Filho (+)
            InkWell(
              onTap: () => _addNode(node),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.add_circle_outline,
                  size: 19,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),

            // Botão Excluir (somente se não for raiz)
            if (!isRoot)
              InkWell(
                onTap: () => _deleteNode(node),
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.redAccent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pinta uma grade de pontos sutil para orientação espacial no estúdio
class _CanvasGridPainter extends CustomPainter {
  final Color gridColor;

  _CanvasGridPainter({required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CanvasGridPainter oldDelegate) => false;
}
