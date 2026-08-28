import 'package:flutter_test/flutter_test.dart';

import 'package:diet_app2/ui/theme/mood_palette.dart';

void main() {
  group('MoodPalette.moodFor', () {
    test('assigns the four progress bands', () {
      expect(MoodPalette.moodFor(.29), DayMood.fresh);
      expect(MoodPalette.moodFor(.30), DayMood.building);
      expect(MoodPalette.moodFor(.95), DayMood.bloom);
      expect(MoodPalette.moodFor(1.06), DayMood.over);
    });

    test('holds the prior state within hysteresis bands', () {
      expect(
        MoodPalette.moodFor(.31, previous: DayMood.fresh),
        DayMood.fresh,
      );
      expect(
        MoodPalette.moodFor(.29, previous: DayMood.building),
        DayMood.building,
      );
      expect(
        MoodPalette.moodFor(.93, previous: DayMood.bloom),
        DayMood.bloom,
      );
      expect(
        MoodPalette.moodFor(1.04, previous: DayMood.over),
        DayMood.over,
      );
    });
  });
}
