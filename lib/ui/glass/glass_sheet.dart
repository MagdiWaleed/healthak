import 'package:flutter/material.dart';

import '../feedback/haptics.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/glass_tokens.dart';
import 'glass_decoration.dart';
import 'specular_border.dart';

/// The one bottom-sheet vocabulary in the app.
///
/// Every `showModalBottomSheet` call renders its content through this now,
/// instead of each sheet hand-rolling its own `DecoratedBox(color: ...)`
/// chrome. Deliberately flat, never [GlassSurface]: a sheet can be opened
/// over a screen that already has both blur slots spent -- a `GlassScaffold`
/// header plus its nav bar -- so a sheet reaching for its own
/// `BackdropFilter` would blow the two-blur budget the moment it's opened
/// from one of those screens (which is most of them). Uses the same
/// specular-border-plus-elevation-tinted-gradient treatment [GlassCard] does,
/// pinned to [GlassElevation.hero]: a sheet is always the thing drawing the
/// eye while it's open.
class GlassSheet extends StatelessWidget {
  final String? title;
  final Widget child;

  /// Distance from the top of the screen the sheet's chrome starts at.
  /// Content-sized sheets (a form, a short list of choices) want more of the
  /// screen left showing behind them; a full catalog picker wants less.
  final double topInset;

  /// `true` lets [child] fill the remaining height (a scrolling list that
  /// should reach the bottom of the sheet); `false` sizes the sheet to
  /// [child]'s own height instead. Matches [Column]'s `Expanded` vs. plain
  /// child distinction -- set it the same way you would there.
  final bool expand;

  final BorderRadius borderRadius;

  const GlassSheet({
    required this.child,
    super.key,
    this.title,
    this.topInset = 80,
    this.expand = false,
    this.borderRadius =
        const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
  });

  /// Opens [builder]'s content through this chrome, with the haptic phrase
  /// every sheet in the app now opens with -- a small physical "lift",
  /// matching the vocabulary [AppHaptics.lift] already carries elsewhere.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isScrollControlled = true,
  }) {
    HapticPhrase.play(AppHaptics.lift);
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(top: media.padding.top + topInset),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: DecoratedBox(
          // An opaque base *under* the glass tint, not instead of it.
          //
          // The tint alone is a white gradient over nothing -- around 90%
          // transparent, which is correct for a card floating on the aurora
          // and completely wrong for a modal sheet: text fields and their
          // labels ended up competing with whatever list was scrolled behind
          // them. Every sheet in the app used to set this explicitly before
          // they were unified here, and losing it was a straight readability
          // regression. Still no `BackdropFilter` -- this is a fill, not a
          // blur, so the two-blur budget is untouched.
          decoration: BoxDecoration(
            color: AppPalette.surface.withValues(alpha: .97),
            boxShadow: GlassDecoration.shadowsFor(GlassElevation.hero),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: GlassDecoration.body(
                top: GlassTokens.topTint(GlassElevation.hero),
                bottom: GlassTokens.bottomTint(GlassElevation.hero),
              ),
            ),
            child: SpecularBorder(
              borderRadius: borderRadius,
              intensity: GlassTokens.borderIntensity(GlassElevation.hero),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration:
                            BoxDecoration(gradient: GlassDecoration.specular),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      if (title != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                          child: Row(children: [
                            Text(title!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  color: AppPalette.text,
                                )),
                          ]),
                        ),
                      expand ? Expanded(child: child) : child,
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
