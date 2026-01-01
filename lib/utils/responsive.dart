import 'package:flutter/material.dart';

class Responsive {
  // Breakpoints
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
  static const double largeDesktop = 1600;
  
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobile;
  
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobile &&
      MediaQuery.of(context).size.width < desktop;
  
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktop &&
      MediaQuery.of(context).size.width < largeDesktop;
  
  static bool isLargeDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= largeDesktop;
  
  // Grid colonnes (plus progressif)
  static int photoGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < 400) return 2;        // Petit mobile
    if (width < mobile) return 2;     // Mobile normal
    if (width < 750) return 3;        // Tablette portrait
    if (width < desktop) return 4;    // Tablette paysage
    if (width < largeDesktop) return 5;  // Desktop
    return 6;                         // Large desktop
  }
  
  // Taille thumbnail (plus progressive)
  static double photoThumbSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < 400) return 80;       // Petit mobile
    if (width < mobile) return 100;   // Mobile normal
    if (width < 750) return 120;      // Tablette portrait
    if (width < desktop) return 140;  // Tablette paysage
    if (width < largeDesktop) return 160;  // Desktop
    return 180;                       // Large desktop
  }
  
  // Padding selon écran
  static EdgeInsets pagePadding(BuildContext context) {
    if (isMobile(context)) return const EdgeInsets.all(12);
    if (isTablet(context)) return const EdgeInsets.all(20);
    return const EdgeInsets.all(32);
  }
  
  // Espacement grid
  static double gridSpacing(BuildContext context) {
    if (isMobile(context)) return 8;
    return 12;
  }
}
