import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/memoire.dart';
import 'voyage_database.dart';

enum ImportMode {
  replace,  // Remplacer tout
  merge,    // Fusionner (écraser si ID existe)
  addNew,   // Ajouter seulement les nouveaux
}

class ImportExportService {
  /// Exporter tous les voyages en JSON
  static Future<File> exportAllVoyages() async {
    final voyages = await VoyageDatabase.instance.getAllVoyages();
    return await _exportVoyages(voyages, 'mes_voyages_complet');
  }
  
  /// Exporter une sélection de voyages
  static Future<File> exportSelectedVoyages(List<Memoire> voyages) async {
    return await _exportVoyages(voyages, 'mes_voyages_selection');
  }
  
  /// Exporter les voyages dans un fichier
  static Future<File> _exportVoyages(List<Memoire> voyages, String baseFilename) async {
    // Créer le JSON
    final jsonData = {
      'memoires': voyages.map((v) => v.toJson()).toList(),
      'exported_at': DateTime.now().toIso8601String(),
      'version': '1.0',
      'count': voyages.length,
    };
    
    final jsonString = JsonEncoder.withIndent('  ').convert(jsonData);
    
    // Sauvegarder dans un fichier temporaire
    //final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    final filename = '${baseFilename}_$timestamp.json';
    //final file = File('${directory.path}/$filename');    
    //await file.writeAsString(jsonString);
    String filePath;
  
    try {
      // Essayer Downloads d'abord
      final downloadsDir = Directory('${Platform.environment['HOME']}/Downloads');
      if (await downloadsDir.exists()) {
        filePath = '${downloadsDir.path}/$filename';
      } else {
        // Sinon, Documents
        final directory = await getApplicationDocumentsDirectory();
        filePath = '${directory.path}/$filename';
      }
    } catch (e) {
      print('❌ Erreur accès répertoire: $e');
      // Fallback : /tmp
      filePath = '/tmp/$filename';
    }
  
    final file = File(filePath);
    await file.writeAsString(jsonString);
  
    print('✅ Fichier exporté : ${file.path}');

    return file;
  }
  
  /// Partager le fichier exporté
  static Future<void> shareExportFile(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Mes voyages - Export',
      text: 'Fichier d\'export de mes voyages (${file.path.split('/').last})',
    );
  }
  
  /// Choisir un fichier JSON à importer
  static Future<File?> pickImportFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );
    
    if (result != null && result.files.single.path != null) {
      return File(result.files.single.path!);
    }
    
    return null;
  }
  
  /// Importer des voyages depuis un fichier JSON
  static Future<ImportResult> importVoyages(File file, ImportMode mode) async {
    try {
      // Lire le fichier
      final jsonString = await file.readAsString();
      final jsonData = json.decode(jsonString);
      
      // Valider le format
      if (!jsonData.containsKey('memoires')) {
        return ImportResult(
          success: false,
          message: 'Format invalide : clé "memoires" manquante',
        );
      }
      
      // Parser les voyages
      final List<dynamic> memoiresJson = jsonData['memoires'];
      final voyages = memoiresJson
          .map((json) => Memoire.fromJson(json))
          .where((m) => m.categorie == 'voyage')
          .toList();
      
      if (voyages.isEmpty) {
        return ImportResult(
          success: false,
          message: 'Aucun voyage trouvé dans le fichier',
        );
      }
      
      // Appliquer selon le mode
      int imported = 0;
      int skipped = 0;
      int replaced = 0;
      
      if (mode == ImportMode.replace) {
        // Supprimer tous les voyages existants
        final existingVoyages = await VoyageDatabase.instance.getAllVoyages();
        for (var v in existingVoyages) {
          await VoyageDatabase.instance.deleteVoyage(v.id);
        }
        
        // Insérer tous les nouveaux
        for (var voyage in voyages) {
          await VoyageDatabase.instance.insertVoyage(voyage);
          imported++;
        }
      } else {
        // Récupérer les IDs existants
        final existingVoyages = await VoyageDatabase.instance.getAllVoyages();
        final existingIds = existingVoyages.map((v) => v.id).toSet();
        
        for (var voyage in voyages) {
          final exists = existingIds.contains(voyage.id);
          
          if (mode == ImportMode.merge) {
            // Fusionner : remplacer si existe, ajouter sinon
            await VoyageDatabase.instance.insertVoyage(voyage);
            if (exists) {
              replaced++;
            } else {
              imported++;
            }
          } else if (mode == ImportMode.addNew) {
            // Ajouter uniquement les nouveaux
            if (!exists) {
              await VoyageDatabase.instance.insertVoyage(voyage);
              imported++;
            } else {
              skipped++;
            }
          }
        }
      }
      
      return ImportResult(
        success: true,
        imported: imported,
        replaced: replaced,
        skipped: skipped,
        message: _buildSuccessMessage(mode, imported, replaced, skipped),
      );
      
    } catch (e) {
      return ImportResult(
        success: false,
        message: 'Erreur lors de l\'import : $e',
      );
    }
  }
  
  static String _buildSuccessMessage(ImportMode mode, int imported, int replaced, int skipped) {
    switch (mode) {
      case ImportMode.replace:
        return '$imported voyages importés (remplacement complet)';
      case ImportMode.merge:
        return '$imported nouveaux voyages, $replaced remplacés';
      case ImportMode.addNew:
        return '$imported voyages ajoutés, $skipped ignorés (déjà existants)';
    }
  }
}

class ImportResult {
  final bool success;
  final int imported;
  final int replaced;
  final int skipped;
  final String message;
  
  ImportResult({
    required this.success,
    this.imported = 0,
    this.replaced = 0,
    this.skipped = 0,
    required this.message,
  });
}
