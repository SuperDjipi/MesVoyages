import 'dart:io';
import 'package:flutter/material.dart';
import '../services/photo_service.dart';
import '../utils/responsive.dart';
import 'photo_viewer.dart';

class PhotoGallery extends StatelessWidget {
  final List<String> photos;
  final Function(String) onDeletePhoto;
  final VoidCallback onAddPhoto;
  final int? maxDisplay; // Limite affichage (null = tout)
  
  const PhotoGallery({
    super.key,
    required this.photos,
    required this.onDeletePhoto,
    required this.onAddPhoto,
    this.maxDisplay,
  });

  @override
  Widget build(BuildContext context) {
    final displayPhotos = maxDisplay != null && photos.length > maxDisplay!
        ? photos.take(maxDisplay!).toList()
        : photos;
    
    final remaining = maxDisplay != null && photos.length > maxDisplay!
        ? photos.length - maxDisplay!
        : 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_library, size: 20, color: Color(0xFF1A3A52)),
                const SizedBox(width: 8),
                Text(
                  'Photos (${photos.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.add_photo_alternate),
              color: const Color(0xFF1A3A52),
              onPressed: onAddPhoto,
              tooltip: 'Ajouter des photos',
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Galerie
        if (photos.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucune photo',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Ajouter des photos'),
                  onPressed: onAddPhoto,
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = Responsive.photoGridColumns(context);
              final spacing = Responsive.gridSpacing(context);
              
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  childAspectRatio: 1.0,
                ),
                itemCount: displayPhotos.length + (remaining > 0 ? 1 : 0),
                itemBuilder: (context, index) {
                  // Dernière case = "voir plus"
                  if (remaining > 0 && index == displayPhotos.length) {
                    return _buildSeeMoreTile(context, remaining);
                  }
                  
                  return _buildPhotoTile(
                    context,
                    displayPhotos[index],
                    photos.indexOf(displayPhotos[index]),
                  );
                },
              );
            },
          ),
      ],
    );
  }
  
  Widget _buildPhotoTile(BuildContext context, String photoPath, int globalIndex) {
    return FutureBuilder<File?>(
      future: PhotoService.getPhotoFile(photoPath, thumbnail: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        
        if (!snapshot.hasData || snapshot.data == null) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.broken_image, color: Colors.grey),
          );
        }
        
        return GestureDetector(
          onTap: () => _openPhotoViewer(context, globalIndex),
          onLongPress: () => _showPhotoOptions(context, photoPath),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  snapshot.data!,
                  fit: BoxFit.cover,
                ),
                // Overlay au hover/tap (optionnel)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white, size: 16),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: () => _showPhotoOptions(context, photoPath),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildSeeMoreTile(BuildContext context, int remaining) {
    return GestureDetector(
      onTap: () {
        // TODO: Ouvrir galerie complète
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Galerie complète à venir')),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library, size: 32, color: Colors.grey[700]),
            const SizedBox(height: 8),
            Text(
              '+$remaining',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            Text(
              'Voir tout',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _openPhotoViewer(BuildContext context, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewer(
          photos: photos,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
  
  void _showPhotoOptions(BuildContext context, String photoPath) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Supprimer'),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, photoPath);
              },
            ),
            // TODO: Autres options (définir comme couverture, etc.)
          ],
        ),
      ),
    );
  }
  
  void _confirmDelete(BuildContext context, String photoPath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la photo ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onDeletePhoto(photoPath);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
