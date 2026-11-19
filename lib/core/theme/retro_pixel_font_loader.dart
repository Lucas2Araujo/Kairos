import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Gerador e carregador em memória de fonte bitmap pixelizada 8-bit/16-bit retrô
/// em formato TrueType (`.ttf`), aplicada ao tema ASCII Vintage (`PixelMono`).
class RetroPixelFontLoader {
  RetroPixelFontLoader._();

  static const int _unitsPerEm = 1024;
  static const int _advanceWidth = 800;
  static const int _leftMargin = 36;
  static const int _stepX = 102;
  static const int _stepY = 100;
  static const int _pixelHeight = 100;
  static const int _baselineRow = 9;
  static const int _totalRows = 13;

  static Future<void>? _loadFuture;
  static bool _isLoaded = false;

  /// Garante que os pesos Regular e Bold da fonte pixel 8-bit estejam
  /// carregados em memória para `'PixelMono'` e `'RetroPixel'`.
  static Future<void> ensureLoaded() {
    if (_isLoaded) return Future.value();
    return _loadFuture ??= _loadAll();
  }

  static Future<void> _loadAll() async {
    try {
      for (final family in const ['PixelMono', 'RetroPixel']) {
        final loader = FontLoader(family);
        final regularBytes = buildTtfBytes(familyName: family, bold: false);
        final boldBytes = buildTtfBytes(familyName: family, bold: true);
        loader.addFont(Future.value(ByteData.sublistView(regularBytes)));
        loader.addFont(Future.value(ByteData.sublistView(boldBytes)));
        await loader.load();
      }
      _isLoaded = true;
    } catch (e) {
      debugPrint('[RetroPixelFontLoader] Erro ao carregar fonte pixelizada: $e');
      _loadFuture = null;
    }
  }

  /// Constrói um arquivo TrueType (`.ttf`) completo com glifos bitmap 7x13 (8-bit CRT).
  @visibleForTesting
  static Uint8List buildTtfBytes({
    required String familyName,
    bool bold = false,
  }) {
    final glyphs = _buildGlyphTable();
    final sortedCodePoints = glyphs.keys.where((cp) => cp > 0).toList()..sort();

    // Índice 0 reservado ao .notdef; índice 1+ segue código Unicode crescente.
    final orderedGlyphs = <_PixelGlyph>[
      glyphs[0]!,
      for (final cp in sortedCodePoints) glyphs[cp]!,
    ];
    final codePointToGid = <int, int>{};
    for (int i = 0; i < sortedCodePoints.length; i++) {
      codePointToGid[sortedCodePoints[i]] = i + 1;
    }

    final builtGlyf = _buildGlyfAndLoca(orderedGlyphs, bold: bold);
    final hmtxBytes = _buildHmtx(orderedGlyphs.length, builtGlyf.lsbs);
    final cmapBytes = _buildCmap(sortedCodePoints, codePointToGid);
    final nameBytes = _buildNameTable(familyName, bold: bold);
    final postBytes = _buildPostTable();
    final os2Bytes = _buildOs2Table(
      bold: bold,
      firstChar: sortedCodePoints.isEmpty ? 32 : sortedCodePoints.first,
      lastChar: sortedCodePoints.isEmpty ? 126 : sortedCodePoints.last,
    );
    final maxpBytes = _buildMaxpTable(
      numGlyphs: orderedGlyphs.length,
      maxPoints: builtGlyf.maxPoints,
      maxContours: builtGlyf.maxContours,
    );
    final hheaBytes = _buildHheaTable(
      numGlyphs: orderedGlyphs.length,
      minLsb: builtGlyf.minLsb,
      minRsb: builtGlyf.minRsb,
      xMaxExtent: builtGlyf.xMaxExtent,
    );
    final headBytes = _buildHeadTable(
      bold: bold,
      xMin: builtGlyf.xMin,
      yMin: builtGlyf.yMin,
      xMax: builtGlyf.xMax,
      yMax: builtGlyf.yMax,
    );

    // Ordem alfabética estrita das tags de tabela conforme especificação OpenType/TTF.
    final tables = <String, Uint8List>{
      'OS/2': os2Bytes,
      'cmap': cmapBytes,
      'glyf': builtGlyf.glyf,
      'head': headBytes,
      'hhea': hheaBytes,
      'hmtx': hmtxBytes,
      'loca': builtGlyf.loca,
      'maxp': maxpBytes,
      'name': nameBytes,
      'post': postBytes,
    };

    return _assembleSfnt(tables);
  }

  static _GlyfBuildResult _buildGlyfAndLoca(
    List<_PixelGlyph> glyphs, {
    required bool bold,
  }) {
    final glyfOut = BytesBuilder(copy: false);
    final locaByteData = ByteData((glyphs.length + 1) * 4);

    int globalXMin = 32767;
    int globalYMin = 32767;
    int globalXMax = -32768;
    int globalYMax = -32768;
    int minLsb = 32767;
    int minRsb = 32767;
    int xMaxExtent = -32768;
    int maxPoints = 0;
    int maxContours = 0;
    final lsbs = <int>[];

    final boldExtra = bold ? 36 : 20;

    for (int gid = 0; gid < glyphs.length; gid++) {
      locaByteData.setUint32(gid * 4, glyfOut.length, Endian.big);
      final g = glyphs[gid];

      // Converte cada segmento horizontal contínuo em um retângulo horário sólido
      // com altura integral (_pixelHeight == _stepY) para estética de fonte bitmap SNES.
      final rects = <_GlyphRect>[];
      for (int r = 0; r < _totalRows; r++) {
        final mask = g.rows[r];
        if (mask == 0) continue;
        final yBottom = (_baselineRow - r) * _stepY;
        final yTop = yBottom + _pixelHeight;

        int c = 0;
        while (c < 7) {
          final isSet = ((mask >> (6 - c)) & 1) == 1;
          if (!isSet) {
            c++;
            continue;
          }
          final cStart = c;
          while (c + 1 < 7 && ((mask >> (6 - (c + 1))) & 1) == 1) {
            c++;
          }
          final xLeft = _leftMargin + cStart * _stepX;
          final xRight = _leftMargin + (c + 1) * _stepX + boldExtra;
          rects.add(_GlyphRect(xLeft, yBottom, xRight, yTop));
          c++;
        }
      }

      if (rects.isEmpty) {
        lsbs.add(0);
        continue;
      }

      int gXMin = rects.first.xMin;
      int gYMin = rects.first.yMin;
      int gXMax = rects.first.xMax;
      int gYMax = rects.first.yMax;
      for (final rect in rects) {
        if (rect.xMin < gXMin) gXMin = rect.xMin;
        if (rect.yMin < gYMin) gYMin = rect.yMin;
        if (rect.xMax > gXMax) gXMax = rect.xMax;
        if (rect.yMax > gYMax) gYMax = rect.yMax;
      }

      if (gXMin < globalXMin) globalXMin = gXMin;
      if (gYMin < globalYMin) globalYMin = gYMin;
      if (gXMax > globalXMax) globalXMax = gXMax;
      if (gYMax > globalYMax) globalYMax = gYMax;

      final lsb = gXMin;
      final rsb = _advanceWidth - gXMax;
      final extent = gXMax;
      if (lsb < minLsb) minLsb = lsb;
      if (rsb < minRsb) minRsb = rsb;
      if (extent > xMaxExtent) xMaxExtent = extent;
      lsbs.add(lsb);

      final numContours = rects.length;
      final numPoints = numContours * 4;
      if (numContours > maxContours) maxContours = numContours;
      if (numPoints > maxPoints) maxPoints = numPoints;

      final headerSize = 10 + numContours * 2 + 2;
      final flagsSize = numPoints;
      final coordsSize = numPoints * 2 * 2;
      final glyphBuf = ByteData(headerSize + flagsSize + coordsSize);

      glyphBuf.setInt16(0, numContours, Endian.big);
      glyphBuf.setInt16(2, gXMin, Endian.big);
      glyphBuf.setInt16(4, gYMin, Endian.big);
      glyphBuf.setInt16(6, gXMax, Endian.big);
      glyphBuf.setInt16(8, gYMax, Endian.big);

      int offset = 10;
      for (int cIdx = 0; cIdx < numContours; cIdx++) {
        glyphBuf.setUint16(offset, cIdx * 4 + 3, Endian.big);
        offset += 2;
      }
      glyphBuf.setUint16(offset, 0, Endian.big); // instructionLength = 0
      offset += 2;

      for (int p = 0; p < numPoints; p++) {
        glyphBuf.setUint8(offset++, 0x01); // On-curve, int16 x/y deltas
      }

      final xs = <int>[];
      final ys = <int>[];
      for (final rect in rects) {
        // Sentido horário em coordenadas TrueType (+x direita, +y cima):
        // baixo-esq -> cima-esq -> cima-dir -> baixo-dir.
        xs.addAll([rect.xMin, rect.xMin, rect.xMax, rect.xMax]);
        ys.addAll([rect.yMin, rect.yMax, rect.yMax, rect.yMin]);
      }

      int prevX = 0;
      for (final x in xs) {
        glyphBuf.setInt16(offset, x - prevX, Endian.big);
        offset += 2;
        prevX = x;
      }

      int prevY = 0;
      for (final y in ys) {
        glyphBuf.setInt16(offset, y - prevY, Endian.big);
        offset += 2;
        prevY = y;
      }

      glyfOut.add(glyphBuf.buffer.asUint8List());
      while (glyfOut.length % 4 != 0) {
        glyfOut.addByte(0);
      }
    }

    locaByteData.setUint32(glyphs.length * 4, glyfOut.length, Endian.big);

    return _GlyfBuildResult(
      glyf: glyfOut.toBytes(),
      loca: locaByteData.buffer.asUint8List(),
      lsbs: lsbs,
      xMin: globalXMin == 32767 ? 0 : globalXMin,
      yMin: globalYMin == 32767 ? 0 : globalYMin,
      xMax: globalXMax == -32768 ? _advanceWidth : globalXMax,
      yMax: globalYMax == -32768 ? 900 : globalYMax,
      minLsb: minLsb == 32767 ? 0 : minLsb,
      minRsb: minRsb == 32767 ? 0 : minRsb,
      xMaxExtent: xMaxExtent == -32768 ? _advanceWidth : xMaxExtent,
      maxPoints: maxPoints,
      maxContours: maxContours,
    );
  }

  static Uint8List _buildHeadTable({
    required bool bold,
    required int xMin,
    required int yMin,
    required int xMax,
    required int yMax,
  }) {
    final bd = ByteData(54);
    bd.setUint32(0, 0x00010000, Endian.big); // version 1.0
    bd.setUint32(4, 0x00010000, Endian.big); // fontRevision 1.0
    bd.setUint32(8, 0, Endian.big); // checkSumAdjustment preenchido em _assembleSfnt
    bd.setUint32(12, 0x5F0F3CF5, Endian.big); // magicNumber
    bd.setUint16(16, 0x000B, Endian.big); // flags: baseline at y=0, lsb at x=0
    bd.setUint16(18, _unitsPerEm, Endian.big);
    // created / modified (bytes 20..35) = 0
    bd.setInt16(36, xMin, Endian.big);
    bd.setInt16(38, yMin, Endian.big);
    bd.setInt16(40, xMax, Endian.big);
    bd.setInt16(42, yMax, Endian.big);
    bd.setUint16(44, bold ? 1 : 0, Endian.big); // macStyle
    bd.setUint16(46, 8, Endian.big); // lowestRecPPEM
    bd.setInt16(48, 2, Endian.big); // fontDirectionHint
    bd.setInt16(50, 1, Endian.big); // indexToLocFormat = 1 (32-bit long loca)
    bd.setInt16(52, 0, Endian.big); // glyphDataFormat
    return bd.buffer.asUint8List();
  }

  static Uint8List _buildHheaTable({
    required int numGlyphs,
    required int minLsb,
    required int minRsb,
    required int xMaxExtent,
  }) {
    final bd = ByteData(36);
    bd.setUint32(0, 0x00010000, Endian.big);
    bd.setInt16(4, 1000, Endian.big); // ascender
    bd.setInt16(6, -240, Endian.big); // descender
    bd.setInt16(8, 80, Endian.big); // lineGap
    bd.setUint16(10, _advanceWidth, Endian.big); // advanceWidthMax
    bd.setInt16(12, minLsb, Endian.big);
    bd.setInt16(14, minRsb, Endian.big);
    bd.setInt16(16, xMaxExtent, Endian.big);
    bd.setInt16(18, 1, Endian.big); // caretSlopeRise
    bd.setInt16(20, 0, Endian.big); // caretSlopeRun
    // 22..31 reserved = 0
    bd.setInt16(32, 0, Endian.big); // metricDataFormat
    bd.setUint16(34, numGlyphs, Endian.big); // numberOfHMetrics
    return bd.buffer.asUint8List();
  }

  static Uint8List _buildMaxpTable({
    required int numGlyphs,
    required int maxPoints,
    required int maxContours,
  }) {
    final bd = ByteData(32);
    bd.setUint32(0, 0x00010000, Endian.big);
    bd.setUint16(4, numGlyphs, Endian.big);
    bd.setUint16(6, maxPoints, Endian.big);
    bd.setUint16(8, maxContours, Endian.big);
    bd.setUint16(14, 1, Endian.big); // maxZones = 1
    return bd.buffer.asUint8List();
  }

  static Uint8List _buildHmtx(int numGlyphs, List<int> lsbs) {
    final bd = ByteData(numGlyphs * 4);
    for (int i = 0; i < numGlyphs; i++) {
      bd.setUint16(i * 4, _advanceWidth, Endian.big);
      bd.setInt16(i * 4 + 2, lsbs[i], Endian.big);
    }
    return bd.buffer.asUint8List();
  }

  static Uint8List _buildOs2Table({
    required bool bold,
    required int firstChar,
    required int lastChar,
  }) {
    final bd = ByteData(96);
    bd.setUint16(0, 3, Endian.big); // version 3
    bd.setInt16(2, _advanceWidth, Endian.big); // xAvgCharWidth
    bd.setUint16(4, bold ? 700 : 400, Endian.big); // usWeightClass
    bd.setUint16(6, 5, Endian.big); // usWidthClass = Medium
    bd.setUint16(8, 0, Endian.big); // fsType = installable
    bd.setInt16(10, 400, Endian.big); // ySubscriptXSize
    bd.setInt16(12, 400, Endian.big); // ySubscriptYSize
    bd.setInt16(14, 0, Endian.big);
    bd.setInt16(16, 140, Endian.big);
    bd.setInt16(18, 400, Endian.big); // ySuperscriptXSize
    bd.setInt16(20, 400, Endian.big);
    bd.setInt16(22, 0, Endian.big);
    bd.setInt16(24, 380, Endian.big);
    bd.setInt16(26, 70, Endian.big); // yStrikeoutSize
    bd.setInt16(28, 300, Endian.big); // yStrikeoutPosition
    bd.setInt16(30, 0x0800, Endian.big); // sFamilyClass: Sans/Monospace
    // panose (bytes 32..41): proportion = 9 (Monospaced)
    bd.setUint8(32, 2); // Latin Text
    bd.setUint8(33, 11); // Normal Sans
    bd.setUint8(34, bold ? 8 : 5);
    bd.setUint8(35, 9); // Monospaced
    // ulUnicodeRange1: Basic Latin + Latin-1 Supplement
    bd.setUint32(42, 0x00000003, Endian.big);
    // achVendID = 'KARS'
    bd.setUint8(58, 0x4B);
    bd.setUint8(59, 0x41);
    bd.setUint8(60, 0x52);
    bd.setUint8(61, 0x53);
    bd.setUint16(62, bold ? 0x0020 : 0x0040, Endian.big); // fsSelection
    bd.setUint16(64, firstChar.clamp(0, 0xFFFF), Endian.big);
    bd.setUint16(66, lastChar.clamp(0, 0xFFFF), Endian.big);
    bd.setInt16(68, 1000, Endian.big); // sTypoAscender
    bd.setInt16(70, -240, Endian.big); // sTypoDescender
    bd.setInt16(72, 80, Endian.big); // sTypoLineGap
    bd.setUint16(74, 1020, Endian.big); // usWinAscent
    bd.setUint16(76, 260, Endian.big); // usWinDescent
    bd.setUint32(78, 0x00000001, Endian.big); // ulCodePageRange1 (Latin 1)
    bd.setInt16(86, 490, Endian.big); // sxHeight
    bd.setInt16(88, 690, Endian.big); // sCapHeight
    bd.setUint16(90, 0, Endian.big); // usDefaultChar
    bd.setUint16(92, 32, Endian.big); // usBreakChar
    bd.setUint16(94, 1, Endian.big); // usMaxContext
    return bd.buffer.asUint8List();
  }

  static Uint8List _buildCmap(
    List<int> sortedCodePoints,
    Map<int, int> codePointToGid,
  ) {
    // Agrupa code points BMP contíguos cujos GIDs também aumentam de 1 em 1.
    final startCodes = <int>[];
    final endCodes = <int>[];
    final idDeltas = <int>[];

    int i = 0;
    while (i < sortedCodePoints.length) {
      final start = sortedCodePoints[i];
      if (start > 0xFFFF) break;
      final startGid = codePointToGid[start]!;
      int end = start;
      while (i + 1 < sortedCodePoints.length &&
          sortedCodePoints[i + 1] == end + 1 &&
          sortedCodePoints[i + 1] <= 0xFFFF &&
          codePointToGid[sortedCodePoints[i + 1]] == startGid + (end + 1 - start)) {
        i++;
        end = sortedCodePoints[i];
      }
      startCodes.add(start);
      endCodes.add(end);
      idDeltas.add((startGid - start) & 0xFFFF);
      i++;
    }

    // Segmento sentinela obrigatório 0xFFFF -> 0xFFFF.
    startCodes.add(0xFFFF);
    endCodes.add(0xFFFF);
    idDeltas.add(1);

    final segCount = startCodes.length;
    final subtableLen = 14 + 2 + segCount * 8;

    int searchRange = 2;
    int entrySelector = 0;
    while (searchRange * 2 <= segCount * 2) {
      searchRange *= 2;
      entrySelector++;
    }
    final rangeShift = segCount * 2 - searchRange;

    const headerLen = 4 + 2 * 8; // 2 EncodingRecords apontando ao mesmo subtable Format 4
    final bd = ByteData(headerLen + subtableLen);

    bd.setUint16(0, 0, Endian.big); // version
    bd.setUint16(2, 2, Endian.big); // numTables = 2
    // Record 0: Unicode BMP (platform 0, encoding 3)
    bd.setUint16(4, 0, Endian.big);
    bd.setUint16(6, 3, Endian.big);
    bd.setUint32(8, headerLen, Endian.big);
    // Record 1: Windows Unicode BMP (platform 3, encoding 1)
    bd.setUint16(12, 3, Endian.big);
    bd.setUint16(14, 1, Endian.big);
    bd.setUint32(16, headerLen, Endian.big);

    int o = headerLen;
    bd.setUint16(o, 4, Endian.big); // format 4
    bd.setUint16(o + 2, subtableLen, Endian.big);
    bd.setUint16(o + 4, 0, Endian.big); // language
    bd.setUint16(o + 6, segCount * 2, Endian.big);
    bd.setUint16(o + 8, searchRange, Endian.big);
    bd.setUint16(o + 10, entrySelector, Endian.big);
    bd.setUint16(o + 12, rangeShift, Endian.big);
    o += 14;

    for (final ec in endCodes) {
      bd.setUint16(o, ec, Endian.big);
      o += 2;
    }
    bd.setUint16(o, 0, Endian.big); // reservedPad
    o += 2;
    for (final sc in startCodes) {
      bd.setUint16(o, sc, Endian.big);
      o += 2;
    }
    for (final delta in idDeltas) {
      bd.setUint16(o, delta, Endian.big);
      o += 2;
    }
    for (int s = 0; s < segCount; s++) {
      bd.setUint16(o, 0, Endian.big); // idRangeOffset = 0
      o += 2;
    }

    return bd.buffer.asUint8List();
  }

  static Uint8List _buildNameTable(String familyName, {required bool bold}) {
    final subfamily = bold ? 'Bold' : 'Regular';
    final fullName = bold ? '$familyName Bold' : familyName;
    final psName = '${familyName.replaceAll(' ', '')}-$subfamily';
    final entries = <int, String>{
      0: 'Kairos Retro Pixel Bitmap Font',
      1: familyName,
      2: subfamily,
      3: 'Kairos-$psName-1.0',
      4: fullName,
      5: 'Version 1.0',
      6: psName,
    };

    final records = <_NameRecordData>[];
    final stringBlob = BytesBuilder(copy: false);

    // Adiciona registros Mac (platform 1) e Windows Unicode UTF-16BE (platform 3).
    for (final e in entries.entries) {
      final asciiBytes = latin1.encode(e.value);
      records.add(_NameRecordData(
        platformId: 1,
        encodingId: 0,
        languageId: 0,
        nameId: e.key,
        offset: stringBlob.length,
        bytes: Uint8List.fromList(asciiBytes),
      ));
      stringBlob.add(asciiBytes);
    }
    for (final e in entries.entries) {
      final utf16 = _encodeUtf16Be(e.value);
      records.add(_NameRecordData(
        platformId: 3,
        encodingId: 1,
        languageId: 0x0409,
        nameId: e.key,
        offset: stringBlob.length,
        bytes: utf16,
      ));
      stringBlob.add(utf16);
    }

    final headerSize = 6 + records.length * 12;
    final header = ByteData(headerSize);
    header.setUint16(0, 0, Endian.big); // format
    header.setUint16(2, records.length, Endian.big);
    header.setUint16(4, headerSize, Endian.big);

    int pos = 6;
    for (final rec in records) {
      header.setUint16(pos, rec.platformId, Endian.big);
      header.setUint16(pos + 2, rec.encodingId, Endian.big);
      header.setUint16(pos + 4, rec.languageId, Endian.big);
      header.setUint16(pos + 6, rec.nameId, Endian.big);
      header.setUint16(pos + 8, rec.bytes.length, Endian.big);
      header.setUint16(pos + 10, rec.offset, Endian.big);
      pos += 12;
    }

    final out = BytesBuilder(copy: false)
      ..add(header.buffer.asUint8List())
      ..add(stringBlob.toBytes());
    return out.toBytes();
  }

  static Uint8List _encodeUtf16Be(String text) {
    final bd = ByteData(text.length * 2);
    for (int i = 0; i < text.length; i++) {
      bd.setUint16(i * 2, text.codeUnitAt(i), Endian.big);
    }
    return bd.buffer.asUint8List();
  }

  static Uint8List _buildPostTable() {
    final bd = ByteData(32);
    bd.setUint32(0, 0x00030000, Endian.big); // format 3.0 (sem tabela de nomes extra)
    bd.setInt32(4, 0, Endian.big); // italicAngle
    bd.setInt16(8, -110, Endian.big); // underlinePosition
    bd.setInt16(10, 60, Endian.big); // underlineThickness
    bd.setUint32(12, 1, Endian.big); // isFixedPitch = 1 (monoespaçada)
    return bd.buffer.asUint8List();
  }

  static Uint8List _assembleSfnt(Map<String, Uint8List> tables) {
    final sortedTags = tables.keys.toList()..sort();
    final numTables = sortedTags.length;

    int searchRange = 16;
    int entrySelector = 0;
    while (searchRange * 2 <= numTables * 16) {
      searchRange *= 2;
      entrySelector++;
    }
    final rangeShift = numTables * 16 - searchRange;

    final dirSize = 12 + numTables * 16;
    int totalDataSize = 0;
    final offsets = <String, int>{};
    for (final tag in sortedTags) {
      offsets[tag] = dirSize + totalDataSize;
      final len = tables[tag]!.length;
      final padded = (len + 3) & ~3;
      totalDataSize += padded;
    }

    final fullBytes = Uint8List(dirSize + totalDataSize);
    final bd = ByteData.sublistView(fullBytes);
    bd.setUint32(0, 0x00010000, Endian.big); // TrueType sfntVersion
    bd.setUint16(4, numTables, Endian.big);
    bd.setUint16(6, searchRange, Endian.big);
    bd.setUint16(8, entrySelector, Endian.big);
    bd.setUint16(10, rangeShift, Endian.big);

    int dirPos = 12;
    for (final tag in sortedTags) {
      final tableData = tables[tag]!;
      final tableOffset = offsets[tag]!;
      fullBytes.setRange(tableOffset, tableOffset + tableData.length, tableData);

      final paddedLen = (tableData.length + 3) & ~3;
      final checksum = _computeTableChecksum(fullBytes, tableOffset, paddedLen);

      for (int k = 0; k < 4; k++) {
        bd.setUint8(dirPos + k, tag.codeUnitAt(k));
      }
      bd.setUint32(dirPos + 4, checksum, Endian.big);
      bd.setUint32(dirPos + 8, tableOffset, Endian.big);
      bd.setUint32(dirPos + 12, tableData.length, Endian.big);
      dirPos += 16;
    }

    // Calcula checkSumAdjustment no campo head+8
    final headOffset = offsets['head']!;
    final wholeChecksum = _computeTableChecksum(fullBytes, 0, fullBytes.length);
    final adjustment = (0xB1B0AFBA - wholeChecksum) & 0xFFFFFFFF;
    bd.setUint32(headOffset + 8, adjustment, Endian.big);

    return fullBytes;
  }

  static int _computeTableChecksum(Uint8List bytes, int start, int length) {
    final bd = ByteData.sublistView(bytes);
    int sum = 0;
    final end = start + length;
    for (int i = start; i + 4 <= end; i += 4) {
      sum = (sum + bd.getUint32(i, Endian.big)) & 0xFFFFFFFF;
    }
    return sum;
  }

  // --- Definições de glifos bitmap 7x13 (linha 9 = base) ---

  static Map<int, _PixelGlyph> _buildGlyphTable() {
    final map = <int, _PixelGlyph>{};

    _PixelGlyph make(int startRow, List<String> lines) {
      final rows = List<int>.filled(_totalRows, 0);
      for (int i = 0; i < lines.length && (startRow + i) < _totalRows; i++) {
        final idx = startRow + i;
        if (idx < 0) continue;
        final line = lines[i].padRight(7, '.');
        int mask = 0;
        for (int c = 0; c < 7; c++) {
          if (line[c] == '#') {
            mask |= (1 << (6 - c));
          }
        }
        rows[idx] = mask;
      }
      return _PixelGlyph(rows);
    }

    _PixelGlyph overlay(_PixelGlyph base, int accentRow, List<String> accent) {
      final rows = List<int>.from(base.rows);
      for (int i = 0; i < accent.length && (accentRow + i) < _totalRows; i++) {
        final idx = accentRow + i;
        if (idx < 0) continue;
        final line = accent[i].padRight(7, '.');
        int mask = 0;
        for (int c = 0; c < 7; c++) {
          if (line[c] == '#') {
            mask |= (1 << (6 - c));
          }
        }
        rows[idx] |= mask;
      }
      return _PixelGlyph(rows);
    }

    // .notdef (caixa vazada) e espaço
    map[0] = make(2, [
      '.#####.',
      '.#...#.',
      '.#...#.',
      '.#...#.',
      '.#...#.',
      '.#...#.',
      '.#...#.',
      '.#####.',
    ]);
    map[0x20] = _PixelGlyph(List<int>.filled(_totalRows, 0));
    map[0x00A0] = map[0x20]!;

    // Pontuação ASCII e símbolos de UI retrô
    map['!'.codeUnitAt(0)] = make(3, [
      '...#...',
      '...#...',
      '...#...',
      '...#...',
      '...#...',
      '.......',
      '...#...',
    ]);
    map['"'.codeUnitAt(0)] = make(3, [
      '..#.#..',
      '..#.#..',
      '..#.#..',
    ]);
    map['#'.codeUnitAt(0)] = make(3, [
      '.#...#.',
      '.#...#.',
      '#######',
      '.#...#.',
      '#######',
      '.#...#.',
      '.#...#.',
    ]);
    map[r'$'.codeUnitAt(0)] = make(3, [
      '...#...',
      '.#####.',
      '#..#...',
      '.#####.',
      '...#..#',
      '.#####.',
      '...#...',
    ]);
    map['%'.codeUnitAt(0)] = make(3, [
      '##....#',
      '##...#.',
      '....#..',
      '...#...',
      '..#....',
      '.#...##',
      '#....##',
    ]);
    map['&'.codeUnitAt(0)] = make(3, [
      '.###...',
      '#...#..',
      '.###...',
      '.#.#...',
      '#...#.#',
      '#....#.',
      '.####.#',
    ]);
    map["'".codeUnitAt(0)] = make(3, ['...#...', '...#...', '..#....']);
    map['('.codeUnitAt(0)] = make(3, [
      '....#..',
      '...#...',
      '..#....',
      '..#....',
      '..#....',
      '...#...',
      '....#..',
    ]);
    map[')'.codeUnitAt(0)] = make(3, [
      '..#....',
      '...#...',
      '....#..',
      '....#..',
      '....#..',
      '...#...',
      '..#....',
    ]);
    map['*'.codeUnitAt(0)] = make(4, [
      '.#.#.#.',
      '..###..',
      '#######',
      '..###..',
      '.#.#.#.',
    ]);
    map['+'.codeUnitAt(0)] = make(4, [
      '...#...',
      '...#...',
      '.#####.',
      '...#...',
      '...#...',
    ]);
    map[','.codeUnitAt(0)] = make(8, ['...#...', '...#...', '..#....']);
    map['-'.codeUnitAt(0)] = make(6, ['.#####.']);
    map['.'.codeUnitAt(0)] = make(8, ['..##...', '..##...']);
    map['/'.codeUnitAt(0)] = make(3, [
      '.....#.',
      '....#..',
      '...#...',
      '...#...',
      '..#....',
      '.#.....',
      '#......',
    ]);
    map[':'.codeUnitAt(0)] = make(5, ['..##...', '..##...', '.......', '..##...', '..##...']);
    map[';'.codeUnitAt(0)] = make(5, ['..##...', '..##...', '.......', '..##...', '..##...', '.#.....']);
    map['<'.codeUnitAt(0)] = make(4, [
      '....#..',
      '...#...',
      '..#....',
      '...#...',
      '....#..',
    ]);
    map['='.codeUnitAt(0)] = make(5, [
      '.#####.',
      '.......',
      '.#####.',
    ]);
    map['>'.codeUnitAt(0)] = make(4, [
      '..#....',
      '...#...',
      '....#..',
      '...#...',
      '..#....',
    ]);
    map['?'.codeUnitAt(0)] = make(3, [
      '.#####.',
      '#.....#',
      '.....#.',
      '...##..',
      '...#...',
      '.......',
      '...#...',
    ]);
    map['@'.codeUnitAt(0)] = make(3, [
      '.#####.',
      '#.....#',
      '#.####.',
      '#.#..##',
      '#.####.',
      '#......',
      '.#####.',
    ]);
    map['['.codeUnitAt(0)] = make(3, [
      '..###..',
      '..#....',
      '..#....',
      '..#....',
      '..#....',
      '..#....',
      '..###..',
    ]);
    map[r'\'.codeUnitAt(0)] = make(3, [
      '#......',
      '.#.....',
      '..#....',
      '...#...',
      '...#...',
      '....#..',
      '.....#.',
    ]);
    map[']'.codeUnitAt(0)] = make(3, [
      '..###..',
      '....#..',
      '....#..',
      '....#..',
      '....#..',
      '....#..',
      '..###..',
    ]);
    map['^'.codeUnitAt(0)] = make(2, ['...#...', '..#.#..', '.#...#.']);
    map['_'.codeUnitAt(0)] = make(9, ['#######']);
    map['`'.codeUnitAt(0)] = make(2, ['..#....', '...#...']);
    map['{'.codeUnitAt(0)] = make(3, [
      '...##..',
      '..#....',
      '..#....',
      '.#.....',
      '..#....',
      '..#....',
      '...##..',
    ]);
    map['|'.codeUnitAt(0)] = make(2, [
      '...#...',
      '...#...',
      '...#...',
      '...#...',
      '...#...',
      '...#...',
      '...#...',
      '...#...',
      '...#...',
    ]);
    map['}'.codeUnitAt(0)] = make(3, [
      '..##...',
      '....#..',
      '....#..',
      '.....#.',
      '....#..',
      '....#..',
      '..##...',
    ]);
    map['~'.codeUnitAt(0)] = make(3, ['.#.#...', '#.#.#..']);

    // Dígitos 0-9
    map['0'.codeUnitAt(0)] = make(3, [
      '.#####.',
      '#....##',
      '#...#.#',
      '#..#..#',
      '#.#...#',
      '##....#',
      '.#####.',
    ]);
    map['1'.codeUnitAt(0)] = make(3, [
      '...#...',
      '..##...',
      '.#.#...',
      '...#...',
      '...#...',
      '...#...',
      '.#####.',
    ]);
    map['2'.codeUnitAt(0)] = make(3, [
      '.#####.',
      '#.....#',
      '......#',
      '..####.',
      '.#.....',
      '#......',
      '#######',
    ]);
    map['3'.codeUnitAt(0)] = make(3, [
      '######.',
      '......#',
      '......#',
      '..####.',
      '......#',
      '#.....#',
      '.#####.',
    ]);
    map['4'.codeUnitAt(0)] = make(3, [
      '....##.',
      '...#.#.',
      '..#..#.',
      '.#...#.',
      '#######',
      '.....#.',
      '.....#.',
    ]);
    map['5'.codeUnitAt(0)] = make(3, [
      '#######',
      '#......',
      '######.',
      '......#',
      '......#',
      '#.....#',
      '.#####.',
    ]);
    map['6'.codeUnitAt(0)] = make(3, [
      '.#####.',
      '#.....#',
      '#......',
      '######.',
      '#.....#',
      '#.....#',
      '.#####.',
    ]);
    map['7'.codeUnitAt(0)] = make(3, [
      '#######',
      '......#',
      '.....#.',
      '....#..',
      '...#...',
      '...#...',
      '...#...',
    ]);
    map['8'.codeUnitAt(0)] = make(3, [
      '.#####.',
      '#.....#',
      '#.....#',
      '.#####.',
      '#.....#',
      '#.....#',
      '.#####.',
    ]);
    map['9'.codeUnitAt(0)] = make(3, [
      '.#####.',
      '#.....#',
      '#.....#',
      '.######',
      '......#',
      '#.....#',
      '.#####.',
    ]);

    // Maiúsculas A-Z
    map['A'.codeUnitAt(0)] = make(3, [
      '..###..',
      '.#...#.',
      '#.....#',
      '#######',
      '#.....#',
      '#.....#',
      '#.....#',
    ]);
    map['B'.codeUnitAt(0)] = make(3, [
      '######.',
      '#.....#',
      '#.....#',
      '######.',
      '#.....#',
      '#.....#',
      '######.',
    ]);
    map['C'.codeUnitAt(0)] = make(3, [
      '.#####.',
      '#.....#',
      '#......',
      '#......',
      '#......',
      '#.....#',
      '.#####.',
    ]);
    map['D'.codeUnitAt(0)] = make(3, [
      '#####..',
      '#....#.',
      '#.....#',
      '#.....#',
      '#.....#',
      '#....#.',
      '#####..',
    ]);
    map['E'.codeUnitAt(0)] = make(3, [
      '#######',
      '#......',
      '#......',
      '#####..',
      '#......',
      '#......',
      '#######',
    ]);
    map['F'.codeUnitAt(0)] = make(3, [
      '#######',
      '#......',
      '#......',
      '#####..',
      '#......',
      '#......',
      '#......',
    ]);
    map['G'.codeUnitAt(0)] = make(3, [
      '.#####.',
      '#.....#',
      '#......',
      '#..####',
      '#.....#',
      '#.....#',
      '.#####.',
    ]);
    map['H'.codeUnitAt(0)] = make(3, [
      '#.....#',
      '#.....#',
      '#.....#',
      '#######',
      '#.....#',
      '#.....#',
      '#.....#',
    ]);
    map['I'.codeUnitAt(0)] = make(3, [
      '.#####.',
      '...#...',
      '...#...',
      '...#...',
      '...#...',
      '...#...',
      '.#####.',
    ]);
    map['J'.codeUnitAt(0)] = make(3, [
      '..#####',
      '.....#.',
      '.....#.',
      '.....#.',
      '#....#.',
      '#....#.',
      '.####..',
    ]);
    map['K'.codeUnitAt(0)] = make(3, [
      '#....#.',
      '#...#..',
      '#..#...',
      '###....',
      '#..#...',
      '#...#..',
      '#....#.',
    ]);
    map['L'.codeUnitAt(0)] = make(3, [
      '#......',
      '#......',
      '#......',
      '#......',
      '#......',
      '#......',
      '#######',
    ]);
    map['M'.codeUnitAt(0)] = make(3, [
      '#.....#',
      '##...##',
      '#.#.#.#',
      '#..#..#',
      '#.....#',
      '#.....#',
      '#.....#',
    ]);
    map['N'.codeUnitAt(0)] = make(3, [
      '#.....#',
      '##....#',
      '#.#...#',
      '#..#..#',
      '#...#.#',
      '#....##',
      '#.....#',
    ]);
    map['O'.codeUnitAt(0)] = make(3, [
      '.#####.',
      '#.....#',
      '#.....#',
      '#.....#',
      '#.....#',
      '#.....#',
      '.#####.',
    ]);
    map['P'.codeUnitAt(0)] = make(3, [
      '######.',
      '#.....#',
      '#.....#',
      '######.',
      '#......',
      '#......',
      '#......',
    ]);
    map['Q'.codeUnitAt(0)] = make(3, [
      '.#####.',
      '#.....#',
      '#.....#',
      '#.....#',
      '#..#..#',
      '#...#.#',
      '.#####.',
      '......#',
    ]);
    map['R'.codeUnitAt(0)] = make(3, [
      '######.',
      '#.....#',
      '#.....#',
      '######.',
      '#...#..',
      '#....#.',
      '#.....#',
    ]);
    map['S'.codeUnitAt(0)] = make(3, [
      '.#####.',
      '#.....#',
      '#......',
      '.#####.',
      '......#',
      '#.....#',
      '.#####.',
    ]);
    map['T'.codeUnitAt(0)] = make(3, [
      '#######',
      '...#...',
      '...#...',
      '...#...',
      '...#...',
      '...#...',
      '...#...',
    ]);
    map['U'.codeUnitAt(0)] = make(3, [
      '#.....#',
      '#.....#',
      '#.....#',
      '#.....#',
      '#.....#',
      '#.....#',
      '.#####.',
    ]);
    map['V'.codeUnitAt(0)] = make(3, [
      '#.....#',
      '#.....#',
      '#.....#',
      '#.....#',
      '.#...#.',
      '..#.#..',
      '...#...',
    ]);
    map['W'.codeUnitAt(0)] = make(3, [
      '#.....#',
      '#.....#',
      '#.....#',
      '#..#..#',
      '#.#.#.#',
      '##...##',
      '#.....#',
    ]);
    map['X'.codeUnitAt(0)] = make(3, [
      '#.....#',
      '.#...#.',
      '..#.#..',
      '...#...',
      '..#.#..',
      '.#...#.',
      '#.....#',
    ]);
    map['Y'.codeUnitAt(0)] = make(3, [
      '#.....#',
      '.#...#.',
      '..#.#..',
      '...#...',
      '...#...',
      '...#...',
      '...#...',
    ]);
    map['Z'.codeUnitAt(0)] = make(3, [
      '#######',
      '.....#.',
      '....#..',
      '...#...',
      '..#....',
      '.#.....',
      '#######',
    ]);

    // Minúsculas a-z (x-height 5..9, ascendentes 3..9, descendentes 5..11)
    map['a'.codeUnitAt(0)] = make(5, [
      '.#####.',
      '......#',
      '.######',
      '#.....#',
      '.######',
    ]);
    map['b'.codeUnitAt(0)] = make(3, [
      '#......',
      '#......',
      '######.',
      '#.....#',
      '#.....#',
      '#.....#',
      '######.',
    ]);
    map['c'.codeUnitAt(0)] = make(5, [
      '.#####.',
      '#.....#',
      '#......',
      '#.....#',
      '.#####.',
    ]);
    map['d'.codeUnitAt(0)] = make(3, [
      '......#',
      '......#',
      '.######',
      '#.....#',
      '#.....#',
      '#.....#',
      '.######',
    ]);
    map['e'.codeUnitAt(0)] = make(5, [
      '.#####.',
      '#.....#',
      '#######',
      '#......',
      '.#####.',
    ]);
    map['f'.codeUnitAt(0)] = make(3, [
      '...###.',
      '..#...#',
      '..#....',
      '#####..',
      '..#....',
      '..#....',
      '..#....',
    ]);
    map['g'.codeUnitAt(0)] = make(5, [
      '.######',
      '#.....#',
      '#.....#',
      '.######',
      '......#',
      '#.....#',
      '.#####.',
    ]);
    map['h'.codeUnitAt(0)] = make(3, [
      '#......',
      '#......',
      '######.',
      '#.....#',
      '#.....#',
      '#.....#',
      '#.....#',
    ]);
    map['i'.codeUnitAt(0)] = make(3, [
      '...#...',
      '.......',
      '..##...',
      '...#...',
      '...#...',
      '...#...',
      '.#####.',
    ]);
    final iBase = make(5, [
      '..##...',
      '...#...',
      '...#...',
      '...#...',
      '.#####.',
    ]);
    map['j'.codeUnitAt(0)] = make(3, [
      '....#..',
      '.......',
      '...##..',
      '....#..',
      '....#..',
      '....#..',
      '....#..',
      '#...#..',
      '.###...',
    ]);
    map['k'.codeUnitAt(0)] = make(3, [
      '#......',
      '#......',
      '#...#..',
      '#..#...',
      '###....',
      '#..#...',
      '#...#..',
    ]);
    map['l'.codeUnitAt(0)] = make(3, [
      '..##...',
      '...#...',
      '...#...',
      '...#...',
      '...#...',
      '...#...',
      '.#####.',
    ]);
    map['m'.codeUnitAt(0)] = make(5, [
      '##.#.#.',
      '#.#.#.#',
      '#.#.#.#',
      '#.....#',
      '#.....#',
    ]);
    map['n'.codeUnitAt(0)] = make(5, [
      '######.',
      '#.....#',
      '#.....#',
      '#.....#',
      '#.....#',
    ]);
    map['o'.codeUnitAt(0)] = make(5, [
      '.#####.',
      '#.....#',
      '#.....#',
      '#.....#',
      '.#####.',
    ]);
    map['p'.codeUnitAt(0)] = make(5, [
      '######.',
      '#.....#',
      '#.....#',
      '######.',
      '#......',
      '#......',
      '#......',
    ]);
    map['q'.codeUnitAt(0)] = make(5, [
      '.######',
      '#.....#',
      '#.....#',
      '.######',
      '......#',
      '......#',
      '......#',
    ]);
    map['r'.codeUnitAt(0)] = make(5, [
      '#.##...',
      '##..#..',
      '#......',
      '#......',
      '#......',
    ]);
    map['s'.codeUnitAt(0)] = make(5, [
      '.######',
      '#......',
      '.#####.',
      '......#',
      '######.',
    ]);
    map['t'.codeUnitAt(0)] = make(3, [
      '..#....',
      '..#....',
      '#####..',
      '..#....',
      '..#....',
      '..#...#',
      '...###.',
    ]);
    map['u'.codeUnitAt(0)] = make(5, [
      '#.....#',
      '#.....#',
      '#.....#',
      '#....##',
      '.####.#',
    ]);
    map['v'.codeUnitAt(0)] = make(5, [
      '#.....#',
      '#.....#',
      '.#...#.',
      '..#.#..',
      '...#...',
    ]);
    map['w'.codeUnitAt(0)] = make(5, [
      '#.....#',
      '#.....#',
      '#..#..#',
      '#.#.#.#',
      '.#...#.',
    ]);
    map['x'.codeUnitAt(0)] = make(5, [
      '#.....#',
      '.#...#.',
      '...#...',
      '.#...#.',
      '#.....#',
    ]);
    map['y'.codeUnitAt(0)] = make(5, [
      '#.....#',
      '#.....#',
      '#.....#',
      '.######',
      '......#',
      '#.....#',
      '.#####.',
    ]);
    map['z'.codeUnitAt(0)] = make(5, [
      '#######',
      '....#..',
      '...#...',
      '..#....',
      '#######',
    ]);

    // Sinais diacríticos para acentuação portuguesa/latina completa
    const acute = ['....#..', '...#...'];
    const grave = ['..#....', '...#...'];
    const circumflex = ['...#...', '..#.#..'];
    const tilde = ['.#.#...', '#.#.#..'];
    const umlaut = ['..#.#..'];
    const cedilla = ['...#...', '..##...'];

    void addAccentedPair(int upperCp, int baseUpper, int lowerCp, int baseLower, List<String> accent, {bool lowerDotlessI = false}) {
      map[upperCp] = overlay(map[baseUpper]!, 0, accent);
      final lowerBase = lowerDotlessI ? iBase : map[baseLower]!;
      map[lowerCp] = overlay(lowerBase, 2, accent);
    }

    addAccentedPair(0x00C0, 0x41, 0x00E0, 0x61, grave); // À à
    addAccentedPair(0x00C1, 0x41, 0x00E1, 0x61, acute); // Á á
    addAccentedPair(0x00C2, 0x41, 0x00E2, 0x61, circumflex); // Â â
    addAccentedPair(0x00C3, 0x41, 0x00E3, 0x61, tilde); // Ã ã
    addAccentedPair(0x00C4, 0x41, 0x00E4, 0x61, umlaut); // Ä ä
    map[0x00C7] = overlay(map[0x43]!, 10, cedilla); // Ç
    map[0x00E7] = overlay(map[0x63]!, 10, cedilla); // ç
    addAccentedPair(0x00C8, 0x45, 0x00E8, 0x65, grave); // È è
    addAccentedPair(0x00C9, 0x45, 0x00E9, 0x65, acute); // É é
    addAccentedPair(0x00CA, 0x45, 0x00EA, 0x65, circumflex); // Ê ê
    addAccentedPair(0x00CB, 0x45, 0x00EB, 0x65, umlaut); // Ë ë
    addAccentedPair(0x00CC, 0x49, 0x00EC, 0x69, grave, lowerDotlessI: true); // Ì ì
    addAccentedPair(0x00CD, 0x49, 0x00ED, 0x69, acute, lowerDotlessI: true); // Í í
    addAccentedPair(0x00CE, 0x49, 0x00EE, 0x69, circumflex, lowerDotlessI: true); // Î î
    addAccentedPair(0x00CF, 0x49, 0x00EF, 0x69, umlaut, lowerDotlessI: true); // Ï ï
    addAccentedPair(0x00D1, 0x4E, 0x00F1, 0x6E, tilde); // Ñ ñ
    addAccentedPair(0x00D2, 0x4F, 0x00F2, 0x6F, grave); // Ò ò
    addAccentedPair(0x00D3, 0x4F, 0x00F3, 0x6F, acute); // Ó ó
    addAccentedPair(0x00D4, 0x4F, 0x00F4, 0x6F, circumflex); // Ô ô
    addAccentedPair(0x00D5, 0x4F, 0x00F5, 0x6F, tilde); // Õ õ
    addAccentedPair(0x00D6, 0x4F, 0x00F6, 0x6F, umlaut); // Ö ö
    addAccentedPair(0x00D9, 0x55, 0x00F9, 0x75, grave); // Ù ù
    addAccentedPair(0x00DA, 0x55, 0x00FA, 0x75, acute); // Ú ú
    addAccentedPair(0x00DB, 0x55, 0x00FB, 0x75, circumflex); // Û û
    addAccentedPair(0x00DC, 0x55, 0x00FC, 0x75, umlaut); // Ü ü

    // Pontuação tipográfica e símbolos extras úteis em textos em PT
    map[0x00AA] = make(3, ['.###...', '....#..', '.####..', '#...#..', '.####..']); // ª
    map[0x00BA] = make(3, ['..###..', '.#...#.', '.#...#.', '..###..']); // º
    map[0x00B0] = map[0x00BA]!; // °
    map[0x00AB] = make(5, ['.#..#..', '#..#...', '.#..#..']); // «
    map[0x00BB] = make(5, ['.#..#..', '..#..#.', '.#..#..']); // »
    map[0x2013] = make(6, ['.#####.']); // –
    map[0x2014] = make(6, ['#######']); // —
    map[0x2018] = map["'".codeUnitAt(0)]!; // ‘
    map[0x2019] = map["'".codeUnitAt(0)]!; // ’
    map[0x201C] = map['"'.codeUnitAt(0)]!; // “
    map[0x201D] = map['"'.codeUnitAt(0)]!; // ”
    map[0x2022] = make(5, ['.......', '..###..', '..###..', '..###..']); // •
    map[0x2026] = make(8, ['#.#.#..', '#.#.#..']); // …
    map[0x2713] = make(4, ['......#', '.....#.', '#...#..', '.#.#...', '..#....']); // ✓

    // Box drawing básico usado nos cards/bordas ASCII
    map[0x2554] = make(4, ['..#####', '..#....', '..#.###', '..#.#..', '..#.#..']); // ╔
    map[0x2557] = make(4, ['#####..', '....#..', '###.#..', '..#.#..', '..#.#..']); // ╗
    map[0x255A] = make(4, ['..#.#..', '..#.#..', '..#.###', '..#....', '..#####']); // ╚
    map[0x255D] = make(4, ['..#.#..', '..#.#..', '###.#..', '....#..', '#####..']); // ╝

    return map;
  }
}

class _PixelGlyph {
  final List<int> rows;
  const _PixelGlyph(this.rows);
}

class _GlyphRect {
  final int xMin;
  final int yMin;
  final int xMax;
  final int yMax;
  const _GlyphRect(this.xMin, this.yMin, this.xMax, this.yMax);
}

class _GlyfBuildResult {
  final Uint8List glyf;
  final Uint8List loca;
  final List<int> lsbs;
  final int xMin;
  final int yMin;
  final int xMax;
  final int yMax;
  final int minLsb;
  final int minRsb;
  final int xMaxExtent;
  final int maxPoints;
  final int maxContours;

  const _GlyfBuildResult({
    required this.glyf,
    required this.loca,
    required this.lsbs,
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
    required this.minLsb,
    required this.minRsb,
    required this.xMaxExtent,
    required this.maxPoints,
    required this.maxContours,
  });
}

class _NameRecordData {
  final int platformId;
  final int encodingId;
  final int languageId;
  final int nameId;
  final int offset;
  final Uint8List bytes;

  const _NameRecordData({
    required this.platformId,
    required this.encodingId,
    required this.languageId,
    required this.nameId,
    required this.offset,
    required this.bytes,
  });
}
