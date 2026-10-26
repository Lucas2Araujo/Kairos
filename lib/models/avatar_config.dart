import 'dart:convert';
import 'package:flutter/material.dart';

/// Modelo de Configuração do Avatar Kairós modular
class AvatarConfig {
  final int skinToneIndex;
  final int hairStyleIndex;
  final int hairColorIndex;
  final int expressionIndex;
  final int glassesIndex;
  final int accessoryIndex;
  final int backgroundColorIndex;

  const AvatarConfig({
    this.skinToneIndex = 1,
    this.hairStyleIndex = 0,
    this.hairColorIndex = 0,
    this.expressionIndex = 0,
    this.glassesIndex = 0,
    this.accessoryIndex = 0,
    this.backgroundColorIndex = 0,
  });

  // Paleta de Tons de Pele
  static const List<Color> skinTones = [
    Color(0xFFFFDFC4), // Claro / Rosado
    Color(0xFFF0D5BE), // Claro / Neutro
    Color(0xFFD1A17C), // Médio / Moreno Claro
    Color(0xFFB57D52), // Médio Moreno
    Color(0xFF8D5524), // Moreno Escuro
    Color(0xFF5A3825), // Negro Escuro
  ];

  // Cores de Cabelo
  static const List<Color> hairColors = [
    Color(0xFF2C221E), // Preto suave
    Color(0xFF4A3728), // Castanho escuro
    Color(0xFF8B5A2B), // Castanho claro
    Color(0xFFD4A373), // Loiro
    Color(0xFFA55A32), // Ruivo
    Color(0xFF9E9E9E), // Grisalho
    Color(0xFFE0E0E0), // Branco
  ];

  // Paleta de Fundo
  static const List<Color> backgroundColors = [
    Color(0xFF0077B6), // Azul Céu Kairós
    Color(0xFF2A9D8F), // Verde Água Esperança
    Color(0xFFE76F51), // Coral Pôr do Sol
    Color(0xFFF4A261), // Âmbar Dourado
    Color(0xFF6A4C93), // Roxo Real
    Color(0xFF343A40), // Grafite Elegante
  ];

  // Nomes de Estilos
  static const List<String> hairStyles = [
    'Curto Elegante',
    'Cacheado Volumoso',
    'Longo / Ondulado',
    'Topete Moderno',
    'Coque Alto',
    'Careca / Raspado',
  ];

  static const List<String> expressions = [
    'Sorridente',
    'Sereno / Confiante',
    'Alegre / Olhos Fechados',
    'Contemplativo',
  ];

  static const List<String> glassesList = [
    'Nenhum',
    'Redondo Clássico',
    'Retangular Moderno',
    'Aviador',
  ];

  static const List<String> accessories = [
    'Nenhum',
    'Aura Dourada (Azeite)',
    'Ramo de Oliveira',
    'Pingente Cruz / Peixe',
    'Coroa da Vitória',
  ];

  AvatarConfig copyWith({
    int? skinToneIndex,
    int? hairStyleIndex,
    int? hairColorIndex,
    int? expressionIndex,
    int? glassesIndex,
    int? accessoryIndex,
    int? backgroundColorIndex,
  }) {
    return AvatarConfig(
      skinToneIndex: skinToneIndex ?? this.skinToneIndex,
      hairStyleIndex: hairStyleIndex ?? this.hairStyleIndex,
      hairColorIndex: hairColorIndex ?? this.hairColorIndex,
      expressionIndex: expressionIndex ?? this.expressionIndex,
      glassesIndex: glassesIndex ?? this.glassesIndex,
      accessoryIndex: accessoryIndex ?? this.accessoryIndex,
      backgroundColorIndex: backgroundColorIndex ?? this.backgroundColorIndex,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'skinToneIndex': skinToneIndex,
      'hairStyleIndex': hairStyleIndex,
      'hairColorIndex': hairColorIndex,
      'expressionIndex': expressionIndex,
      'glassesIndex': glassesIndex,
      'accessoryIndex': accessoryIndex,
      'backgroundColorIndex': backgroundColorIndex,
    };
  }

  factory AvatarConfig.fromMap(Map<String, dynamic> map) {
    return AvatarConfig(
      skinToneIndex: (map['skinToneIndex'] as num?)?.toInt() ?? 1,
      hairStyleIndex: (map['hairStyleIndex'] as num?)?.toInt() ?? 0,
      hairColorIndex: (map['hairColorIndex'] as num?)?.toInt() ?? 0,
      expressionIndex: (map['expressionIndex'] as num?)?.toInt() ?? 0,
      glassesIndex: (map['glassesIndex'] as num?)?.toInt() ?? 0,
      accessoryIndex: (map['accessoryIndex'] as num?)?.toInt() ?? 0,
      backgroundColorIndex: (map['backgroundColorIndex'] as num?)?.toInt() ?? 0,
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
}

