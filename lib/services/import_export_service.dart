import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:archive/archive_io.dart';
import '../models/memoire.dart';
import 'voyage_database.dart';
import 'photo_service.dart';

enum ImportMode {
  replace,  // Remplacer tout
  merge,    // Fusionner (écraser si ID existe)
  addNew,   // Ajouter seulement les nouveaux
}

class ImportExportService {
  /// Exporter tous les voyages en ZIP (JSON + photos)
  static Future<File> exportAllVoyages() async {
    final voyages = await VoyageDatabase.instance.getAllVoyages();
    return await _exportVoyages(voyages, 'mes_voyages_complet');
  }
  
  /// Exporter une sélection de voyages
  static Future<File> exportSelectedVoyages(List<Memoire> voyages) async {
    return await _exportVoyages(voyages, 'mes_voyages_selection');
  }
  
  /// Exporter les voyages dans un fichier ZIP
  static Future<File> _exportVoyages(List<Memoire> voyages, String baseFilename) async {
    print('🚀 Début export de ${voyages.length} voyages...');
    
    // 1. Créer le dossier temporaire
    final tempDir = await getTemporaryDirectory();
    final exportDir = Directory('${tempDir.path}/export_${DateTime.now().millisecondsSinceEpoch}');
    await exportDir.create(recursive: true);
    
    print('📁 Dossier temporaire : ${exportDir.path}');
    
    try {
      // 2. Créer le JSON
      final jsonData = {
        'memoires': voyages.map((v) => v.toJson()).toList(),
        'exported_at': DateTime.now().toIso8601String(),
        'version': '1.0',
        'count': voyages.length,
        'has_photos': voyages.any((v) => v.photos.isNotEmpty),
      };
      
      final jsonFile = File('${exportDir.path}/voyages.json');
      await jsonFile.writeAsString(
        JsonEncoder.withIndent('  ').convert(jsonData),
      );
      
      print('✅ JSON créé');
      
      // 3. Copier les photos
      final photosDir = Directory('${exportDir.path}/photos');
      await photosDir.create();
      
      int photoCount = 0;
      
      for (var voyage in voyages) {
        if (voyage.photos.isEmpty) continue;
        
        for (var photoPath in voyage.photos) {
          // Copier thumbnail
          final thumbFile = await PhotoService.getPhotoFile(photoPath, thumbnail: true);
          if (thumbFile != null && await thumbFile.exists()) {
            final parts = photoPath.split('/');
            if (parts.length == 2) {
              final voyageId = parts[0];
              final filename = parts[1];
              
              final destDir = Directory('${photosDir.path}/$voyageId');
              await destDir.create(recursive: true);
              
              await thumbFile.copy('${destDir.path}/thumb_$filename');
              photoCount++;
            }
          }
          
          // Copier HD
          final hdFile = await PhotoService.getPhotoFile(photoPath, thumbnail: false);
          if (hdFile != null && await hdFile.exists()) {
            final parts = photoPath.split('/');
            if (parts.length == 2) {
              final voyageId = parts[0];
              final filename = parts[1];
              
              final destDir = Directory('${photosDir.path}/$voyageId');
              await destDir.create(recursive: true);
              
              await hdFile.copy('${destDir.path}/hd_$filename');
            }
          }
        }
      }
      
      print('✅ $photoCount photos copiées');
      
      // 4. Créer le ZIP
      final encoder = ZipFileEncoder();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final zipFilename = '${baseFilename}_$timestamp.zip';
      
      String zipPath;
      
      // Essayer Downloads d'abord (Linux)
      if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        final downloadsDir = Directory('${Platform.environment['HOME']}/Downloads');
        if (await downloadsDir.exists()) {
          zipPath = '${downloadsDir.path}/$zipFilename';
        } else {
          final appDir = await getApplicationDocumentsDirectory();
          zipPath = '${appDir.path}/$zipFilename';
        }
      } else {
        // Android
        final appDir = await getApplicationDocumentsDirectory();
        zipPath = '${appDir.path}/$zipFilename';
      }
      
      encoder.create(zipPath);
      await encoder.addDirectory(exportDir);
      encoder.close();
      
      print('✅ ZIP créé : $zipPath');
      
      // 5. Nettoyer le dossier temporaire
      await exportDir.delete(recursive: true);
      
      final zipFile = File(zipPath);
      final zipSize = await zipFile.length();
      print('✅ Export terminé : ${(zipSize / 1024 / 1024).toStringAsFixed(2)} MB');
      
      return zipFile;
      
    } catch (e, stackTrace) {
      print('❌ Erreur export : $e');
      print(stackTrace);
      
      // Nettoyer en cas d'erreur
      if (await exportDir.exists()) {
        await exportDir.delete(recursive: true);
      }
      
      rethrow;
    }
  }
  
  /// Partager le fichier exporté
  static Future<void> shareExportFile(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Mes voyages - Export',
      text: 'Fichier d\'export de mes voyages (${file.path.split('/').last})',
    );
  }
  
  /// Choisir un fichier ZIP à importer
  static Future<File?> pickImportFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      allowMultiple: false,
    );
    
    if (result != null && result.files.single.path != null) {
      return File(result.files.single.path!);
    }
    
    return null;
  }
  
  /// Importer des voyages depuis un fichier ZIP
  static Future<ImportResult> importVoyages(File zipFile, ImportMode mode) async {
    print('🚀 Début import depuis ${zipFile.path}...');
    
    // 1. Créer un dossier temporaire pour extraire
    final tempDir = await getTemporaryDirectory();
    final extractDir = Directory('${tempDir.path}/import_${DateTime.now().millisecondsSinceEpoch}');
    await extractDir.create(recursive: true);
    
    print('📁 Extraction dans : ${extractDir.path}');
    
    try {
      // 2. Extraire le ZIP
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      for (var file in archive) {
        final filename = file.name;
        
        if (file.isFile) {
          final data = file.content as List<int>;
          final outFile = File('${extractDir.path}/$filename');
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(data);
        } else {
          await Directory('${extractDir.path}/$filename').create(recursive: true);
        }
      }
      
      print('✅ ZIP extrait');
      
      // 3. Lire le JSON
      final jsonFile = File('${extractDir.path}/voyages.json');
      
      if (!await jsonFile.exists()) {
        // Chercher dans un sous-dossier (cas où le ZIP a un dossier racine)
        final contents = await extractDir.list().toList();
        if (contents.length == 1 && contents.first is Directory) {
          final subDir = contents.first as Directory;
          final subJsonFile = File('${subDir.path}/voyages.json');
          
          if (await subJsonFile.exists()) {
            return await _processImport(subDir, subJsonFile, mode);
          }
        }
        
        return ImportResult(
          success: false,
          message: 'Format invalide : voyages.json manquant',
        );
      }
      
      return await _processImport(extractDir, jsonFile, mode);
      
    } catch (e, stackTrace) {
      print('❌ Erreur import : $e');
      print(stackTrace);
      
      return ImportResult(
        success: false,
        message: 'Erreur lors de l\'import : $e',
      );
    } finally {
      // Nettoyer le dossier temporaire
      if (await extractDir.exists()) {
        await extractDir.delete(recursive: true);
      }
    }
  }
  
  /// Traiter l'import (JSON + photos)
  static Future<ImportResult> _processImport(
    Directory extractDir,
    File jsonFile,
    ImportMode mode,
  ) async {
    // 1. Parser le JSON
    final jsonString = await jsonFile.readAsString();
    final jsonData = json.decode(jsonString);
  
    if (!jsonData.containsKey('memoires')) {
      return ImportResult(
        success: false,
        message: 'Format invalide : clé "memoires" manquante',
      );
    }
  
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
  
    print('📦 ${voyages.length} voyages à importer');
  
    // 2. Gérer le mode REPLACE (supprimer AVANT d'importer)
    if (mode == ImportMode.replace) {
      final existingVoyages = await VoyageDatabase.instance.getAllVoyages();
    
      print('🗑️ Mode REPLACE : suppression de ${existingVoyages.length} voyages existants...');
    
      // Supprimer les photos AVANT tout
      for (var v in existingVoyages) {
        await PhotoService.deleteAllVoyagePhotos(v.id);
      }
    
      // Supprimer les voyages de la DB
      for (var v in existingVoyages) {
        await VoyageDatabase.instance.deleteVoyage(v.id);
      }
    
      print('✅ Nettoyage terminé');
    }
  
    // 3. Importer les photos MAINTENANT (après nettoyage si replace)
    final photosDir = Directory('${extractDir.path}/photos');
    int photosImported = 0;
  
    if (await photosDir.exists()) {
      print('📸 Import des photos...');
    
      try {
        final appPhotosDir = Directory(
          '${(await getApplicationDocumentsDirectory()).path}/photos'
        );
      
        // Créer le dossier s'il n'existe pas
        if (!await appPhotosDir.exists()) {
          await appPhotosDir.create(recursive: true);
        }
      
        // Copier récursivement toutes les photos
        await for (var entity in photosDir.list(recursive: true)) {
          if (entity is File) {
            try {
              final relativePath = entity.path.replaceFirst('${photosDir.path}/', '');
              final destFile = File('${appPhotosDir.path}/$relativePath');
            
              await destFile.parent.create(recursive: true);
              await entity.copy(destFile.path);
              photosImported++;
            } catch (e) {
              print('❌ Erreur copie photo : $e');
            }
          }
        }
      
        print('✅ $photosImported fichiers photos importés');
      } catch (e, stackTrace) {
        print('❌ Erreur import photos : $e');
        print(stackTrace);
      }
    }
  
    // 4. Insérer les voyages en DB selon le mode
    int imported = 0;
    int skipped = 0;
    int replaced = 0;
  
    if (mode == ImportMode.replace) {
      // Tout a déjà été supprimé, juste insérer
      for (var voyage in voyages) {
        await VoyageDatabase.instance.insertVoyage(voyage);
        imported++;
      }
    } else {
      // Merge ou AddNew
      final existingVoyages = await VoyageDatabase.instance.getAllVoyages();
      final existingIds = existingVoyages.map((v) => v.id).toSet();
    
      for (var voyage in voyages) {
        final exists = existingIds.contains(voyage.id);
      
        if (mode == ImportMode.merge) {
          // Merge : si existe, supprimer les anciennes photos d'abord
          if (exists) {
            await PhotoService.deleteAllVoyagePhotos(voyage.id);
          }
        
          await VoyageDatabase.instance.insertVoyage(voyage);
        
          if (exists) {
            replaced++;
          } else {
            imported++;
          }
        } else if (mode == ImportMode.addNew) {
          if (!exists) {
            await VoyageDatabase.instance.insertVoyage(voyage);
            imported++;
          } else {
            skipped++;
            // Ne pas importer les photos des voyages ignorés
            await PhotoService.deleteAllVoyagePhotos(voyage.id);
          }
        }
      }
    }
  
    return ImportResult(
      success: true,
      imported: imported,
      replaced: replaced,
      skipped: skipped,
      photosImported: photosImported,
      message: _buildSuccessMessage(mode, imported, replaced, skipped, photosImported),
    );
  }
  
  static String _buildSuccessMessage(
    ImportMode mode,
    int imported,
    int replaced,
    int skipped,
    int photosImported,
  ) {
    final voyagesMsg = switch (mode) {
      ImportMode.replace => '$imported voyages importés (remplacement complet)',
      ImportMode.merge => '$imported nouveaux voyages, $replaced remplacés',
      ImportMode.addNew => '$imported voyages ajoutés, $skipped ignorés',
    };
    
    final photosMsg = photosImported > 0 ? '\n$photosImported photos importées' : '';
    
    return voyagesMsg + photosMsg;
  }
}

class ImportResult {
  final bool success;
  final int imported;
  final int replaced;
  final int skipped;
  final int photosImported;
  final String message;
  
  ImportResult({
    required this.success,
    this.imported = 0,
    this.replaced = 0,
    this.skipped = 0,
    this.photosImported = 0,
    required this.message,
  });
}
