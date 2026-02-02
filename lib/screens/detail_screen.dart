import 'dart:io';  
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../config/map_config.dart';
import '../config/pin_config.dart';
import '../models/memoire.dart';
import '../services/voyage_storage_service.dart';
import '../services/voyage_database.dart';
import '../services/photo_service.dart';
import '../widgets/photo_gallery.dart';
import '../utils/responsive.dart';
import 'add_voyage_screen.dart';
import 'add_event_screen.dart';

class DetailScreen extends StatefulWidget {
  final Memoire memoire;

  const DetailScreen({super.key, required this.memoire});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final MapController _mapController = MapController();
  final ScrollController _scrollController = ScrollController();
  
  Evenement? _selectedEvenement;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Zoom sur un événement dans la mini-carte
  void _onEvenementSelected(Evenement evt) {
    setState(() {
      _selectedEvenement = evt;
    });
    
    if (evt.lat != null && evt.lng != null) {
      _mapController.move(
        LatLng(evt.lat!, evt.lng!),
        10.0,
      );
    }
  }

  // Fonction helper pour calculer hauteur grid photos
  double _calculatePhotoGridHeight(int photoCount) {
    final columns = Responsive.photoGridColumns(context);
    final rows = (photoCount / columns).ceil();
    final thumbSize = Responsive.photoThumbSize(context);
    final spacing = Responsive.gridSpacing(context);
  
    return (rows * thumbSize) + ((rows - 1) * spacing);
  }

  // Scroll vers un événement dans la liste
  void _onMarkerTapped(Evenement evt) {
    setState(() {
      _selectedEvenement = evt;
    });
    
    // Trouver l'index de l'événement
    final evenements = widget.memoire.evenements ?? [];
    final index = evenements.indexWhere((e) => e.nom == evt.nom);
    
    if (index != -1 && _scrollController.hasClients) {
      // Calculer la position en partant du HAUT
      final headerHeight = 150.0;  // En-tête avec icône
      final infoSectionHeight = 100.0;  // Description, participants, tags
    
      // AJOUT : Hauteur de la galerie photos
      final photoCount = widget.memoire.photos.length;
      final photoGalleryHeight = photoCount > 0 
          ? 80.0 + _calculatePhotoGridHeight(photoCount)  // En-tête + grid
          : 0.0;
    
      final evenementsTitleHeight = 50.0;
      final eventCardHeight = 110.0;
    
      final cardPosition = headerHeight + 
                        infoSectionHeight + 
                        photoGalleryHeight + 24 +  // Spacing
                        evenementsTitleHeight + 
                        (index * eventCardHeight);
      // Centrer la card sur l'écran
      final screenHeight = MediaQuery.of(context).size.height;
      final appBarHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
      final mapHeight = 250.0;
      final visibleHeight = screenHeight - appBarHeight - mapHeight;
    
      // Scroll pour centrer : position de la card - la moitié de la hauteur visible
      final targetScroll = cardPosition - (visibleHeight / 2) + (eventCardHeight / 2);
    
      _scrollController.animateTo(
        targetScroll.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _editVoyage() async {
    final voyageModifie = await Navigator.push<Memoire>(
      context,
      MaterialPageRoute(
        builder: (context) => AddVoyageScreen(voyage: widget.memoire),
      ),
    );
  
    if (voyageModifie != null) {
      await VoyageStorageService.updateVoyage(voyageModifie);
    
      if (mounted) {
        Navigator.pop(context, voyageModifie);
      }
    }
  }

  // AJOUTER un événement
  Future<void> _addEvent() async {
    final nouvelEvent = await Navigator.push<Evenement>(
      context,
      MaterialPageRoute(
        builder: (context) => AddEventScreen(voyage: widget.memoire),
      ),
    );
  
    if (nouvelEvent != null) {
      final ancienEvenements = widget.memoire.evenements ?? [];
      final nouveauxEvenements = [...ancienEvenements, nouvelEvent];
      final voyageMisAJour = widget.memoire.copyWith(
        evenements: nouveauxEvenements,
      );
    
      await VoyageStorageService.updateVoyage(voyageMisAJour);
    
      if (mounted) {
        Navigator.pop(context, voyageMisAJour);
      }
    }
  }

  // MODIFIER un événement
  Future<void> _editEvent(Evenement event, int index) async {
    final eventModifie = await Navigator.push<Evenement>(
      context,
      MaterialPageRoute(
        builder: (context) => AddEventScreen(evenement: event),
      ),
    );
  
    if (eventModifie != null) {
      final nouveauxEvenements = List<Evenement>.from(widget.memoire.evenements ?? []);
      nouveauxEvenements[index] = eventModifie;
      final voyageMisAJour = widget.memoire.copyWith(
        evenements: nouveauxEvenements,
      );
    
      await VoyageStorageService.updateVoyage(voyageMisAJour);
    
      if (mounted) {
        Navigator.pop(context, voyageMisAJour);
      }
    }
  }

  // SUPPRIMER un événement
  Future<void> _deleteEvent(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cet événement ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  
    if (confirm == true) {
      final nouveauxEvenements = List<Evenement>.from(widget.memoire.evenements ?? []);
      nouveauxEvenements.removeAt(index);
      final voyageMisAJour = widget.memoire.copyWith(
        evenements: nouveauxEvenements,
      );
    
      await VoyageStorageService.updateVoyage(voyageMisAJour);
    
      if (mounted) {
        Navigator.pop(context, voyageMisAJour);
      }
    }
  }

  // RÉORGANISER les événements (drag & drop)
  Future<void> _onReorderEvent(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final nouveauxEvenements = List<Evenement>.from(widget.memoire.evenements ?? []);
    final event = nouveauxEvenements.removeAt(oldIndex);
    nouveauxEvenements.insert(newIndex, event);

    final voyageMisAJour = widget.memoire.copyWith(evenements: nouveauxEvenements);
    await VoyageStorageService.updateVoyage(voyageMisAJour);

    if (mounted) {
      Navigator.pop(context, voyageMisAJour);
    }
  }

  // ==================== GESTION DES PHOTOS ====================

  Future<void> _addPhotos() async {
    final photos = await PhotoService.pickPhotos(multiple: true);
  
    if (photos == null || photos.isEmpty) {
      return;
    }
  
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(
              'Ajout de ${photos.length} photo(s)...',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  
    try {
      final List<String> savedPhotos = [];
    
      for (var photo in photos) {
        final file = File(photo.path);
        final photoPath = await PhotoService.savePhoto(file, widget.memoire.id);
      
        if (photoPath != null) {
          savedPhotos.add(photoPath);
        }
      }
    
      Navigator.pop(context); // Fermer loader
    
      if (savedPhotos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Aucune photo n\'a pu être sauvegardée'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    
      final nouveauxPhotos = [...widget.memoire.photos, ...savedPhotos];
      final voyageMisAJour = widget.memoire.copyWith(photos: nouveauxPhotos);
    
      await VoyageStorageService.updateVoyage(voyageMisAJour);
    
      if (mounted) {
        Navigator.pop(context, voyageMisAJour);
      }
    
    } catch (e) {
      Navigator.pop(context);
    
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deletePhoto(String photoPath) async {
    final success = await PhotoService.deletePhoto(photoPath);
  
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Erreur lors de la suppression'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
  
    final nouveauxPhotos = widget.memoire.photos.where((p) => p != photoPath).toList();
    final voyageMisAJour = widget.memoire.copyWith(photos: nouveauxPhotos);
  
    await VoyageStorageService.updateVoyage(voyageMisAJour);
  
    if (mounted) {
      Navigator.pop(context, voyageMisAJour);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.memoire.titre),
        backgroundColor: const Color(0xFF1A3A52),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editVoyage,
            tooltip: 'Modifier',
          ),
        ],
      ),
      body: Column(
        children: [
          // MINI-CARTE STICKY
          _buildMiniMap(),
          
          // CONTENU SCROLLABLE
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: Responsive.pagePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // EN-TÊTE
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: widget.memoire.couleur.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: FaIcon(
                          widget.memoire.icone,
                          color: widget.memoire.couleur,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.memoire.titre,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.memoire.periode,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // INFORMATIONS
                  _buildInfoSection(),
                  
                  const SizedBox(height: 24),
                  
                  // ==================== GALERIE PHOTOS ====================
                  PhotoGallery(
                    photos: widget.memoire.photos,
                    onDeletePhoto: _deletePhoto,
                    onAddPhoto: _addPhotos,
                    maxDisplay: Responsive.isMobile(context) ? 6 : 8,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // ÉVÉNEMENTS
                  _buildEvenements(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMap() {
    final evenements = widget.memoire.evenements
        ?.where((e) => e.lat != null && e.lng != null)
        .toList() ?? [];
  
    if (evenements.isEmpty) {
      return const SizedBox.shrink();
    }
  
    // Collecter TOUS les points (événements + leurs waypoints)
    final List<LatLng> allPoints = [];
  
    for (var evt in evenements) {
      if (evt.waypoints != null && evt.waypoints!.isNotEmpty) {
        // Si l'événement a des waypoints, utiliser ceux-ci
        allPoints.addAll(evt.waypoints!.map((w) => LatLng(w.lat, w.lng)));
      } else if (evt.lat != null && evt.lng != null) {
        // Sinon utiliser la position de l'événement
        allPoints.add(LatLng(evt.lat!, evt.lng!));
      }
    }
  
    if (allPoints.isEmpty) {
      return const SizedBox.shrink();
    }
  
    // Calculer les bounds
    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;
  
    for (var point in allPoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
  
    final center = LatLng(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );
  
    final maxDiff = ((maxLat - minLat) > (maxLng - minLng))
        ? (maxLat - minLat)
        : (maxLng - minLng);
  
    double zoom = 9.0;
    if (maxDiff < 0.01) {
      zoom = 12.0;
    } else if (maxDiff < 0.1) {
      zoom = 10.0;
    } else if (maxDiff < 1.0) {
      zoom = 8.0;
    } else if (maxDiff < 5.0) {
      zoom = 6.0;
    } else {
      zoom = 4.0;
    }

    return Container(
      height: 250,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: center,
          initialZoom: zoom,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: MapConfig.tileUrl,
            subdomains: MapConfig.subdomains,
            userAgentPackageName: MapConfig.userAgent,
            maxNativeZoom: MapConfig.maxNativeZoom,
          ),
        
          // Polylines pour événements normaux (sans waypoints)
          PolylineLayer(
            polylines: _buildEventPolylines(evenements),
          ),
        
          // Polylines pour waypoints (journées visite et vols)
          PolylineLayer(
            polylines: _buildWaypointPolylines(evenements),
          ),
        
          // Markers pour événements normaux
          MarkerLayer(
            markers: _buildEventMarkers(evenements),
          ),
        
          // Markers pour waypoints
          MarkerLayer(
            markers: _buildWaypointMarkers(evenements),
          ),
        ],
      ),
    );
  }

  // ===== POLYLINES ÉVÉNEMENTS NORMAUX =====

  List<Polyline> _buildEventPolylines(List<Evenement> evenements) {
    final eventsWithoutWaypoints = evenements
        .where((e) => e.waypoints == null || e.waypoints!.isEmpty)
        .where((e) => e.lat != null && e.lng != null)
        .toList();
  
    if (eventsWithoutWaypoints.length <= 1) return [];
  
    final points = eventsWithoutWaypoints
        .map((e) => LatLng(e.lat!, e.lng!))
        .toList();
  
    return [
      Polyline(
        points: points,
        strokeWidth: 3.0,
        color: widget.memoire.couleur.withOpacity(0.7),
        borderStrokeWidth: 1.0,
        borderColor: Colors.white,
      ),
    ];
  }

  // ===== POLYLINES WAYPOINTS =====

  List<Polyline> _buildWaypointPolylines(List<Evenement> evenements) {
    final polylines = <Polyline>[];
  
    for (var evt in evenements) {
      if (evt.waypoints == null || evt.waypoints!.length < 2) continue;
    
      final points = evt.waypoints!.map((w) => LatLng(w.lat, w.lng)).toList();
    
      // Style selon le type d'événement
      if (evt.type == 'day_tour') {
        // Journée visite : ligne pointillée fine
        polylines.add(
          Polyline(
            points: points,
            strokeWidth: 1.5,
            color: evt.couleur.withOpacity(0.6),
          ),
        );
      } else if (evt.type == 'air_journey') {
        // Vol multi-segments : ligne directe du premier au dernier
        polylines.add(
          Polyline(
            points: [points.first, points.last],
            strokeWidth: 2.5,
            color: evt.couleur.withOpacity(0.8),
            borderStrokeWidth: 1.0,
            borderColor: Colors.white,
          ),
        );
      } else {
        // Autres types avec waypoints : ligne normale
        polylines.add(
          Polyline(
            points: points,
            strokeWidth: 2.5,
            color: evt.couleur.withOpacity(0.7),
          ),
        );
      }
    }
  
    return polylines;
  }

  // ===== MARKERS ÉVÉNEMENTS =====

  List<Marker> _buildEventMarkers(List<Evenement> evenements) {
    final markers = <Marker>[];
  
    for (var evt in evenements) {
      // Ne pas afficher le pin de l'événement s'il a des waypoints
      // (on affichera les waypoints à la place)
      if (evt.waypoints != null && evt.waypoints!.isNotEmpty) continue;
    
      if (evt.lat == null || evt.lng == null) continue;
    
      final isSelected = _selectedEvenement?.nom == evt.nom;
    
      markers.add(
        Marker(
          point: LatLng(evt.lat!, evt.lng!),
          width: isSelected ? 40 : 32,
          height: isSelected ? 58 : 46,
          alignment: Alignment.topCenter,  
          child: GestureDetector(
            onTap: () => _onMarkerTapped(evt),
            child: Image.asset(
              PinConfig.getPinAsset(evt.couleur),
              width: isSelected ? 40 : 32,
              height: isSelected ? 58 : 46,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }
  
    return markers;
  }

  // ===== MARKERS WAYPOINTS =====

  List<Marker> _buildWaypointMarkers(List<Evenement> evenements) {
    final markers = <Marker>[];
  
    for (var evt in evenements) {
      if (evt.waypoints == null || evt.waypoints!.isEmpty) continue;
    
      for (var i = 0; i < evt.waypoints!.length; i++) {
        final waypoint = evt.waypoints![i];
        final isSelected = _selectedEvenement?.nom == evt.nom;
      
        markers.add(
          Marker(
            point: LatLng(waypoint.lat, waypoint.lng),
            width: 60,
            height: 60,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => _onMarkerTapped(evt),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: isSelected ? 32 : 28,
                    height: isSelected ? 32 : 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: evt.couleur,
                        width: isSelected ? 3 : 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected 
                              ? evt.couleur.withOpacity(0.4)
                              : Colors.black.withOpacity(0.2),
                          blurRadius: isSelected ? 6 : 3,
                          spreadRadius: isSelected ? 1 : 0,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: evt.couleur,
                          fontSize: isSelected ? 14 : 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
  
    return markers;
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.memoire.description.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.description, size: 20, color: Color(0xFF1A3A52)),
              SizedBox(width: 8),
              Text(
                'Description',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.memoire.description,
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 16),
        ],
        
        if (widget.memoire.participants.isNotEmpty) ...[
          _buildParticipants(),
          const SizedBox(height: 16),
        ],
        
        if (widget.memoire.tags.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.label, size: 20, color: Color(0xFF1A3A52)),
              SizedBox(width: 8),
              Text(
                'Tags',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildTags(),
        ],
      ],
    );
  }

  Widget _buildParticipants() {
    return Row(
      children: [
        const FaIcon(
          FontAwesomeIcons.users,
          size: 16,
          color: Colors.grey,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.memoire.participants.join(', '),
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.memoire.tags.map((tag) {
        return Chip(
          label: Text(tag),
          backgroundColor: widget.memoire.couleur.withOpacity(0.1),
          labelStyle: TextStyle(
            color: widget.memoire.couleur,
            fontSize: 12,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        );
      }).toList(),
    );
  }

  Widget _buildEvenements() {
    final evenements = widget.memoire.evenements ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.listCheck,
                  color: widget.memoire.couleur,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Événements',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          
            IconButton(
              icon: const Icon(Icons.add_circle),
              color: widget.memoire.couleur,
              onPressed: _addEvent,
              tooltip: 'Ajouter un événement',
            ),
          ],
        ),
        const SizedBox(height: 12),
      
        if (evenements.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Aucun événement.\nAppuyez sur + pour en ajouter.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: evenements.length,
            onReorder: _onReorderEvent,
            itemBuilder: (context, index) {
              final evt = evenements[index];
              return _buildEvenementCard(evt, index, key: ValueKey(evt.nom + index.toString()));
            },
          ),
      ],
    );
  }

  Widget _buildEvenementCard(Evenement evt, int index, {Key? key}) {
    final isSelected = _selectedEvenement?.nom == evt.nom;

    return GestureDetector(
      key: key,
      onTap: () => _onEvenementSelected(evt),
      onDoubleTap: () => _editEvent(evt, index),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: isSelected ? 4 : 2,
        color: isSelected ? evt.couleur.withOpacity(0.05) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isSelected
              ? BorderSide(color: evt.couleur, width: 2)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: evt.couleur.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FaIcon(evt.icone, color: evt.couleur, size: 20),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      evt.nom,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (evt.lieu != null)
                      Row(
                        children: [
                          const FaIcon(
                            FontAwesomeIcons.locationDot,
                            size: 12,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              evt.lieu!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const FaIcon(
                          FontAwesomeIcons.calendar,
                          size: 12,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          evt.dateFormatee,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    if (evt.participants != null &&
                        evt.participants!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const FaIcon(
                            FontAwesomeIcons.users,
                            size: 12,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              evt.participants!.join(', '),
                              style: const TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    color: evt.couleur,
                    onPressed: () => _editEvent(evt, index),
                    tooltip: 'Modifier',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    color: Colors.red,
                    onPressed: () => _deleteEvent(index),
                    tooltip: 'Supprimer',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
