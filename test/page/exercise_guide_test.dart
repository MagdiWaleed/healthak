import 'dart:io';

import 'package:diet_app2/domain/training/exercise.dart';
import 'package:diet_app2/l10n/app_strings.dart';
import 'package:diet_app2/l10n/exercise_guides.dart';
import 'package:diet_app2/page/training/exercise_guide_sheet.dart';
import 'package:diet_app2/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every library exercise has a guide with 3 steps and a tip', () {
    for (final e in kExerciseLibrary) {
      final g = kExerciseGuides[e.id];
      expect(g, isNotNull, reason: e.id);
      expect(g!.steps, hasLength(3), reason: e.id);
      expect(g.tip, isNotEmpty, reason: e.id);
    }
  });

  test('every exercise with photos has both frames bundled', () {
    for (final e in kExerciseLibrary.where((e) => hasPhotos(e.id))) {
      for (final f in [0, 1]) {
        expect(File(photoPath(e.id, f)).existsSync(), isTrue,
            reason: photoPath(e.id, f));
      }
    }
  });

  test('video link is a YouTube search over https', () {
    final uri = videoSearchUri(exerciseById('pull_up')!);
    expect(uri.scheme, 'https');
    expect(uri.host, 'www.youtube.com');
    expect(uri.queryParameters['search_query'], contains('pull up'));
  });

  testWidgets('guide sheet shows steps, tip and video button', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
            builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: const Scaffold(
                    body: ExerciseGuideSheet(exerciseId: 'pull_up'))))));
    await tester.pump();
    final g = kExerciseGuides['pull_up']!;
    expect(find.text(AppStrings.howToDoIt), findsOneWidget);
    expect(find.text(g.steps.first), findsOneWidget);
    expect(find.text(g.tip), findsOneWidget);
    expect(find.text(AppStrings.watchVideo), findsOneWidget);
    // Reduced motion: both frames side by side, no timer.
    expect(find.byType(Image), findsNWidgets(2));
  });
}
