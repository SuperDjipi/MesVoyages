import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionService {
  static const String _keyIsPremium = 'is_premium';
  static const int FREE_VOYAGE_LIMIT = 3;
  
  // Vérifier si l'utilisateur est premium
  static Future<bool> isPremium() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsPremium) ?? false;
  }
  
  // Activer le premium (après paiement)
  static Future<void> activatePremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsPremium, true);
  }
  
  // Pour dev/test : simuler l'achat
  static Future<void> togglePremium() async {
    final current = await isPremium();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsPremium, !current);
  }

  // Reset (pour dev)
  static Future<void> resetPremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsPremium, false);
  }
}
