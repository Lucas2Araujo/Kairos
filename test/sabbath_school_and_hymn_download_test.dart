import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/core/database/database_manager.dart';
import 'package:kairos_web/data/services/sabbath_school_service.dart';
import 'package:kairos_web/services/hymn_batch_download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers.global'),
    (call) async => null,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers'),
    (call) async => null,
  );

  group('SabbathSchool Image & Download Features', () {
    test('extractImageUrls parses markdown image tags and normalizes url', () {
      const markdown = '''
# Lição 1
Texto introdutório.
![tirinha](https://sabbath-school.adventech.io/api/v2/pt/quarterlies/2026-01-cq/lessons/01/days/1/image.png)
Mais texto.
![outro](https://exemplo.com/imagem.png)
''';

      final urls = SabbathSchoolService.extractImageUrls(markdown);
      expect(urls.length, 2);
      expect(urls[0], 'https://sabbath-school.adventech.io/api/v2/pt/quarterlies/2026-01-cq/lessons/01/days/image.png');
      expect(urls[1], 'https://exemplo.com/imagem.png');
    });

    test('ss_images_cache is listed in userPreservedTables', () {
      expect(userPreservedTables.contains('ss_images_cache'), isTrue);
    });
  });

  group('HymnBatchDownloadService Tests', () {
    test('initial state and cancellation work correctly', () {
      final service = HymnBatchDownloadService();
      expect(service.isRunning, isFalse);
      expect(service.progress, 0.0);

      service.cancel();
      expect(service.isRunning, isFalse);
    });

    test('empty list does not start batch', () async {
      final service = HymnBatchDownloadService();
      await service.startBatch(hymns: [], edition: 'novo');
      expect(service.isRunning, isFalse);
      expect(service.total, 0);
    });
  });
}
