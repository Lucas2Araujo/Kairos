import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Modelo de Configuração do Avatar Kairós 2.0 modular e retrocompatível,
/// incluindo roupas personalizáveis, formatos de rosto, barba, itens especiais
/// desbloqueáveis por conquistas e insígnias sincronizadas com a Turma.
class AvatarConfig {
  final int skinToneIndex;
  final int faceShapeIndex;
  final int hairStyleIndex;
  final int hairColorIndex;
  final int facialHairIndex;
  final int expressionIndex;
  final int glassesIndex;
  final int outfitIndex;
  final int outfitColorIndex;
  final int accessoryIndex;
  final int backgroundColorIndex;
  final List<String> unlockedTrophies;
  final String? featuredBadge;

  const AvatarConfig({
    this.skinToneIndex = 1,
    this.faceShapeIndex = 0,
    this.hairStyleIndex = 0,
    this.hairColorIndex = 0,
    this.facialHairIndex = 0,
    this.expressionIndex = 0,
    this.glassesIndex = 0,
    this.outfitIndex = 0,
    this.outfitColorIndex = 0,
    this.accessoryIndex = 0,
    this.backgroundColorIndex = 0,
    this.unlockedTrophies = const [],
    this.featuredBadge,
  });

  // Paleta de Tons de Pele
  static const List<Color> skinTones = [
    Color(0xFFFFDFC4), // Claro / Rosado
    Color(0xFFF0D5BE), // Claro / Neutro
    Color(0xFFD9A77F), // Médio / Moreno Claro
    Color(0xFFB57D52), // Médio Moreno
    Color(0xFF8D5524), // Moreno Escuro
    Color(0xFF5A3825), // Negro Escuro
    Color(0xFF3D2314), // Ébano Profundo
  ];

  // Formatos de Rosto
  static const List<String> faceShapes = [
    'Oval Suave',
    'Jovem Arredondado',
    'Angular Definido',
    'Delicado',
  ];

  // Cores de Cabelo / Barba
  static const List<Color> hairColors = [
    Color(0xFF201A17), // Preto intenso
    Color(0xFF4A3728), // Castanho escuro
    Color(0xFF8B5A2B), // Castanho claro
    Color(0xFFD4A373), // Loiro dourado
    Color(0xFFA54A2A), // Ruivo acobreado
    Color(0xFF6D2E46), // Vinho moderno
    Color(0xFF9E9E9E), // Grisalho
    Color(0xFFE5E5E5), // Platinado / Branco
  ];

  // Paleta de Fundo (Cores base de gradientes)
  static const List<Color> backgroundColors = [
    Color(0xFF0077B6), // 0: Azul Céu Kairós
    Color(0xFF2A9D8F), // 1: Verde Água Esperança
    Color(0xFFE76F51), // 2: Coral Pôr do Sol
    Color(0xFFF4A261), // 3: Âmbar Dourado
    Color(0xFF6A4C93), // 4: Roxo Real
    Color(0xFF343A40), // 5: Grafite Elegante
    Color(0xFF4F46E5), // 6: Aurora Celestial (Conquista: explorador_biblico)
    Color(0xFFD97706), // 7: Ouro Sagrado (Conquista: mestre_palavra)
  ];

  static const List<String> backgroundNames = [
    'Céu Kairós',
    'Verde Esperança',
    'Coral Suave',
    'Âmbar Solar',
    'Roxo Real',
    'Grafite Noite',
    'Aurora Celestial',
    'Pôr do Sol Dourado',
  ];

  // Cores de Roupa
  static const List<Color> outfitColors = [
    Color(0xFF1D3557), // Azul Marinho
    Color(0xFF2B9348), // Verde Floresta
    Color(0xFF9B2226), // Bordô Clássico
    Color(0xFF5A189A), // Violeta
    Color(0xFF343A40), // Preto Grafite
    Color(0xFFE09F3E), // Mostarda
    Color(0xFF0077B6), // Azul Royal
    Color(0xFFF8F9FA), // Branco Culto
  ];

  // Estilos de Cabelo (0..5 mantidos para retrocompatibilidade)
  static const List<String> hairStyles = [
    'Curto Elegante',
    'Cacheado Volumoso',
    'Longo Ondulado',
    'Topete Moderno',
    'Coque Alto',
    'Raspado / Careca',
    'Black Power / Afro',
    'Médio com Franja',
  ];

  // Barba / Bigode
  static const List<String> facialHairStyles = [
    'Nenhum',
    'Barba Sutil',
    'Cavanhaque',
    'Barba Cheia',
  ];

  // Expressões
  static const List<String> expressions = [
    'Sorridente',
    'Sereno & Confiante',
    'Alegre (Olhos Fechados)',
    'Contemplativo',
    'Piscadela Amigável',
  ];

  // Óculos
  static const List<String> glassesList = [
    'Nenhum',
    'Redondo Clássico',
    'Retangular Moderno',
    'Aviador Dourado',
    'Meia-Armação Intelectual',
  ];

  // Roupas / Trajes
  static const List<String> outfits = [
    'Camiseta Casual',
    'Social de Sábado',
    'Moletom Jovem',
    'Uniforme com Lenço',
    'Túnica Bereana',
    'Traje Mestre Sabatino',
    'Manto de Luz Dourada',
    'Jaqueta da Comunidade',
  ];

  // Acessórios e Molduras
  static const List<String> accessories = [
    'Nenhum',
    'Aura Dourada (Azeite)',
    'Ramo de Oliveira',
    'Pingente Cruz / Fé',
    'Coroa da Vitória',
    'Auréola Sentinela',
    'Insígnia da Turma',
  ];

  /// Retorna o ID da conquista necessária para desbloquear uma roupa (ou null se livre)
  static String? requiredTrophyForOutfit(int index) {
    switch (index) {
      case 4:
        return 'bereano';
      case 5:
        return 'mestre_escola_sabatina';
      case 6:
        return 'virgem_prudente';
      case 7:
        return 'membro_turma';
      default:
        return null;
    }
  }

  /// Retorna o ID da conquista necessária para desbloquear um acessório (ou null se livre)
  static String? requiredTrophyForAccessory(int index) {
    switch (index) {
      case 1:
        return 'primeiro_passo';
      case 4:
        return 'semana_vitoria';
      case 5:
        return 'sentinela_manha';
      case 6:
        return 'chama_comunidade';
      default:
        return null;
    }
  }

  /// Retorna o ID da conquista necessária para desbloquear um fundo (ou null se livre)
  static String? requiredTrophyForBackground(int index) {
    switch (index) {
      case 6:
        return 'explorador_biblico';
      case 7:
        return 'mestre_palavra';
      default:
        return null;
    }
  }

  AvatarConfig copyWith({
    int? skinToneIndex,
    int? faceShapeIndex,
    int? hairStyleIndex,
    int? hairColorIndex,
    int? facialHairIndex,
    int? expressionIndex,
    int? glassesIndex,
    int? outfitIndex,
    int? outfitColorIndex,
    int? accessoryIndex,
    int? backgroundColorIndex,
    List<String>? unlockedTrophies,
    String? featuredBadge,
    bool clearFeaturedBadge = false,
  }) {
    return AvatarConfig(
      skinToneIndex: skinToneIndex ?? this.skinToneIndex,
      faceShapeIndex: faceShapeIndex ?? this.faceShapeIndex,
      hairStyleIndex: hairStyleIndex ?? this.hairStyleIndex,
      hairColorIndex: hairColorIndex ?? this.hairColorIndex,
      facialHairIndex: facialHairIndex ?? this.facialHairIndex,
      expressionIndex: expressionIndex ?? this.expressionIndex,
      glassesIndex: glassesIndex ?? this.glassesIndex,
      outfitIndex: outfitIndex ?? this.outfitIndex,
      outfitColorIndex: outfitColorIndex ?? this.outfitColorIndex,
      accessoryIndex: accessoryIndex ?? this.accessoryIndex,
      backgroundColorIndex: backgroundColorIndex ?? this.backgroundColorIndex,
      unlockedTrophies: unlockedTrophies ?? this.unlockedTrophies,
      featuredBadge: clearFeaturedBadge ? null : (featuredBadge ?? this.featuredBadge),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'skinToneIndex': skinToneIndex,
      'faceShapeIndex': faceShapeIndex,
      'hairStyleIndex': hairStyleIndex,
      'hairColorIndex': hairColorIndex,
      'facialHairIndex': facialHairIndex,
      'expressionIndex': expressionIndex,
      'glassesIndex': glassesIndex,
      'outfitIndex': outfitIndex,
      'outfitColorIndex': outfitColorIndex,
      'accessoryIndex': accessoryIndex,
      'backgroundColorIndex': backgroundColorIndex,
      if (unlockedTrophies.isNotEmpty) 'unlockedTrophies': unlockedTrophies,
      if (featuredBadge != null && featuredBadge!.isNotEmpty) 'featuredBadge': featuredBadge,
    };
  }

  factory AvatarConfig.fromMap(Map<String, dynamic> map) {
    final rawTrophies = map['unlockedTrophies'];
    final parsedTrophies = rawTrophies is List
        ? rawTrophies.map((e) => e.toString()).toList()
        : const <String>[];

    return AvatarConfig(
      skinToneIndex: (map['skinToneIndex'] as num?)?.toInt() ?? 1,
      faceShapeIndex: (map['faceShapeIndex'] as num?)?.toInt() ?? 0,
      hairStyleIndex: (map['hairStyleIndex'] as num?)?.toInt() ?? 0,
      hairColorIndex: (map['hairColorIndex'] as num?)?.toInt() ?? 0,
      facialHairIndex: (map['facialHairIndex'] as num?)?.toInt() ?? 0,
      expressionIndex: (map['expressionIndex'] as num?)?.toInt() ?? 0,
      glassesIndex: (map['glassesIndex'] as num?)?.toInt() ?? 0,
      outfitIndex: (map['outfitIndex'] as num?)?.toInt() ?? 0,
      outfitColorIndex: (map['outfitColorIndex'] as num?)?.toInt() ?? 0,
      accessoryIndex: (map['accessoryIndex'] as num?)?.toInt() ?? 0,
      backgroundColorIndex: (map['backgroundColorIndex'] as num?)?.toInt() ?? 0,
      unlockedTrophies: parsedTrophies,
      featuredBadge: map['featuredBadge']?.toString(),
    );
  }

  String toJson() => json.encode(toMap());

  factory AvatarConfig.fromJson(String source) {
    try {
      return AvatarConfig.fromMap(json.decode(source) as Map<String, dynamic>);
    } catch (_) {
      return const AvatarConfig();
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AvatarConfig &&
        other.skinToneIndex == skinToneIndex &&
        other.faceShapeIndex == faceShapeIndex &&
        other.hairStyleIndex == hairStyleIndex &&
        other.hairColorIndex == hairColorIndex &&
        other.facialHairIndex == facialHairIndex &&
        other.expressionIndex == expressionIndex &&
        other.glassesIndex == glassesIndex &&
        other.outfitIndex == outfitIndex &&
        other.outfitColorIndex == outfitColorIndex &&
        other.accessoryIndex == accessoryIndex &&
        other.backgroundColorIndex == backgroundColorIndex &&
        other.featuredBadge == featuredBadge &&
        listEquals(other.unlockedTrophies, unlockedTrophies);
  }

  @override
  int get hashCode => Object.hash(
        skinToneIndex,
        faceShapeIndex,
        hairStyleIndex,
        hairColorIndex,
        facialHairIndex,
        expressionIndex,
        glassesIndex,
        outfitIndex,
        outfitColorIndex,
        accessoryIndex,
        backgroundColorIndex,
        featuredBadge,
        Object.hashAll(unlockedTrophies),
      );
}
