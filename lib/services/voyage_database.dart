import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/memoire.dart';

class VoyageDatabase {
  static final VoyageDatabase instance = VoyageDatabase._init();
  static Database? _database;

  VoyageDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('voyages.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL';
    const textNullableType = 'TEXT';

    await db.execute('''
      CREATE TABLE voyages (
        id $idType,
        categorie $textType,
        titre $textType,
        dateDebut $textType,
        dateFin $textNullableType,
        latitude $realType,
        longitude $realType,
        description $textType,
        participants $textType,
        photos $textType,
        tags $textType,
        evenements $textNullableType
      )
    ''');
  }

  // Insérer un voyage
  Future<void> insertVoyage(Memoire voyage) async {
    final db = await instance.database;
    
    await db.insert(
      'voyages',
      {
        'id': voyage.id,
        'categorie': voyage.categorie,
        'titre': voyage.titre,
        'dateDebut': voyage.dateDebut.toIso8601String(),
        'dateFin': voyage.dateFin?.toIso8601String(),
        'latitude': voyage.latitude,
        'longitude': voyage.longitude,
        'description': voyage.description,
        'participants': json.encode(voyage.participants),
        'photos': json.encode(voyage.photos),
        'tags': json.encode(voyage.tags),
        'evenements': voyage.evenements != null
            ? json.encode(voyage.evenements!.map((e) => e.toJson()).toList())
            : null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Récupérer tous les voyages
  Future<List<Memoire>> getAllVoyages() async {
    final db = await instance.database;
    final result = await db.query('voyages', orderBy: 'dateDebut DESC');

    return result.map((json) => _voyageFromJson(json)).toList();
  }

  // Récupérer un voyage par ID
  Future<Memoire?> getVoyage(String id) async {
    final db = await instance.database;
    final result = await db.query(
      'voyages',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isNotEmpty) {
      return _voyageFromJson(result.first);
    }
    return null;
  }

  // Mettre à jour un voyage
  Future<void> updateVoyage(Memoire voyage) async {
    final db = await instance.database;

    await db.update(
      'voyages',
      {
        'categorie': voyage.categorie,
        'titre': voyage.titre,
        'dateDebut': voyage.dateDebut.toIso8601String(),
        'dateFin': voyage.dateFin?.toIso8601String(),
        'latitude': voyage.latitude,
        'longitude': voyage.longitude,
        'description': voyage.description,
        'participants': json.encode(voyage.participants),
        'photos': json.encode(voyage.photos),
        'tags': json.encode(voyage.tags),
        'evenements': voyage.evenements != null
            ? json.encode(voyage.evenements!.map((e) => e.toJson()).toList())
            : null,
      },
      where: 'id = ?',
      whereArgs: [voyage.id],
    );
  }

  // Supprimer un voyage
  Future<void> deleteVoyage(String id) async {
    final db = await instance.database;
    await db.delete(
      'voyages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Compter les voyages
  Future<int> getVoyageCount() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM voyages');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Fermer la base
  Future close() async {
    final db = await instance.database;
    db.close();
  }

  // Convertir JSON DB → Memoire
  Memoire _voyageFromJson(Map<String, dynamic> json) {
    return Memoire(
      id: json['id'],
      categorie: json['categorie'],
      titre: json['titre'],
      dateDebut: DateTime.parse(json['dateDebut']),
      dateFin: json['dateFin'] != null ? DateTime.parse(json['dateFin']) : null,
      latitude: json['latitude'],
      longitude: json['longitude'],
      description: json['description'],
      participants: List<String>.from(jsonDecode(json['participants'])),
      photos: List<String>.from(jsonDecode(json['photos'])),
      tags: List<String>.from(jsonDecode(json['tags'])),
      evenements: json['evenements'] != null
          ? (jsonDecode(json['evenements']) as List)
              .map((e) => Evenement.fromJson(e))
              .toList()
          : null,
    );
  }
}
