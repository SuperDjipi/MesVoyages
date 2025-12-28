import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../models/memoire.dart';
import '../services/geocoding_service.dart';

class AddEventScreen extends StatefulWidget {
  final Evenement? evenement;  // null = nouveau, sinon = édition
  
  const AddEventScreen({super.key, this.evenement});

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
  
  bool get _isEditing => widget.evenement != null;

  static const Map<String, EventTypeInfo> _eventTypes = {
    'lodging': EventTypeInfo('Hébergement', FontAwesomeIcons.bed, Colors.blue),
    'air': EventTypeInfo('Vol', FontAwesomeIcons.plane, Colors.indigo),
    'rail': EventTypeInfo('Train', FontAwesomeIcons.train, Colors.teal),
    'car': EventTypeInfo('Voiture', FontAwesomeIcons.car, Colors.orange),
    'activity': EventTypeInfo('Activité', FontAwesomeIcons.ticket, Colors.green),
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

  void _saveEvent() {
    if (!_formKey.currentState!.validate()) return;
    
    if (_dateDebut == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une date')),
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
    );

    Navigator.pop(context, evenement);
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
              child: TextFormField(
                controller: _lieuController,
                decoration: InputDecoration(
                  hintText: 'Ex: Venise, Italie',
                  helperText: 'Format: Ville, Pays',
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
                        ),
                ),
                onFieldSubmitted: (_) => _searchLocation(),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // DATES
            _buildSection(
              icon: FontAwesomeIcons.calendar,
              title: 'Dates',
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event),
                      label: Text(
                        _dateDebut == null
                            ? 'Date début'
                            : DateFormat('dd/MM/yyyy').format(_dateDebut!),
                      ),
                      onPressed: () => _selectDate(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event),
                      label: Text(
                        _dateFin == null
                            ? 'Date fin (opt.)'
                            : DateFormat('dd/MM/yyyy').format(_dateFin!),
                      ),
                      onPressed: () => _selectDate(false),
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
            
            const SizedBox(height: 32),
            
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
