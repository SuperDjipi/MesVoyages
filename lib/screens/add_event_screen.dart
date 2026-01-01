import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../models/memoire.dart';
import '../services/geocoding_service.dart';
import '../widgets/map_picker.dart';

class AddEventScreen extends StatefulWidget {
  final Evenement? evenement;  // null = nouveau, sinon = édition
  final Memoire? voyage;  // voyage parent pour les valeurs par défaut
  
  const AddEventScreen({super.key, this.evenement, this.voyage});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _lieuController = TextEditingController();
  final _participantsController = TextEditingController();
  
  String _type = 'lodging';  // Type par défaut
  DateTime? _dateDebut;
  DateTime? _dateFin;
  double? _latitude;
  double? _longitude;
  bool _isSearchingLocation = false;
  List<Waypoint> _waypoints = [];
  
  bool get _isEditing => widget.evenement != null;

  // Types supportant les waypoints
  bool get _supportsWaypoints => _type == 'day_tour' || _type == 'air_journey'; 

  static const Map<String, EventTypeInfo> _eventTypes = {
    'lodging': EventTypeInfo('Hébergement', FontAwesomeIcons.bed, Colors.blue),
    'air': EventTypeInfo('Vol', FontAwesomeIcons.plane, Colors.indigo),
    'air_journey': EventTypeInfo('Vol multi-segments', FontAwesomeIcons.planeArrival, Colors.deepPurple),
    'rail': EventTypeInfo('Train', FontAwesomeIcons.train, Colors.teal),
    'car': EventTypeInfo('Voiture', FontAwesomeIcons.car, Colors.orange),
    'day_tour': EventTypeInfo('Journée visite', FontAwesomeIcons.car, Colors.purple),
    'activity': EventTypeInfo('Activité', FontAwesomeIcons.ticket, Colors.green),
    'hike': EventTypeInfo('Randonnée', FontAwesomeIcons.personHiking, Colors.brown),
    'restaurant': EventTypeInfo('Restaurant', FontAwesomeIcons.utensils, Colors.redAccent),
    'other': EventTypeInfo('Autre', FontAwesomeIcons.circleInfo, Colors.grey),
  };

  @override
  void initState() {
    super.initState();
    
    if (_isEditing) {
      final e = widget.evenement!;
      _nomController.text = e.nom;
      _lieuController.text = e.lieu ?? '';
      _participantsController.text = e.participants?.join(', ') ?? '';
      _type = e.type;
      _dateDebut = e.dateDebut;
      _dateFin = e.dateFin;
      _latitude = e.lat;
      _longitude = e.lng;
      _waypoints = e.waypoints ?? [];
    } else if (widget.voyage != null) {
      // Mode création : pré-remplir avec les infos du voyage
      _dateDebut = widget.voyage!.dateDebut;  // ← Date début voyage
      _dateFin = widget.voyage!.dateFin;      // ← Date fin voyage (peut être null)
      _latitude = widget.voyage!.latitude;
      _longitude = widget.voyage!.longitude;
      _participantsController.text = widget.voyage!.participants.join(', ');
      
      // Optionnel : pré-remplir le lieu
      if (widget.voyage!.latitude != null && widget.voyage!.longitude != null) {
        _lieuController.text = widget.voyage!.titre;  // Approximation
      }
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _lieuController.dispose();
    _participantsController.dispose();
    super.dispose();
  }

  Future<void> _searchLocation() async {
    if (_lieuController.text.isEmpty) return;
    
    setState(() => _isSearchingLocation = true);
    
    try {
      final result = await GeocodingService.searchLocation(_lieuController.text);
      
      if (result != null) {
        setState(() {
          _latitude = result.latitude;
          _longitude = result.longitude;
          _isSearchingLocation = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📍 Lieu trouvé : ${result.displayName}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() => _isSearchingLocation = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Lieu non trouvé'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isSearchingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Erreur de connexion'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickLocationOnMap() async {
    final initialPosition = (_latitude != null && _longitude != null)
        ? LatLng(_latitude!, _longitude!)
        : null;
  
    final selectedPosition = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (context) => MapPicker(
          initialPosition: initialPosition,
          locationName: _nomController.text.isNotEmpty ? _nomController.text : null,
        ),
      ),
    );
  
    if (selectedPosition != null) {
      setState(() {
        _latitude = selectedPosition.latitude;
        _longitude = selectedPosition.longitude;
      });
    
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📍 Position définie sur la carte'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _selectDate(bool isDebut) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
    );
    
    if (picked != null) {
      setState(() {
        if (isDebut) {
          _dateDebut = picked;
        } else {
          _dateFin = picked;
        }
      });
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateDebut != null
          ? DateTimeRange(
              start: _dateDebut!,
              end: _dateFin ?? _dateDebut!,
            )
          : null,
      locale: const Locale('fr', 'FR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF1A3A52),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
  
    if (picked != null) {
      setState(() {
        _dateDebut = picked.start;
        _dateFin = picked.end != picked.start ? picked.end : null;
      });
    }
  }

  void _saveEvent() {
    if (!_formKey.currentState!.validate()) return;
    
    if (_dateDebut == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une date')),
      );
      return;
    }

    // Validation : date fin après date début
    if (_dateFin != null && _dateFin!.isBefore(_dateDebut!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ La date de fin doit être après la date de début'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final evenement = Evenement(
      type: _type,
      nom: _nomController.text,
      lieu: _lieuController.text.isNotEmpty ? _lieuController.text : null,
      dateDebut: _dateDebut!,
      dateFin: _dateFin,
      lat: _latitude,
      lng: _longitude,
      participants: _participantsController.text.isNotEmpty
          ? _participantsController.text.split(',').map((p) => p.trim()).toList()
          : null,
      photos: _isEditing ? widget.evenement!.photos : null,
      waypoints: _waypoints.isNotEmpty ? _waypoints : null,
    );

    Navigator.pop(context, evenement);
  }

  Widget _buildWaypointCard(Waypoint waypoint, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: waypoint.couleur.withOpacity(0.2),
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: waypoint.couleur,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(waypoint.nom),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${waypoint.lat.toStringAsFixed(4)}, ${waypoint.lng.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 11),
            ),
            if (waypoint.heure != null)
              Text('🕐 ${waypoint.heure}', style: const TextStyle(fontSize: 11)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => _editWaypoint(index),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
              onPressed: () => _deleteWaypoint(index),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),  
    );
  }

  Future<void> _addWaypoint() async {
    final waypoint = await _showWaypointDialog();
  
    if (waypoint != null) {
      setState(() {
        _waypoints.add(waypoint);
      });
    }
  }

  Future<void> _editWaypoint(int index) async {
    final waypoint = await _showWaypointDialog(existing: _waypoints[index]);
  
    if (waypoint != null) {
      setState(() {
        _waypoints[index] = waypoint;
      });
    }
  }

  void _deleteWaypoint(int index) {
    setState(() {
      _waypoints.removeAt(index);
    });
  }

  Future<Waypoint?> _showWaypointDialog({Waypoint? existing}) async {
    final nomController = TextEditingController(text: existing?.nom ?? '');
    final heureController = TextEditingController(text: existing?.heure ?? '');
    double? lat = existing?.lat;
    double? lng = existing?.lng;
    String? selectedType = existing?.type ?? (_type == 'day_tour' ? 'activity' : null);
  
    return showDialog<Waypoint>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Ajouter un point' : 'Modifier le point'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nom
                TextField(
                  controller: nomController,
                  decoration: InputDecoration(
                    labelText: _type == 'day_tour' ? 'Nom du lieu' : 'Aéroport/Vol',
                    hintText: _type == 'day_tour' ? 'Ex: Palais des Doges' : 'Ex: AMS (KL5678)',
                    border: const OutlineInputBorder(),
                  ),
                ),
               
                const SizedBox(height: 16),
              
                // Type (seulement pour day_tour)
                if (_type == 'day_tour') ...[
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'activity', child: Text('🎭 Activité')),
                      DropdownMenuItem(value: 'restaurant', child: Text('🍽️ Restaurant')),
                      DropdownMenuItem(value: 'viewpoint', child: Text('📸 Point de vue')),
                      DropdownMenuItem(value: 'lodging', child: Text('🛏️ Hébergement')),
                      DropdownMenuItem(value: null, child: Text('📍 Autre')),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedType = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              
                // Heure (optionnel)
                TextField(
                  controller: heureController,
                  decoration: const InputDecoration(
                    labelText: 'Heure (optionnel)',
                    hintText: 'Ex: 14:30',
                    border: OutlineInputBorder(),
                  ),
                ),
              
                const SizedBox(height: 16),
              
                // Bouton placer sur carte
                OutlinedButton.icon(
                  icon: const Icon(Icons.map),
                  label: Text(
                    lat != null && lng != null
                        ? 'Position définie ✓'
                        : 'Placer sur la carte',
                  ),
                  onPressed: () async {
                    // Déterminer la position initiale intelligemment
                    LatLng? initialPosition;
    
                    if (lat != null && lng != null) {
                      // Si le waypoint a déjà une position, l'utiliser
                      initialPosition = LatLng(lat!, lng!);
                    } else if (_waypoints.isNotEmpty) {
                      // Sinon, utiliser la position du dernier waypoint
                      final lastWaypoint = _waypoints.last;
                      initialPosition = LatLng(lastWaypoint.lat, lastWaypoint.lng);
                    } else if (_latitude != null && _longitude != null) {
                      // Sinon, utiliser la position de l'événement
                      initialPosition = LatLng(_latitude!, _longitude!);
                    } else if (widget.voyage != null && 
                               widget.voyage!.latitude != null && 
                               widget.voyage!.longitude != null) {
                      // Sinon, utiliser la position du voyage
                      initialPosition = LatLng(
                        widget.voyage!.latitude!, 
                        widget.voyage!.longitude!,
                      );
                    }
                    // Sinon, MapPicker utilisera Paris par défaut (son propre fallback)
    
                    final position = await Navigator.push<LatLng>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MapPicker(
                          initialPosition: initialPosition,
                         locationName: nomController.text.isNotEmpty 
                              ? nomController.text 
                              : (_type == 'day_tour' ? 'Point d\'intérêt' : 'Segment de vol'),
                        ),
                      ),
                    );
                  
                    if (position != null) {
                      setDialogState(() {
                        lat = position.latitude;
                        lng = position.longitude;
                      });
                    }
                  },
                ),
              
                if (lat != null && lng != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${lat!.toStringAsFixed(4)}, ${lng!.toStringAsFixed(4)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nomController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Le nom est obligatoire')),
                  );
                  return;
                }
              
                if (lat == null || lng == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Position obligatoire')),
                  );
                  return;
                }
              
                Navigator.pop(
                  context,
                  Waypoint(
                    nom: nomController.text,
                    lat: lat!,
                    lng: lng!,
                    heure: heureController.text.isNotEmpty ? heureController.text : null,
                    type: selectedType,
                  ),
                );
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typeInfo = _eventTypes[_type]!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier l\'événement' : 'Nouvel événement'),
        backgroundColor: const Color(0xFF1A3A52),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveEvent,
            tooltip: 'Enregistrer',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // TYPE D'ÉVÉNEMENT
            _buildSection(
              icon: FontAwesomeIcons.tag,
              title: 'Type d\'événement',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _eventTypes.entries.map((entry) {
                  final selected = _type == entry.key;
                  final info = entry.value;
                  
                  return FilterChip(
                    selected: selected,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FaIcon(info.icon, size: 14, color: selected ? Colors.white : info.color),
                        const SizedBox(width: 6),
                        Text(info.label),
                      ],
                    ),
                    onSelected: (_) => setState(() => _type = entry.key),
                    selectedColor: info.color,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                    ),
                  );
                }).toList(),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // NOM
            _buildSection(
              icon: typeInfo.icon,
              title: 'Nom',
              child: TextFormField(
                controller: _nomController,
                decoration: InputDecoration(
                  hintText: 'Ex: Hôtel Rialto, Vol Paris-Venise...',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(typeInfo.icon, color: typeInfo.color),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Le nom est obligatoire';
                  }
                  return null;
                },
              ),
            ),
            
            const SizedBox(height: 24),
            
            // LIEU
            _buildSection(
              icon: FontAwesomeIcons.locationDot,
              title: 'Lieu (optionnel)',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _lieuController,
                          decoration: InputDecoration(
                            hintText: 'Ex: Venise, Italie',
                            helperText: 'Rechercher ou placer sur carte',
                            helperStyle: const TextStyle(fontSize: 11),
                            border: const OutlineInputBorder(),
                            suffixIcon: _isSearchingLocation
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.search),
                                    onPressed: _searchLocation,
                                    tooltip: 'Rechercher',
                                  ),
                          ),
                          onFieldSubmitted: (_) => _searchLocation(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A3A52).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.map, color: Color(0xFF1A3A52)),
                          onPressed: _pickLocationOnMap,
                          tooltip: 'Placer sur carte',
                        ),
                      ),
                    ],
                  ),
                  if (_latitude != null && _longitude != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Position définie',
                            style: TextStyle(color: Colors.green[700], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // DATES - Version range picker
            _buildSection(
              icon: FontAwesomeIcons.calendar,
              title: 'Dates',
              child: Column(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _dateDebut == null
                          ? 'Sélectionner les dates'
                          : _dateFin == null
                              ? DateFormat('dd/MM/yyyy').format(_dateDebut!)
                              : '${DateFormat('dd/MM/yyyy').format(_dateDebut!)} → ${DateFormat('dd/MM/yyyy').format(_dateFin!)}',
                    ),
                    onPressed: _selectDateRange,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  if (_dateDebut != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _dateFin == null
                                  ? 'Une seule journée'
                                  : '${_dateFin!.difference(_dateDebut!).inDays + 1} jour(s)',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              _dateDebut = null;
                              _dateFin = null;
                            }),
                            child: const Text('Effacer', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // PARTICIPANTS
            _buildSection(
              icon: FontAwesomeIcons.users,
              title: 'Participants (optionnel)',
              child: TextFormField(
                controller: _participantsController,
                decoration: const InputDecoration(
                  hintText: 'Ex: Matt, Compagne',
                  border: OutlineInputBorder(),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // WAYPOINTS (seulement pour day_tour et air_journey)
            if (_supportsWaypoints) ...[
              _buildSection(
                icon: FontAwesomeIcons.mapPin,
                title: _type == 'day_tour' 
                    ? 'Points d\'intérêt (${_waypoints.length})'
                    : 'Segments de vol (${_waypoints.length})',
                child: Column(
                  children: [
                    // Liste des waypoints
                    if (_waypoints.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            _type == 'day_tour'
                                ? 'Aucun point d\'intérêt.\nAjoutez les lieux visités pendant cette journée.'
                                : 'Aucun segment.\nAjoutez les vols composant ce trajet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      )
                    else
                      ...List.generate(_waypoints.length, (index) {
                        return _buildWaypointCard(_waypoints[index], index);
                      }),
        
                    const SizedBox(height: 12),
        
                    // Bouton ajouter waypoint
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_location),
                      label: Text(_type == 'day_tour' ? 'Ajouter un point' : 'Ajouter un vol'),
                      onPressed: _addWaypoint,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            const SizedBox(height: 34),
            
            // BOUTON ENREGISTRER
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: Text(_isEditing ? 'Enregistrer les modifications' : 'Ajouter l\'événement'),
              style: ElevatedButton.styleFrom(
                backgroundColor: typeInfo.color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _saveEvent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FaIcon(icon, size: 18, color: const Color(0xFF1A3A52)),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A3A52),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class EventTypeInfo {
  final String label;
  final IconData icon;
  final Color color;
  
  const EventTypeInfo(this.label, this.icon, this.color);
}
