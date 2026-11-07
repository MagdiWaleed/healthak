import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/training/exercise.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/exercise_guides.dart';
import '../../ui/glass/glass_sheet.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/motion_settings.dart';
import 'equipment_sheet.dart';

/// Bundled start/end photos (see asset/exercises/SOURCE.txt). Not every
/// exercise has them; [hasPhotos] lists the ones that do.
const _noPhotos = {'pike_push_up', 'burpee'};
bool hasPhotos(String exerciseId) =>
    exerciseById(exerciseId) != null && !_noPhotos.contains(exerciseId);
String photoPath(String exerciseId, int frame) =>
    'asset/exercises/${exerciseId}_$frame.jpg';

/// A YouTube search for the exercise's English name, so the user gets a
/// current form video without the app bundling or hosting any.
Uri videoSearchUri(Exercise exercise) {
  final name =
      exercise.aliasesEn.isNotEmpty ? exercise.aliasesEn.first : exercise.id;
  return Uri.https('www.youtube.com', '/results',
      {'search_query': '$name exercise proper form'});
}

/// "How to do it": alternating start/end photo, three steps, one tip, and a
/// button to watch a video.
class ExerciseGuideSheet extends StatelessWidget {
  const ExerciseGuideSheet({required this.exerciseId, this.nameAr, super.key});
  final String exerciseId;
  final String? nameAr;

  /// Does nothing for custom exercises (no guide, no photos).
  static Future<void> show(BuildContext context, String exerciseId,
      {String? nameAr}) async {
    if (exerciseById(exerciseId) == null) return;
    await GlassSheet.show<void>(context,
        builder: (_) =>
            ExerciseGuideSheet(exerciseId: exerciseId, nameAr: nameAr));
  }

  @override
  Widget build(BuildContext context) {
    final exercise = exerciseById(exerciseId)!;
    final guide = kExerciseGuides[exerciseId];
    return GlassSheet(
      title: nameAr ?? exercise.nameAr,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .78),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
                '${muscleLabelAr(exercise.muscle)} · ${needsLabel(exercise.needs)}',
                style: const TextStyle(color: AppPalette.muted)),
            const SizedBox(height: 12),
            if (hasPhotos(exerciseId)) _AlternatingPhoto(exerciseId),
            if (guide != null) ...[
              const SizedBox(height: 16),
              const Text(AppStrings.howToDoIt,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              for (var i = 0; i < guide.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor:
                              AppPalette.emerald.withValues(alpha: .18),
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  color: AppPalette.emerald,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(guide.steps[i])),
                      ]),
                ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppPalette.amber.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  const Icon(Icons.lightbulb_outline,
                      color: AppPalette.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(guide.tip)),
                ]),
              ),
            ],
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => launchUrl(videoSearchUri(exercise),
                  mode: LaunchMode.externalApplication),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: const StadiumBorder()),
              icon: const Icon(Icons.play_circle_outline),
              label: const Text(AppStrings.watchVideo),
            ),
          ],
        ),
      ),
    );
  }
}

/// Start and end position, cross-fading like a slow GIF. Reduced motion
/// shows both frames side by side instead.
class _AlternatingPhoto extends StatefulWidget {
  const _AlternatingPhoto(this.exerciseId);
  final String exerciseId;
  @override
  State<_AlternatingPhoto> createState() => _AlternatingPhotoState();
}

class _AlternatingPhotoState extends State<_AlternatingPhoto> {
  int frame = 0;
  Timer? timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    timer?.cancel();
    if (MotionSettings.enabled(context)) {
      timer = Timer.periodic(const Duration(milliseconds: 1100),
          (_) => setState(() => frame = 1 - frame));
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Widget _image(int f) => Image.asset(photoPath(widget.exerciseId, f),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const SizedBox.shrink());

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 3 / 2,
          child: MotionSettings.enabled(context)
              ? AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child:
                      KeyedSubtree(key: ValueKey(frame), child: _image(frame)))
              : Row(children: [
                  Expanded(child: _image(0)),
                  const SizedBox(width: 2),
                  Expanded(child: _image(1)),
                ]),
        ),
      );
}
