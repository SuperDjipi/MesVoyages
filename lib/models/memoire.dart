import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class Memoire {
  final String id;
  final String categorie;
  final String titre;
  final DateTime dateDebut;
  final DateTime? dateFin;
  final double? latitude;
  final double? longitude;
  final String description;
  final List<String> participants;
  final List<String> photos;
  final List<String> tags;
  final List<Evenement>? evenements;

  Memoire({
    required this.id,
    required this.categorie,
    required this.titre,
    required this.dateDebut,
    this.dateFin,
    this.latitude,
    this.longitude,
    required this.description,
    required this.participants,
    required this.photos,
    required this.tags,
    this.evenements,
  });

  factory Memoire.fromJson(Map<String, dynamic> json) {
    return Memoire(
      id: json['id'],
      categorie: json['categorie'],
      titre: json['titre'],
      dateDebut: DateTime.parse(json['dateDebut']),
      dateFin: json['dateFin'] != null ? DateTime.parse(json['dateFin']) : null,
      latitude: json['latitude'],
      longitude: json['longitude'],
      description: json['description'],
      participants: List<String>.from(json['participants']),
      photos: List<String>.from(json['photos'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
      evenements: json['evenements'] != null
          ? (json['evenements'] as List).map((e) => Evenement.fromJson(e)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categorie': categorie,
      'titre': titre,
      'dateDebut': dateDebut.toIso8601String(),
      'dateFin': dateFin?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'participants': participants,
      'photos': photos,
      'tags': tags,
      'evenements': evenements?.map((e) => e.toJson()).toList(),
    };
  }

  /// Créer une copie avec modifications
  Memoire copyWith({
    String? id,
    String? categorie,
    String? titre,
    DateTime? dateDebut,
    DateTime? dateFin,
    double? latitude,
    double? longitude,
    String? description,
    List<String>? participants,
    List<String>? photos,
    List<String>? tags,
    List<Evenement>? evenements,
  }) {
    return Memoire(
      id: id ?? this.id,
      categorie: categorie ?? this.categorie,
      titre: titre ?? this.titre,
      dateDebut: dateDebut ?? this.dateDebut,
      dateFin: dateFin ?? this.dateFin,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      description: description ?? this.description,
      participants: participants ?? this.participants,
      photos: photos ?? this.photos,
      tags: tags ?? this.tags,
      evenements: evenements ?? this.evenements,
    );
  }

  String get duree {
    if (dateFin == null) return 'En cours';
    final jours = dateFin!.difference(dateDebut).inDays + 1;
    return '$jours jours';
  }

  String get periode {
    final formatter = DateFormat('dd/MM/yyyy');
    if (dateFin != null) {
      return '${formatter.format(dateDebut)} - ${formatter.format(dateFin!)}';
    }
    return formatter.format(dateDebut);
  }

  String get annee {
    return dateDebut.year.toString();
  }

  // Couleur selon la catégorie
  Color get couleur {
    switch (categorie.toLowerCase()) {
      case 'voyage':
        return Colors.blue;
      case 'realisation':
        return Colors.green;
      case 'professionnel':
        return const Color(0xFF1A3A52);
      case 'familial':
        return Colors.pink;
      case 'culturel':
        return Colors.purple;
      case 'personnel':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // Icône selon la catégorie
  IconData get icone {
    switch (categorie.toLowerCase()) {
      case 'voyage':
        return FontAwesomeIcons.earthEurope;
      case 'realisation':
        return FontAwesomeIcons.lightbulb;
      case 'professionnel':
        return FontAwesomeIcons.briefcase;
      case 'familial':
        return FontAwesomeIcons.peopleGroup;
      case 'culturel':
        return FontAwesomeIcons.mask;
      case 'personnel':
        return FontAwesomeIcons.heart;
      default:
        return FontAwesomeIcons.circle;
    }
  }

  // Pour la carte : icône selon les tags (pour les voyages)
  IconData get iconePin => icone;
        //{
        //    if (categorie != 'voyage') return icone;
    
        //    if (tags.contains('archipel') || tags.contains('plage')) {
        //    return FontAwesomeIcons.umbrellaBeach;
        //  } else if (tags.contains('circuit')) {
        //    return FontAwesomeIcons.route;
        //  } else if (tags.contains('ville')) {
        //    return FontAwesomeIcons.city;
        //  } else if (tags.contains('nature')) {
        //    return FontAwesomeIcons.tree;
        //  } else if (tags.contains('culturel')) {
        //    return FontAwesomeIcons.landmark;
        //  }
        //  return FontAwesomeIcons.locationDot;
        //  }
}

class Evenement {
  final String type;
  final String nom;
  final String? lieu;
  final DateTime dateDebut;
  final DateTime? dateFin;
  final double? lat;
  final double? lng;
  final List<String>? participants;
  final List<String>? photos;

  Evenement({
    required this.type,
    required this.nom,
    this.lieu,
    required this.dateDebut,
    this.dateFin,
    this.lat,
    this.lng,
    this.participants,
    this.photos,
  });

  factory Evenement.fromJson(Map<String, dynamic> json) {
    return Evenement(
      type: json['type'],
      nom: json['nom'],
      lieu: json['lieu'],
      dateDebut: DateTime.parse(json['dateDebut']),
      dateFin: json['dateFin'] != null ? DateTime.parse(json['dateFin']) : null,
      lat: json['lat'],
      lng: json['lng'],
      participants: json['participants'] != null 
          ? List<String>.from(json['participants']) 
          : null,
      photos: json['photos'] != null 
          ? List<String>.from(json['photos']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'nom': nom,
      'lieu': lieu,
      'dateDebut': dateDebut.toIso8601String(),
      'dateFin': dateFin?.toIso8601String(),
      'lat': lat,
      'lng': lng,
      'participants': participants,
      'photos': photos,
    };
  }


  String get dateFormatee {
    final formatter = DateFormat('dd/MM/yyyy');
    if (dateFin != null && dateFin != dateDebut) {
      return '${formatter.format(dateDebut)} → ${formatter.format(dateFin!)}';
    }
    return formatter.format(dateDebut);
  }

  IconData get icone {
    switch (type.toLowerCase()) {
      case 'lodging':
        return FontAwesomeIcons.bed;
      case 'air':
        return FontAwesomeIcons.plane;
      case 'rail':
        return FontAwesomeIcons.train;
      case 'car':
        return FontAwesomeIcons.car;
      case 'activity':
        return FontAwesomeIcons.ticket;
      case 'restaurant':
        return FontAwesomeIcons.utensils;
      default:
        return FontAwesomeIcons.circleInfo;
    }
  }

  Color get couleur {
    switch (type.toLowerCase()) {
      case 'lodging':
        return Colors.blue;
      case 'air':
        return Colors.indigo;
      case 'rail':
        return Colors.teal;
      case 'car':
        return Colors.orange;
      case 'activity':
        return Colors.green;
      case 'restaurant':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }
}
