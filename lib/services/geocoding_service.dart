import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';
  
  /// Recherche un lieu et retourne les coordonnées
  static Future<LocationResult?> searchLocation(String query) async {
    if (query.trim().isEmpty) return null;
    
    try {
      final uri = Uri.parse('$_baseUrl/search').replace(
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': '1',
          'addressdetails': '1',
        },
      );
      
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'VoyageMapApp/1.0',  // Nominatim exige un User-Agent
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        
        if (results.isNotEmpty) {
          final result = results.first;
          return LocationResult(
            latitude: double.parse(result['lat']),
            longitude: double.parse(result['lon']),
            displayName: result['display_name'],
          );
        }
      }
      
      return null;
    } catch (e) {
      print('Erreur geocoding: $e');
      return null;
    }
  }
}

class LocationResult {
  final double latitude;
  final double longitude;
  final String displayName;
  
  LocationResult({
    required this.latitude,
    required this.longitude,
    required this.displayName,
  });
}
