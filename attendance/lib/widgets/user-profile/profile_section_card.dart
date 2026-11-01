import 'package:attendance/config/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Layout, colour and type tokens shared by the profile screen.
///
/// The rhythm (4/8/12/16/20/24), the 22dp grouped-card radius, the hairline
/// separators and the restrained 400/500/600 type weights follow the Block
/// Buzz profile/settings screens, mapped onto the Attendance [AppTheme].
abstract final class ProfileUi {
  static const double gutter = 20;
  static const double rowInset = 16;
  static const double cardRadius = 22;
  static const double sheetRadius = 24;
  static const double iconSize = 22;

  /// Separators start after the leading icon so they align with row labels.
  static const double dividerIndent = rowInset + iconSize + rowInset;

  static const Color page = Colors.white;
  static const Color cardFill = AppTheme.softGray;
  static const Color warning = Color(0xFFAB6400);

  static Color get hairline => AppTheme.textPrimary.withValues(alpha: 0.07);

  static TextStyle body({Color? color, FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.inter(
        fontSize: 16,
        height: 1.25,
        fontWeight: weight,
        color: color ?? AppTheme.textPrimary,
      );

  static TextStyle small({Color? color, FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.inter(
        fontSize: 14,
        height: 1.3,
        fontWeight: weight,
        color: color ?? AppTheme.textSecondary,
      );

  static TextStyle caption({
    Color? color,
    FontWeight weight = FontWeight.w500,
  }) => GoogleFonts.inter(
    fontSize: 12,
    height: 1.25,
    fontWeight: weight,
    color: color ?? AppTheme.textSecondary,
  );
}

/// A group of rows inside one rounded surface, with an optional sentence-case
/// [label] above it and hairline separators between [children].
class ProfileSectionCard extends StatelessWidget {
  const ProfileSectionCard({
    super.key,
    this.label,
    this.dividerIndent = ProfileUi.dividerIndent,
    required this.children,
  });

  final String? label;
  final double dividerIndent;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final separated = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        separated.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: dividerIndent,
            endIndent: ProfileUi.rowInset,
            color: ProfileUi.hairline,
          ),
        );
      }
      separated.add(children[i]);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ProfileUi.gutter,
        vertical: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Semantics(
                header: true,
                child: Text(
                  label!,
                  style: ProfileUi.small(weight: FontWeight.w600),
                ),
              ),
            ),
          Material(
            color: ProfileUi.cardFill,
            borderRadius: BorderRadius.circular(ProfileUi.cardRadius),
            // Keeps row ripples inside the rounded corners.
            clipBehavior: Clip.antiAlias,
            child: Column(mainAxisSize: MainAxisSize.min, children: separated),
          ),
        ],
      ),
    );
  }
}