import 'package:flutter_test/flutter_test.dart';
import 'package:streaming_mobile/shared/molecules/custom_video_player.dart';

void main() {
  group('CustomVideoPlayer VTT Parser Unit Tests', () {
    test('Should parse standard WebVTT subtitles correctly', () {
      const vttData = '''WEBVTT

1
00:00:01.000 --> 00:00:03.500
Halo, ini adalah subtitle pertama.

2
00:00:04.100 --> 00:00:07.000
Halo, ini adalah subtitle kedua dengan
dua baris teks.
''';

      final parsed = CustomVideoPlayer.parseVtt(vttData);

      expect(parsed.length, equals(2));
      
      // Test first subtitle
      expect(parsed[0].start.inMilliseconds, equals(1000));
      expect(parsed[0].end.inMilliseconds, equals(3500));
      expect(parsed[0].text, equals('Halo, ini adalah subtitle pertama.'));

      // Test second subtitle
      expect(parsed[1].start.inMilliseconds, equals(4100));
      expect(parsed[1].end.inMilliseconds, equals(7000));
      expect(parsed[1].text, equals('Halo, ini adalah subtitle kedua dengan\ndua baris teks.'));
    });

    test('Should handle invalid VTT format gracefully without crashing', () {
      const invalidVtt = '''INVALID HEADER
not-a-timestamp --> definitely-not-a-timestamp
Broken content
''';

      final parsed = CustomVideoPlayer.parseVtt(invalidVtt);
      expect(parsed, isEmpty);
    });
  });
}
