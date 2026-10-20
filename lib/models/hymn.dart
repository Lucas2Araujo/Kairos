class Hymn {
  final int id;
  final String numero;
  final String titulo;
  final String? letra;
  final String? autorLetra;
  final String? autorMusica;
  final String? textoBase;
  final String? categoria;
  final String? subcategoria;
  final String? autores;
  final String? linkVideo;

  const Hymn({
    required this.id,
    required this.numero,
    required this.titulo,
    this.letra,
    this.autorLetra,
    this.autorMusica,
    this.textoBase,
    this.categoria,
    this.subcategoria,
    this.autores,
    this.linkVideo,
  });

  factory Hymn.fromMap(Map<String, dynamic> map) {
    return Hymn(
      id: map['id'] as int? ?? 0,
      numero: (map['numero'] ?? '').toString(),
      titulo: (map['titulo'] ?? '').toString(),
      letra: map['letra'] as String?,
      autorLetra: map['autor_letra'] as String?,
      autorMusica: map['autor_musica'] as String?,
      textoBase: map['texto_base'] as String?,
      categoria: map['categoria'] as String?,
      subcategoria: map['subcategoria'] as String?,
      autores: map['autores'] as String?,
      linkVideo: map['link_video'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'numero': numero,
      'titulo': titulo,
      'letra': letra,
      'autor_letra': autorLetra,
      'autor_musica': autorMusica,
      'texto_base': textoBase,
      'categoria': categoria,
      'subcategoria': subcategoria,
      'autores': autores,
    };
  }
}
