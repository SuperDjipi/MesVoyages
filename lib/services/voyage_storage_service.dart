import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/memoire.dart';
import 'subscription_service.dart';
import 'voyage_database.dart';

class VoyageStorageService {
  // Charger les voyages
  static Future<List<Memoire>> loadVoyages() async {
    final isPremium = await SubscriptionService.isPremium();
    
    if (isPremium) {
      return await VoyageDatabase.instance.getAllVoyages();
    } else {
      return await _loadFreeVoyages();
    }
  }
  
  // Sauvegarder un voyage (retourne true si OK, false si limite atteinte)
  static Future<bool> saveVoyage(Memoire voyage) async {
    final isPremium = await SubscriptionService.isPremium();
    
    if (isPremium) {
      await VoyageDatabase.instance.insertVoyage(voyage);
      return true;
    } else {
      final voyages = await _loadFreeVoyages();
      
      if (voyages.length >= SubscriptionService.FREE_VOYAGE_LIMIT) {
        return false;  // Limite atteinte
      }
      
      voyages.add(voyage);
      await _saveFreeVoyages(voyages);
      return true;
    }
  }
  
  // Mettre à jour un voyage
  static Future<void> updateVoyage(Memoire voyage) async {
    final isPremium = await SubscriptionService.isPremium();
    
    if (isPremium) {
      await VoyageDatabase.instance.updateVoyage(voyage);
    } else {
      final voyages = await _loadFreeVoyages();
      final index = voyages.indexWhere((v) => v.id == voyage.id);
      if (index != -1) {
        voyages[index] = voyage;
        await _saveFreeVoyages(voyages);
      }
    }
  }
  
  // Supprimer un voyage
  static Future<void> deleteVoyage(String id) async {
    final isPremium = await SubscriptionService.isPremium();
    
    if (isPremium) {
      await VoyageDatabase.instance.deleteVoyage(id);
    } else {
      final voyages = await _loadFreeVoyages();
      voyages.removeWhere((v) => v.id == id);
      await _saveFreeVoyages(voyages);
    }
  }
  
  // Compter les voyages
  static Future<int> getVoyageCount() async {
    final isPremium = await SubscriptionService.isPremium();
    
    if (isPremium) {
      return await VoyageDatabase.instance.getVoyageCount();
    } else {
      final voyages = await _loadFreeVoyages();
      return voyages.length;
    }
  }
  
  // Charger voyages gratuits
  static Future<List<Memoire>> _loadFreeVoyages() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('free_voyages');
    
    if (jsonString == null) {
      // Première utilisation : charger démos
      return await _loadDemoVoyages();
    }
    
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((json) => Memoire.fromJson(json)).toList();
  }
  
  // Sauvegarder voyages gratuits
  static Future<void> _saveFreeVoyages(List<Memoire> voyages) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = voyages.map((v) => v.toJson()).toList();
    await prefs.setString('free_voyages', json.encode(jsonList));
  }
  
  // Charger voyages démo depuis assets
  static Future<List<Memoire>> _loadDemoVoyages() async {
    try {
      final String response = await rootBundle.loadString('assets/voyages.json');
      final data = json.decode(response);
      final List<dynamic> memoiresJson = data['memoires'];
      
      // Prendre seulement les 3 premiers voyages
      final demoVoyages = memoiresJson
          .take(3)
          .map((json) => Memoire.fromJson(json))
          .toList();
      
      // Les sauvegarder pour la prochaine fois
      await _saveFreeVoyages(demoVoyages);
      
      return demoVoyages;
    } catch (e) {
      print('Erreur chargement démos: $e');
      return [];
    }
  }
  
  // Migration gratuit → premium
  static Future<void> migrateToPremium() async {
    final freeVoyages = await _loadFreeVoyages();
    
    // Copier dans Sqflite
    for (var voyage in freeVoyages) {
      await VoyageDatabase.instance.insertVoyage(voyage);
    }
    
    // Activer premium
    await SubscriptionService.activatePremium();
    
    // Nettoyer SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('free_voyages');
  }
}
