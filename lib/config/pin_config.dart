import 'package:flutter/material.dart';

class PinConfig {
  // Mapping couleurs Flutter → fichiers pin
  static String getPinAsset(Color couleur) {
    // Convertir la couleur en nom
    if (_isSimilar(couleur, Colors.blue)) return 'assets/markers/pin_marker_vm_bleu.png';
    if (_isSimilar(couleur, Colors.grey)) return 'assets/markers/pin_marker_vm_gris.png';
    if (_isSimilar(couleur, Colors.yellow)) return 'assets/markers/pin_marker_vm_jaune.png';
    if (_isSimilar(couleur, Colors.brown)) return 'assets/markers/pin_marker_vm_marron.png';
    if (_isSimilar(couleur, Colors.pink)) return 'assets/markers/pin_marker_vm_rose.png';
    if (_isSimilar(couleur, Colors.red)) return 'assets/markers/pin_marker_vm_rouge.png';
    if (_isSimilar(couleur, Colors.green)) return 'assets/markers/pin_marker_vm_vert.png';
    if (_isSimilar(couleur, Colors.purple)) return 'assets/markers/pin_marker_vm_violet.png';
    
    // Défaut si couleur non reconnue
    return 'assets/markers/pin_marker_vm_gris.png';
  }
  
  // Palette de couleurs disponibles (pour le sélecteur)
  static const List<Color> availableColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,    // Correspondance avec marron
    Colors.purple,
    Colors.pink,
    Colors.yellow,
    Colors.grey,
  ];
  
  // Comparer deux couleurs (tolérance pour variations de teinte)
  static bool _isSimilar(Color c1, Color c2) {
    return (c1.value & 0x00FFFFFF) == (c2.value & 0x00FFFFFF);
  }
}
