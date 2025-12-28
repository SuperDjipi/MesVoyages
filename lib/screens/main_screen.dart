import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';  // Pour kReleaseMode
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/memoire.dart';
// import '../services/voyage_service.dart';
import '../services/voyage_storage_service.dart'; 
import '../services/subscription_service.dart';  
import '../widgets/timeline_widget.dart';
import 'detail_screen.dart';
import 'add_voyage_screen.dart';
import '../services/voyage_database.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final MapController _mapController = MapController();
  final ScrollController _timelineScrollController = ScrollController();
  
  List<Memoire> _voyages = [];  
  Memoire? _selectedVoyage;  
  bool _isLoading = true;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _loadVoyages();
  }

  @override
  void dispose() {
    _timelineScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadVoyages() async {
    final voyages = await VoyageStorageService.loadVoyages();
    final premium = await SubscriptionService.isPremium();
    
    setState(() {
      _voyages = voyages;
      _isPremium = premium;
      _isLoading = false;
    });
  }

  void _onVoyageSelectedFromTimeline(Memoire voyage) {
    setState(() {
      _selectedVoyage = voyage;
    });
    
    if (voyage.latitude != null && voyage.longitude != null) {
      _mapController.move(
        LatLng(voyage.latitude!, voyage.longitude!),
        6.0,
      );
    }
  }

  Future<void> _addVoyage() async {
    final nouveauVoyage = await Navigator.push<Memoire>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddVoyageScreen(),
      ),
    );
  
    if (nouveauVoyage != null) {
      // Tenter de sauvegarder
      final success = await VoyageStorageService.saveVoyage(nouveauVoyage);
    
      if (success) {
        setState(() {
          _voyages.add(nouveauVoyage);
        });
       
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Voyage ajouté !'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Limite atteinte !
        _showPremiumDialog();
      }
    }
  }

  void _onMarkerTapped(Memoire voyage) {
    setState(() {
      _selectedVoyage = voyage;
    });
    _scrollTimelineToVoyage(voyage);
  }

  void _scrollTimelineToVoyage(Memoire voyage) {
    final sortedVoyages = List<Memoire>.from(_voyages)
      ..sort((a, b) => b.dateDebut.compareTo(a.dateDebut));
    
    final index = sortedVoyages.indexWhere((m) => m.id == voyage.id);
    
    if (index != -1 && _timelineScrollController.hasClients) {
      final position = index * 120.0;
      _timelineScrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showDetails(Memoire voyage) async {
    final voyageModifie = await Navigator.push<Memoire>(
      context,
      MaterialPageRoute(
        builder: (context) => DetailScreen(memoire: voyage),
      ),
    );
  
    // Si le voyage a été modifié
    if (voyageModifie != null) {
      setState(() {
        final index = _voyages.indexWhere((v) => v.id == voyageModifie.id);
        if (index != -1) {
          _voyages[index] = voyageModifie;
        }
      });
    
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Voyage modifié !'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('À propos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mes Voyages v1.0.0'),
            const SizedBox(height: 16),
            const Text(
              'Cette application utilise :',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.map, size: 16),
              label: const Text('© OpenStreetMap contributors'),
              onPressed: () => launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright'),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.code, size: 16),
              label: const Text('flutter_map (BSD-3 License)'),
              onPressed: () => launchUrl(
                Uri.parse('https://pub.dev/packages/flutter_map'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.lock, color: Colors.orange),
            SizedBox(width: 8),
            Text('Limite atteinte'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version gratuite : ${SubscriptionService.FREE_VOYAGE_LIMIT} voyages maximum',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Passez à la version PRO pour :'),
            const SizedBox(height: 8),
            _premiumFeature('Voyages illimités'),
            _premiumFeature('Sauvegarde automatique'),
            _premiumFeature('Photos par voyage'),
            _premiumFeature('Export/Import illimité'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.star),
            label: const Text('Débloquer - 2,99€'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _unlockPremium();
            },
          ),
        ],
      ),
    );
  }

  Widget _premiumFeature(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  Future<void> _unlockPremium() async {
    // Pour l'instant : simulation (mode dev)
    // Plus tard : intégration Google Play Billing
  
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  
    await Future.delayed(const Duration(seconds: 1));  // Simule paiement
  
    // Migration
    await VoyageStorageService.migrateToPremium();
  
    // Recharger
    await _loadVoyages();
  
    Navigator.pop(context);  // Fermer le loader
  
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 Version PRO activée !'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }
  
  Future<void> _importAllVoyages() async {
    // Confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importer tous les voyages ?'),
        content: const Text(
          'Cette action va :\n'
          '1. Activer la version PRO\n'
          '2. Importer tous les voyages depuis le JSON\n'
          '3. Les sauvegarder en base Sqflite\n\n'
          'Continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Importer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Afficher loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Import en cours...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    try {
      // 1. Activer premium
      await SubscriptionService.activatePremium();

      // 2. Charger tous les voyages depuis le JSON
      final String response = await rootBundle.loadString(
        'assets/voyages.json',
      );
      final data = json.decode(response);
      final List<dynamic> memoiresJson = data['memoires'];

      // 3. Filtrer uniquement les voyages
      final voyages = memoiresJson
          .map((json) => Memoire.fromJson(json))
          .where((m) => m.categorie == 'voyage')
          .toList();

      // 4. Insérer en base
      for (var voyage in voyages) {
        await VoyageDatabase.instance.insertVoyage(voyage);
      }

      // 5. Recharger
      await _loadVoyages();

      Navigator.pop(context); // Fermer loader

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${voyages.length} voyages importés !'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Fermer loader

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur import : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Mes Voyages (${_voyages.length})'),
        backgroundColor: const Color(0xFF1A3A52),
        foregroundColor: Colors.white,
        actions: [
          // Badge PRO (avant les autres boutons)
          if (_isPremium)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '⭐ PRO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          // BOUTON DEBUG (temporaire)
          if (!kReleaseMode) // Seulement en mode debug
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: _importAllVoyages,
              tooltip: 'Importer tous les voyages',
            ),

          // Bouton À propos
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showAbout,
            tooltip: 'À propos',
          ),
    
          // Bouton détails (si sélection)
          if (_selectedVoyage != null)
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.circleInfo),
              onPressed: () => _showDetails(_selectedVoyage!),
              tooltip: 'Voir les détails',
            ),
        ],
      ),
      body: Column(
        children: [
          // CARTE (60%) avec attribution
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(46.5, 2.5),
                    initialZoom: 5.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'club.djipi.voyage_map_public',
                    ),
                    MarkerLayer(
                      markers: _voyages
                          .where((v) => v.latitude != null && v.longitude != null)
                          .map((voyage) {
                        final isSelected = _selectedVoyage?.id == voyage.id;
                        
                        return Marker(
                          point: LatLng(voyage.latitude!, voyage.longitude!),
                          width: 100,
                          height: isSelected ? 100 : 80,
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
                            onTap: () => _onMarkerTapped(voyage),
                            onDoubleTap: () => _showDetails(voyage),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FaIcon(
                                  voyage.iconePin,
                                  color: voyage.couleur,
                                  size: isSelected ? 40 : 30,
                                ),
                                if (isSelected)
                                  Container(
                                    constraints: const BoxConstraints(maxWidth: 90),
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      voyage.titre,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                
                // Attribution OpenStreetMap (en bas à droite)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: GestureDetector(
                    onTap: () => launchUrl(
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '© OpenStreetMap',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // SÉPARATEUR
          Container(
            height: 2,
            color: Colors.grey[300],
          ),
          
          // TIMELINE (40%)
          Expanded(
            flex: 4,
            child: TimelineWidget(
              scrollController: _timelineScrollController,
              memoires: _voyages,
              selectedMemoire: _selectedVoyage,
              onMemoireSelected: _onVoyageSelectedFromTimeline,
              onMemoireDoubleTapped: _showDetails,
            ),
          ),
        ],
      ),
      
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Bouton ajouter voyage
          FloatingActionButton(
            heroTag: 'add',
            onPressed: _addVoyage,
            backgroundColor: Colors.green,
            child: const Icon(Icons.add, color: Colors.white),
          ),
          const SizedBox(height: 12),
          // Bouton détails (si sélection)
          if (_selectedVoyage != null)
            FloatingActionButton(
              heroTag: 'details',
              onPressed: () => _showDetails(_selectedVoyage!),
              backgroundColor: _selectedVoyage!.couleur,
              child: const FaIcon(FontAwesomeIcons.circleInfo, color: Colors.white),
            ),
        ],
      ),
    );
  }
}
