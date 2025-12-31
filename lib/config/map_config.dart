class MapConfig {
  // URL des tiles - Carto Positron (romanisation internationale)
  // Styles disponibles :
  // - light_all : Clair (Positron) - RECOMMANDÉ
  // - dark_all : Sombre (Dark Matter)
  // - rastertiles/voyager : Coloré (Voyager)
  static const String tileUrl = 
      // 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
  // Subdomains pour load balancing
  static const List<String> subdomains = ['a', 'b', 'c', 'd'];
  
  // User agent
  static const String userAgent = 'club.djipi.voyage_map_public';
  
  // Limites de zoom
  static const int maxNativeZoom = 19;
  static const int minZoom = 2;
  
  // Centre par défaut (France)
  static const double defaultLat = 46.5;
  static const double defaultLng = 2.5;
  
  // Attribution
  static const String attribution = 
      '© OpenStreetMap contributors © CARTO';
}
