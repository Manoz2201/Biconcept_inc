import 'package:flutter/material.dart';

class AppSpacing {
  const AppSpacing._();

  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;

  static const radiusSm = 4.0;
  static const radiusMd = 8.0;
  static const radiusLg = 12.0;
  static const radiusXl = 16.0;
  static const radiusXxl = 24.0;
  static const radiusPill = 999.0;

  static const borderThin = 1.0;
  static const borderRegular = 2.0;
  static const borderThick = 4.0;

  static const iconSm = 16.0;
  static const iconMd = 20.0;
  static const iconLg = 24.0;

  static const touchMin = 48.0;

  static const radiusAllSm = BorderRadius.all(Radius.circular(radiusSm));
  static const radiusAllMd = BorderRadius.all(Radius.circular(radiusMd));
  static const radiusAllLg = BorderRadius.all(Radius.circular(radiusLg));
  static const radiusAllXl = BorderRadius.all(Radius.circular(radiusXl));
  static const radiusAllXxl = BorderRadius.all(Radius.circular(radiusXxl));
  static const radiusAllPill = BorderRadius.all(Radius.circular(radiusPill));
}
