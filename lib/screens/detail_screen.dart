import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../config/map_config.dart';
import '../models/memoire.dart';
import '../services/voyage_storage_service.dart';
import '../services/voyage_database.dart';
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

  // Scroll vers un événement dans la liste
  void _onMarkerTapped(Evenement evt) {
    setState(() {
      _selectedEvenement = evt;
    });
    
    // Trouver l'index de l'événement
    final evenements = widget.memoire.evenements ?? [];
    final index = evenements.indexWhere((e) => e.nom == evt.nom);
    
    if (index != -1 && _scrollController.hasClients) {
      // Hauteurs
      final headerSectionHeight = 350.0;  // En-tête + description...
      final evenementsTitleHeight = 50.0;  // Titre "Événements"
      final eventCardHeight = 110.0;  // Hauteur d'une card
    
      // Position de la card dans le scroll
      final cardPosition = headerSectionHeight + evenementsTitleHeight + (index * eventCardHeight);
    
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
        builder: (context) => AddVoyageScreen(voyage: widget.memoire),  // Passer le voyage
      ),
    );
  
    if (voyageModifie != null) {
      // Sauvegarder
      await VoyageStorageService.updateVoyage(voyageModifie);
    
      // Retourner à l'écran principal avec le voyage modifié
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
        builder: (context) => const AddEventScreen(),
      ),
    );
  
    if (nouvelEvent != null) {
      // 1. Prendre les événements existants
      final ancienEvenements = widget.memoire.evenements ?? [];
    
      // 2. Créer une NOUVELLE liste avec l'événement ajouté
      final nouveauxEvenements = [...ancienEvenements, nouvelEvent];
    
      // 3. Créer un NOUVEAU voyage avec cette liste
      final voyageMisAJour = widget.memoire.copyWith(
        evenements: nouveauxEvenements,
      );
    
      // 4. Sauvegarder en base
      await VoyageStorageService.updateVoyage(voyageMisAJour);
    
      // 5. Retourner à l'écran principal avec le voyage modifié
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
      // 1. Copier la liste existante
      final nouveauxEvenements = List<Evenement>.from(widget.memoire.evenements ?? []);
    
      // 2. Remplacer l'événement à l'index
      nouveauxEvenements[index] = eventModifie;
    
      // 3. Créer nouveau voyage
      final voyageMisAJour = widget.memoire.copyWith(
        evenements: nouveauxEvenements,
      );
    
      // 4. Sauvegarder
      await VoyageStorageService.updateVoyage(voyageMisAJour);
    
      // 5. Retour
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
      // 1. Copier la liste
      final nouveauxEvenements = List<Evenement>.from(widget.memoire.evenements ?? []);
    
      // 2. Supprimer l'événement
      nouveauxEvenements.removeAt(index);
    
      // 3. Créer nouveau voyage
      final voyageMisAJour = widget.memoire.copyWith(
        evenements: nouveauxEvenements,
      );
    
      // 4. Sauvegarder
      await VoyageStorageService.updateVoyage(voyageMisAJour);
    
      // 5. Retour
      if (mounted) {
        Navigator.pop(context, voyageMisAJour);
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final hasLocation = widget.memoire.latitude != null && widget.memoire.longitude != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.memoire.titre),
        backgroundColor: const Color(0xFF1A3A52),
        foregroundColor: Colors.white,
        actions: [
          // NOUVEAU : Bouton éditer
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editVoyage(),
            tooltip: 'Modifier',
          ),
        ],
      ),
      body: Column(
        children: [
          // MINI-CARTE STICKY (reste en haut)
          if (hasLocation)
            _buildMiniMap(),
          
          // CONTENU SCROLLABLE
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildDateInfo(),
                    const SizedBox(height: 16),
                    Text(
                      widget.memoire.description,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    if (widget.memoire.participants.isNotEmpty)
                      _buildParticipants(),
                    if (widget.memoire.tags.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildTags(),
                    ],
                    if (widget.memoire.evenements != null && widget.memoire.evenements!.isNotEmpty) ...[
                      const SizedBox(height: 30),
                      _buildEvenements(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMap() {
    final points = <LatLng>[];
    
    if (widget.memoire.latitude != null && widget.memoire.longitude != null) {
      points.add(LatLng(widget.memoire.latitude!, widget.memoire.longitude!));
    }
    
    if (widget.memoire.evenements != null) {
      for (var evt in widget.memoire.evenements!) {
        if (evt.lat != null && evt.lng != null) {
          points.add(LatLng(evt.lat!, evt.lng!));
        }
      }
    }
    
    LatLng center;
    double zoom;
    
    if (points.length == 1) {
      center = points.first;
      zoom = 10.0;
    } else if (points.length > 1) {
      double latSum = 0, lngSum = 0;
      for (var point in points) {
        latSum += point.latitude;
        lngSum += point.longitude;
      }
      center = LatLng(latSum / points.length, lngSum / points.length);
      
      double maxLat = points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
      double minLat = points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
      double maxLng = points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);
      double minLng = points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
      
      double latDiff = maxLat - minLat;
      double lngDiff = maxLng - minLng;
      double maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
      
      if (maxDiff > 10) {
        zoom = 4.0;
      } else if (maxDiff > 5) {
        zoom = 5.0;
      } else if (maxDiff > 2) {
        zoom = 6.0;
      } else if (maxDiff > 1) {
        zoom = 7.0;
      } else if (maxDiff > 0.5) {
        zoom = 8.0;
      } else {
        zoom = 9.0;
      }
    } else {
      center = LatLng(46.5, 2.5);
      zoom = 5.0;
    }

    return Container(
      height: 250,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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
          
          if (points.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  strokeWidth: 3.0,
                  color: widget.memoire.couleur.withOpacity(0.7),
                  borderStrokeWidth: 1.0,
                  borderColor: Colors.white,
                ),
              ],
            ),
          
          MarkerLayer(
            markers: widget.memoire.evenements
                    ?.where((e) => e.lat != null && e.lng != null)
                    .map((evt) {
                  final isSelected = _selectedEvenement?.nom == evt.nom;
                  
                  return Marker(
                    point: LatLng(evt.lat!, evt.lng!),
                    width: 70,
                    height: 70,
                    alignment: Alignment.center,
                    child: GestureDetector(
                      onTap: () => _onMarkerTapped(evt),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.all(isSelected ? 8 : 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: evt.couleur,
                                width: isSelected ? 4 : 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected 
                                      ? evt.couleur.withOpacity(0.5)
                                      : Colors.black.withOpacity(0.2),
                                  blurRadius: isSelected ? 8 : 4,
                                  spreadRadius: isSelected ? 2 : 0,
                                ),
                              ],
                            ),
                            child: FaIcon(
                              evt.icone,
                              size: isSelected ? 20 : 16,
                              color: evt.couleur,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList() ??
                [],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        FaIcon(
          widget.memoire.icone,
          color: widget.memoire.couleur,
          size: 32,
        ),
        const SizedBox(width: 12),
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
                widget.memoire.categorie.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  color: widget.memoire.couleur,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const FaIcon(
              FontAwesomeIcons.calendar,
              size: 16,
              color: Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              widget.memoire.periode,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
        if (widget.memoire.dateFin != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const FaIcon(
                FontAwesomeIcons.clock,
                size: 16,
                color: Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                widget.memoire.duree,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
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
        // EN-TÊTE avec bouton ajouter
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
          
            // BOUTON AJOUTER ÉVÉNEMENT
            IconButton(
              icon: const Icon(Icons.add_circle),
              color: widget.memoire.couleur,
              onPressed: _addEvent,
              tooltip: 'Ajouter un événement',
            ),
          ],
        ),
        const SizedBox(height: 12),
      
        // LISTE RÉORDONNANÇABLE
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
          child: Column(
            children: [
              Row(
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

                  // BOUTONS ACTIONS
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
            ],
          ),
        ),
      ),
    );
  }
}
