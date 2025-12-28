import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/memoire.dart';

class VoyageService {
  Future<List<Memoire>> loadVoyages() async {
    try {
      final String response = await rootBundle.loadString('assets/voyages.json');
      final data = json.decode(response);
      final List<dynamic> voyagesJson = data['memoires'];  // Garde "memoires" pour compatibilité
      
      // Filtrer uniquement les voyages
      final voyages = voyagesJson
          .map((json) => Memoire.fromJson(json))
          .where((m) => m.categorie == 'voyage')
          .toList();
      
      return voyages;
    } catch (e) {
      print('Erreur chargement voyages: $e');
      return [];
    }
  }
}
