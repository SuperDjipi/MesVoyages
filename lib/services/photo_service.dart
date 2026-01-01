import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';

class PhotoService {
  static const int thumbnailMaxWidth = 600;
  static const int thumbnailQuality = 90;
  
  static const int hdMaxWidth = 1920;
  static const int hdQuality = 92;
  
  /// Récupérer le dossier photos de l'app (pour import/export)
  static Future<Directory> getPhotosDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${appDir.path}/photos');
  
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
  
    return photosDir;
  }

  /// Récupérer le dossier photos de l'app
  static Future<Directory> _getPhotosDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${appDir.path}/photos');
    
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    
    return photosDir;
  }
  
  /// Récupérer le dossier photos d'un voyage
  static Future<Directory> _getVoyagePhotosDirectory(String voyageId) async {
    final photosDir = await _getPhotosDirectory();
    final voyageDir = Directory('${photosDir.path}/$voyageId');
    
    if (!await voyageDir.exists()) {
      await voyageDir.create(recursive: true);
    }
    
    return voyageDir;
  }
  
  /// Sélectionner des photos depuis la galerie
  static Future<List<XFile>?> pickPhotos({bool multiple = true}) async {
    final ImagePicker picker = ImagePicker();
    
    if (multiple) {
      return await picker.pickMultiImage();
    } else {
      final photo = await picker.pickImage(source: ImageSource.gallery);
      return photo != null ? [photo] : null;
    }
  }
  
  /// Sauvegarder une photo (crée thumbnail + HD)
  static Future<String?> savePhoto(File originalFile, String voyageId) async {
    try {
      final voyageDir = await _getVoyagePhotosDirectory(voyageId);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'photo_$timestamp.jpg';
      
      // Lire l'image originale
      final bytes = await originalFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        print('❌ Impossible de décoder l\'image');
        return null;
      }
      
      // Créer thumbnail (400px max)
      final thumbnail = img.copyResize(
        image,
        width: image.width > thumbnailMaxWidth ? thumbnailMaxWidth : null,
      );
      final thumbFile = File('${voyageDir.path}/thumb_$filename');
      await thumbFile.writeAsBytes(
        img.encodeJpg(thumbnail, quality: thumbnailQuality),
      );
      
      // Créer HD (1920px max)
      final hd = img.copyResize(
        image,
        width: image.width > hdMaxWidth ? hdMaxWidth : null,
      );
      final hdFile = File('${voyageDir.path}/hd_$filename');
      await hdFile.writeAsBytes(
        img.encodeJpg(hd, quality: hdQuality),
      );
      
      print('✅ Photo sauvegardée : $filename');
      
      // Retourner le chemin relatif (sans préfixe thumb_ ou hd_)
      return '$voyageId/$filename';
      
    } catch (e) {
      print('❌ Erreur sauvegarde photo : $e');
      return null;
    }
  }
  
  /// Récupérer le fichier photo (thumbnail ou HD)
  static Future<File?> getPhotoFile(String photoPath, {bool thumbnail = true}) async {
    try {
      final photosDir = await _getPhotosDirectory();
      final prefix = thumbnail ? 'thumb_' : 'hd_';
      
      // photoPath format: "voyage-123/photo_456.jpg"
      final parts = photoPath.split('/');
      if (parts.length != 2) return null;
      
      final voyageId = parts[0];
      final filename = parts[1];
      
      final file = File('${photosDir.path}/$voyageId/$prefix$filename');
      
      if (await file.exists()) {
        return file;
      }
      
      return null;
    } catch (e) {
      print('❌ Erreur récupération photo : $e');
      return null;
    }
  }
  
  /// Supprimer une photo (thumbnail + HD)
  static Future<bool> deletePhoto(String photoPath) async {
    try {
      final photosDir = await _getPhotosDirectory();
      
      final parts = photoPath.split('/');
      if (parts.length != 2) return false;
      
      final voyageId = parts[0];
      final filename = parts[1];
      
      // Supprimer thumbnail
      final thumbFile = File('${photosDir.path}/$voyageId/thumb_$filename');
      if (await thumbFile.exists()) {
        await thumbFile.delete();
      }
      
      // Supprimer HD
      final hdFile = File('${photosDir.path}/$voyageId/hd_$filename');
      if (await hdFile.exists()) {
        await hdFile.delete();
      }
      
      print('✅ Photo supprimée : $photoPath');
      return true;
      
    } catch (e) {
      print('❌ Erreur suppression photo : $e');
      return false;
    }
  }
  
  /// Supprimer toutes les photos d'un voyage
  static Future<void> deleteAllVoyagePhotos(String voyageId) async {
    try {
      final voyageDir = await _getVoyagePhotosDirectory(voyageId);
      
      if (await voyageDir.exists()) {
        await voyageDir.delete(recursive: true);
        print('✅ Toutes les photos du voyage $voyageId supprimées');
      }
    } catch (e) {
      print('❌ Erreur suppression photos voyage : $e');
    }
  }
}
