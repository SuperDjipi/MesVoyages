import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class Voyage {
  final String id;
  final String nom;
  final double latitude;
  final double longitude;
  final DateTime dateDebut;
  final DateTime dateFin;
  final String type;
  final String description;
  final List<String> participants;
  final List<String> photos;
  final List<Evenement>? evenements;

  Voyage({
    required this.id,
    required this.nom,
    required this.latitude,
    required this.longitude,
    required this.dateDebut,
    required this.dateFin,
    required this.type,
    required this.description,
    required this.participants,
    required this.photos,
    this.evenements,
  });

  factory Voyage.fromJson(Map<String, dynamic> json) {
    return Voyage(
      id: json['id'],
      nom: json['nom'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      dateDebut: DateTime.parse(json['dateDebut']),
      dateFin: DateTime.parse(json['dateFin']),
      type: json['type'],
      description: json['description'],
      participants: List<String>.from(json['participants']),
      photos: List<String>.from(json['photos']),
      evenements: json['evenements'] != null
          ? (json['evenements'] as List).map((e) => Evenement.fromJson(e)).toList()
          : null,
    );
  }

  String get duree {
    final jours = dateFin.difference(dateDebut).inDays + 1;
    return '$jours jours';
  }

  String get periode {
    final formatter = DateFormat('dd/MM/yyyy');
    return '${formatter.format(dateDebut)} - ${formatter.format(dateFin)}';
  }

  // Couleur du pin selon le type
  Color get couleurPin {
    switch (type.toLowerCase()) {
      case 'ville':
        return Colors.red;
      case 'archipel':
        return Colors.blue;
      case 'circuit':
        return Colors.orange;
      case 'nature':
        return Colors.green;
      case 'culturel':
        return const Color(0xFF1A3A52); // Navy
      case 'autre':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  // Icône du pin selon le type
  IconData get iconePin {
    switch (type.toLowerCase()) {
      case 'ville':
        return FontAwesomeIcons.city;
      case 'archipel':
        return FontAwesomeIcons.umbrellaBeach;
      case 'circuit':
        return FontAwesomeIcons.route;
      case 'nature':
        return FontAwesomeIcons.tree;
      case 'culturel':
        return FontAwesomeIcons.landmark;
      case 'autre':
        return FontAwesomeIcons.mapLocationDot;
      default:
        return FontAwesomeIcons.locationDot;
    }
  }
}

class Evenement {
  final String type;
  final String nom;
  final String? lieu;
  final DateTime dateDebut;
  final DateTime? dateFin;
  final double? lat;
  final double? lng;

  Evenement({
    required this.type,
    required this.nom,
    this.lieu,
    required this.dateDebut,
    this.dateFin,
    this.lat,
    this.lng,
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
    );
  }

  String get dateFormatee {
    final formatter = DateFormat('dd/MM/yyyy');
    if (dateFin != null && dateFin != dateDebut) {
      return '${formatter.format(dateDebut)} → ${formatter.format(dateFin!)}';
    }
    return formatter.format(dateDebut);
  }

  // Icône selon le type d'événement
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

  // Couleur selon le type d'événement
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
