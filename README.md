# 🗺️ Voyage Map - Application de Mémoires de Voyages

Application Flutter pour cartographier et chronologiser vos voyages avec une interface interactive.

## ✨ Fonctionnalités

### 🎯 Principales
- **Carte interactive** avec pins géolocalisés par voyage
- **Timeline chronologique** synchronisée avec la carte
- **Gestion complète des voyages** (CRUD)
- **Gestion des événements** par voyage (hébergements, vols, activités...)
- **Géolocalisation automatique** via Nominatim (OpenStreetMap)
- **Stockage local** avec Sqflite

### 🎨 Interface
- Synchronisation bidirectionnelle carte ↔ timeline
- Mini-carte des étapes dans les détails
- Design navy blue / crème / vert
- Interface en français

### 💰 Modèle freemium
- **Gratuit** : 3 voyages maximum
- **Premium** : Voyages illimités + fonctionnalités avancées

## 🚀 Installation

### Prérequis
- Flutter SDK 3.38+ 
- Android SDK (pour build Android)

### Installation
```bash
# Cloner le repo
git clone https://github.com/VOTRE_USERNAME/voyage-map-public.git
cd voyage-map-public

# Installer les dépendances
flutter pub get

# Lancer sur Linux
flutter run -d linux

# Ou sur Android
flutter run -d android
```

### Build APK
```bash
flutter build apk --release
# APK dans : build/app/outputs/flutter-apk/app-release.apk
```

## 📱 Technologies

- **Flutter** 3.38.5
- **Sqflite** - Base de données locale
- **flutter_map** - Cartes OpenStreetMap
- **Nominatim** - Géocodage
- **font_awesome_flutter** - Icônes

## 📊 Structure du projet
```
lib/
├── models/
│   └── memoire.dart          # Modèles Voyage et Evenement
├── screens/
│   ├── main_screen.dart      # Écran principal (carte + timeline)
│   ├── detail_screen.dart    # Détails d'un voyage
│   ├── add_voyage_screen.dart  # Formulaire voyage
│   └── add_event_screen.dart   # Formulaire événement
├── services/
│   ├── voyage_database.dart      # Sqflite
│   ├── voyage_storage_service.dart  # Couche d'abstraction
│   ├── subscription_service.dart    # Gestion freemium
│   └── geocoding_service.dart       # Nominatim
└── widgets/
    └── timeline_widget.dart   # Widget timeline
```

## 🗺️ Format des données

Les voyages sont stockés au format JSON :
```json
{
  "memoires": [
    {
      "id": "voyage-123",
      "categorie": "voyage",
      "titre": "Venise",
      "dateDebut": "2024-01-01",
      "dateFin": "2024-01-05",
      "latitude": 45.4408,
      "longitude": 12.3155,
      "description": "Réveillon à Venise",
      "participants": ["Matt", "Compagne"],
      "tags": ["ville", "culturel"],
      "evenements": [...]
    }
  ]
}
```

## 📄 License

Ce projet utilise :
- **OpenStreetMap** - Données cartographiques (© OpenStreetMap contributors)
- **flutter_map** - BSD-3 License

## 🔮 Roadmap

- [ ] Gestion des photos par voyage/événement
- [ ] Export PDF
- [ ] Synchronisation cloud
- [ ] Mode "Raconter" (narration automatique)
- [ ] Partage de voyages entre utilisateurs

## 👨‍💻 Auteur

Matt - Aix-en-Provence

---

**Version actuelle : 0.5.0**
