import 'package:flutter/material.dart';

/// Shared layout and visual constants for the desktop UI.
///
/// Keep frequently reused dimensions here so sidebars, toolbars and detail
/// panes stay visually aligned as the application grows.
abstract final class UiTokens {
  static const double sidebarWidth = 232;
  static const double bookmarkSidebarWidth = 220;
  static const double collapsedSidebarWidth = 48;

  static const double appBarHeight = 50;
  static const double toolbarHeight = 50;
  static const double sidebarRowHeight = 36;
  static const double sidebarChildRowHeight = 32;
  static const double sidebarSectionHeight = 32;
  static const double detailRowHeight = 36;

  static const double iconSmall = 16;
  static const double iconNormal = 18;
  static const double iconLarge = 20;

  static const double textXs = 10.5;
  static const double textSm = 12;
  static const double textMd = 13;
  static const double textLg = 17;

  static const double radiusSm = 5;
  static const double radiusMd = 7;
  static const double radiusLg = 10;

  static const double space2 = 2;
  static const double space4 = 4;
  static const double space6 = 6;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space24 = 24;

  static const EdgeInsets pagePadding = EdgeInsets.all(space16);
  static const EdgeInsets sidebarRowPadding = EdgeInsets.symmetric(
    horizontal: 9,
    vertical: 7,
  );
}
