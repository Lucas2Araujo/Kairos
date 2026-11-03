import 'dart:convert';
import 'dart:typed_data';

/// Gerador minimalista em puro Dart de planilhas OpenXML (.xlsx) compatíveis
/// nativamente com Excel, Google Sheets e LibreOffice Calc (Filosofia Ponytail:
/// zero dependências externas).
class XlsxBuilder {
  const XlsxBuilder._();

  static const String mimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  /// Gera os bytes binários de um arquivo `.xlsx` válido contendo metadados opcionais,
  /// linha de cabeçalho estilizada e linhas tipadas (números vs textos).
  static Uint8List buildWorkbook({
    required String sheetName,
    required List<String> headers,
    required List<List<Object?>> rows,
    List<String> metadataLines = const [],
  }) {
    final safeSheetName = _sanitizeSheetName(sheetName);
    final entries = <_ZipEntry>[
      _ZipEntry('[Content_Types].xml', utf8.encode(_contentTypesXml)),
      _ZipEntry('_rels/.rels', utf8.encode(_rootRelsXml)),
      _ZipEntry('xl/workbook.xml', utf8.encode(_buildWorkbookXml(safeSheetName))),
      _ZipEntry('xl/_rels/workbook.xml.rels', utf8.encode(_workbookRelsXml)),
      _ZipEntry('xl/styles.xml', utf8.encode(_stylesXml)),
      _ZipEntry(
        'xl/worksheets/sheet1.xml',
        utf8.encode(
          _buildSheetXml(
            headers: headers,
            rows: rows,
            metadataLines: metadataLines,
          ),
        ),
      ),
    ];

    return _encodeZipStore(entries);
  }

  static String _sanitizeSheetName(String input) {
    final cleaned = input.replaceAll(RegExp(r'[\[\]\*\?\/\\:]'), ' ').trim();
    if (cleaned.isEmpty) return 'Relatorio Kairos';
    return cleaned.length > 31 ? cleaned.substring(0, 31) : cleaned;
  }

  static String _xmlEscape(String text) {
    final clean = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
    return clean
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _colLetter(int zeroBasedCol) {
    var col = zeroBasedCol + 1;
    final sb = StringBuffer();
    while (col > 0) {
      final rem = (col - 1) % 26;
      sb.writeCharCode(65 + rem);
      col = (col - 1) ~/ 26;
    }
    return sb.toString().split('').reversed.join();
  }

  static String _buildSheetXml({
    required List<String> headers,
    required List<List<Object?>> rows,
    required List<String> metadataLines,
  }) {
    final sb = StringBuffer();
    sb.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sb.write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');

    if (headers.isNotEmpty) {
      sb.write('<cols>');
      for (int c = 0; c < headers.length; c++) {
        final width = c == 1 || c >= headers.length - 3 ? 28 : 16;
        sb.write('<col min="${c + 1}" max="${c + 1}" width="$width" customWidth="1"/>');
      }
      sb.write('</cols>');
    }

    sb.write('<sheetData>');
    int rowNum = 1;

    for (final line in metadataLines) {
      sb.write('<row r="$rowNum">');
      final ref = 'A$rowNum';
      final styleIdx = rowNum == 1 ? 2 : 0;
      sb.write('<c r="$ref" t="inlineStr" s="$styleIdx"><is><t>${_xmlEscape(line)}</t></is></c>');
      sb.write('</row>');
      rowNum++;
    }

    if (metadataLines.isNotEmpty) {
      sb.write('<row r="$rowNum"/>');
      rowNum++;
    }

    // Cabeçalho da tabela (style s="1": fundo roxo Kairós + texto branco em negrito)
    sb.write('<row r="$rowNum">');
    for (int c = 0; c < headers.length; c++) {
      final ref = '${_colLetter(c)}$rowNum';
      sb.write('<c r="$ref" t="inlineStr" s="1"><is><t>${_xmlEscape(headers[c])}</t></is></c>');
    }
    sb.write('</row>');
    rowNum++;

    // Dados
    for (final row in rows) {
      sb.write('<row r="$rowNum">');
      for (int c = 0; c < row.length; c++) {
        final ref = '${_colLetter(c)}$rowNum';
        final val = row[c];
        if (val == null) {
          sb.write('<c r="$ref" t="inlineStr"><is><t></t></is></c>');
        } else if (val is num && val.isFinite) {
          sb.write('<c r="$ref"><v>$val</v></c>');
        } else {
          sb.write('<c r="$ref" t="inlineStr"><is><t>${_xmlEscape(val.toString())}</t></is></c>');
        }
      }
      sb.write('</row>');
      rowNum++;
    }

    sb.write('</sheetData></worksheet>');
    return sb.toString();
  }

  static String _buildWorkbookXml(String sheetName) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets><sheet name="${_xmlEscape(sheetName)}" sheetId="1" r:id="rId1"/></sheets>'
      '</workbook>';

  static const String _contentTypesXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '</Types>';

  static const String _rootRelsXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';

  static const String _workbookRelsXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '</Relationships>';

  static const String _stylesXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<fonts count="3">'
      '<font><sz val="11"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>'
      '<font><b/><sz val="13"/><color rgb="FF381E72"/><name val="Calibri"/></font>'
      '</fonts>'
      '<fills count="3">'
      '<fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FF4A148C"/><bgColor indexed="64"/></patternFill></fill>'
      '</fills>'
      '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="3">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>'
      '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      '</cellXfs>'
      '</styleSheet>';

  static final List<int> _crcTable = List<int>.generate(256, (n) {
    int c = n;
    for (int k = 0; k < 8; k++) {
      c = ((c & 1) != 0) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
    }
    return c;
  });

  static int _crc32(List<int> bytes) {
    int crc = 0xFFFFFFFF;
    for (final b in bytes) {
      crc = _crcTable[(crc ^ b) & 0xFF] ^ (crc >>> 8);
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  static Uint8List _encodeZipStore(List<_ZipEntry> entries) {
    final out = BytesBuilder(copy: false);
    final centralDir = BytesBuilder(copy: false);
    int offset = 0;

    for (final entry in entries) {
      final nameBytes = utf8.encode(entry.path);
      final dataBytes = entry.bytes;
      final crc = _crc32(dataBytes);
      final size = dataBytes.length;

      final localHeader = ByteData(30 + nameBytes.length);
      localHeader.setUint32(0, 0x04034b50, Endian.little);
      localHeader.setUint16(4, 20, Endian.little);
      localHeader.setUint16(6, 0x0800, Endian.little); // UTF-8
      localHeader.setUint16(8, 0, Endian.little); // STORE
      localHeader.setUint16(10, 0, Endian.little);
      localHeader.setUint16(12, 0x21, Endian.little);
      localHeader.setUint32(14, crc, Endian.little);
      localHeader.setUint32(18, size, Endian.little);
      localHeader.setUint32(22, size, Endian.little);
      localHeader.setUint16(26, nameBytes.length, Endian.little);
      localHeader.setUint16(28, 0, Endian.little);
      for (int i = 0; i < nameBytes.length; i++) {
        localHeader.setUint8(30 + i, nameBytes[i]);
      }

      final localHeaderBytes = localHeader.buffer.asUint8List();
      out.add(localHeaderBytes);
      out.add(dataBytes);

      final cdHeader = ByteData(46 + nameBytes.length);
      cdHeader.setUint32(0, 0x02014b50, Endian.little);
      cdHeader.setUint16(4, 20, Endian.little);
      cdHeader.setUint16(6, 20, Endian.little);
      cdHeader.setUint16(8, 0x0800, Endian.little);
      cdHeader.setUint16(10, 0, Endian.little);
      cdHeader.setUint16(12, 0, Endian.little);
      cdHeader.setUint16(14, 0x21, Endian.little);
      cdHeader.setUint32(16, crc, Endian.little);
      cdHeader.setUint32(20, size, Endian.little);
      cdHeader.setUint32(24, size, Endian.little);
      cdHeader.setUint16(28, nameBytes.length, Endian.little);
      cdHeader.setUint16(30, 0, Endian.little);
      cdHeader.setUint16(32, 0, Endian.little);
      cdHeader.setUint16(34, 0, Endian.little);
      cdHeader.setUint16(36, 0, Endian.little);
      cdHeader.setUint32(38, 0, Endian.little);
      cdHeader.setUint32(42, offset, Endian.little);
      for (int i = 0; i < nameBytes.length; i++) {
        cdHeader.setUint8(46 + i, nameBytes[i]);
      }
      centralDir.add(cdHeader.buffer.asUint8List());

      offset += localHeaderBytes.length + size;
    }

    final cdBytes = centralDir.toBytes();
    out.add(cdBytes);

    final eocd = ByteData(22);
    eocd.setUint32(0, 0x06054b50, Endian.little);
    eocd.setUint16(4, 0, Endian.little);
    eocd.setUint16(6, 0, Endian.little);
    eocd.setUint16(8, entries.length, Endian.little);
    eocd.setUint16(10, entries.length, Endian.little);
    eocd.setUint32(12, cdBytes.length, Endian.little);
    eocd.setUint32(16, offset, Endian.little);
    eocd.setUint16(20, 0, Endian.little);
    out.add(eocd.buffer.asUint8List());

    return out.toBytes();
  }
}

class _ZipEntry {
  final String path;
  final List<int> bytes;
  const _ZipEntry(this.path, this.bytes);
}
