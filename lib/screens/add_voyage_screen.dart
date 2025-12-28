import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import '../models/memoire.dart';
import '../services/geocoding_service.dart';

class AddVoyageScreen extends StatefulWidget {
  final Memoire? voyage;
  const AddVoyageScreen({super.key, this.voyage});

  @override
  State<AddVoyageScreen> createState() => _AddVoyageScreenState();
}

class _AddVoyageScreenState extends State<AddVoyageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _lieuController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _participantsController = TextEditingController();
  
  DateTime? _dateDebut;
  DateTime? _dateFin;
  double? _latitude;
  double? _longitude;
  bool _isSearchingLocation = false;

  bool get _isEditing => widget.voyage != null;

  @override
  void initState() {
    super.initState();
    
    // NOUVEAU : Pré-remplir si édition
    if (_isEditing) {
      final v = widget.voyage!;
      _nomController.text = v.titre;
      _descriptionController.text = v.description;
      _participantsController.text = v.participants.join(', ');
      _dateDebut = v.dateDebut;
      _dateFin = v.dateFin;
      _latitude = v.latitude;
      _longitude = v.longitude;
      
      // Reconstituer le nom du lieu (approximatif)
      if (v.latitude != null && v.longitude != null) {
        _lieuController.text = v.titre;  // Ou chercher avec reverse geocoding
      }
    }
  }
  
  @override
  void dispose() {
    _nomController.dispose();
    _lieuController.dispose();
    _descriptionController.dispose();
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
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📍 Lieu trouvé !', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    result.displayName,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        setState(() => _isSearchingLocation = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('❌ Lieu non trouvé'),
                  const SizedBox(height: 4),
                  Text(
                    'Essayez: "${_lieuController.text}, France" ou "Venise, Italie"',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isSearchingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Erreur de connexion. Vérifiez votre internet.'),
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

  void _saveVoyage() {
    if (!_formKey.currentState!.validate()) return;
    
    if (_dateDebut == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une date de début')),
      );
      return;
    }
    
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez rechercher un lieu valide')),
      );
      return;
    }

    // Créer le voyage
    final voyage = Memoire(
      id: _isEditing ? widget.voyage!.id : 'voyage-${DateTime.now().millisecondsSinceEpoch}',
      categorie: 'voyage',
      titre: _nomController.text,
      dateDebut: _dateDebut!,
      dateFin: _dateFin,
      latitude: _latitude,
      longitude: _longitude,
      description: _descriptionController.text,
      participants: _participantsController.text
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList(),
      photos: _isEditing ? widget.voyage!.photos : [],
      tags: _isEditing ? widget.voyage!.tags : ['nouveau'],
      evenements: _isEditing ? widget.voyage!.evenements : null,
    );

    // Retourner le voyage créé
    Navigator.pop(context, voyage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le voyage' : 'Nouveau voyage'),
        backgroundColor: const Color(0xFF1A3A52),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveVoyage,
            tooltip: 'Enregistrer',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // 1. NOM DU VOYAGE
            _buildSection(
              icon: FontAwesomeIcons.pen,
              title: 'Nom du voyage',
              child: TextFormField(
                controller: _nomController,
                decoration: const InputDecoration(
                  hintText: 'Ex: Venise, Cap-Vert...',
                  border: OutlineInputBorder(),
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
            
            // 2. LIEU
            _buildSection(
              icon: FontAwesomeIcons.locationDot,
              title: 'Où êtes-vous allé ?',
              child: Column(
                children: [
                  TextFormField(
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
                  if (_latitude != null && _longitude != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Coordonnées trouvées',
                            style: TextStyle(color: Colors.green[700], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 3. DATES
            _buildSection(
              icon: FontAwesomeIcons.calendar,
              title: 'Quand ?',
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
            
            // 4. PARTICIPANTS
            _buildSection(
              icon: FontAwesomeIcons.users,
              title: 'Avec qui ?',
              child: TextFormField(
                controller: _participantsController,
                decoration: const InputDecoration(
                  hintText: 'Ex: Matt, Compagne (séparés par virgule)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 5. DESCRIPTION
            _buildSection(
              icon: FontAwesomeIcons.alignLeft,
              title: 'Description (optionnel)',
              child: TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Racontez votre voyage...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // BOUTON ENREGISTRER
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: Text(_isEditing ? 'Enregistrer les modifications' : 'Enregistrer le voyage'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3A52),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _saveVoyage,
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
