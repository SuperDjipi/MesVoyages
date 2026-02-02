# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

```bash
flutter pub get                # Install dependencies
flutter run -d linux           # Run on Linux desktop
flutter run -d android         # Run on Android
flutter run -d ios             # Run on iOS
flutter build apk --release    # Build release APK
flutter analyze                # Lint (uses flutter_lints)
flutter test                   # Run tests (minimal suite currently)
```

Desktop builds (Linux/macOS/Windows) use `sqflite_common_ffi` for SQLite compatibility.

## Architecture

**Flutter app (Dart, SDK ^3.10.4)** — spatio-temporal travel memory mapper with interactive map, timeline, and photo management. All UI is in French.

### Layered structure

- **models/memoire.dart** — All core models in one file: `Memoire` (voyage), `Evenement` (event within a voyage), `Waypoint` (location within an event). Each has category-based color/icon getters. `Voyage` exists for backward compatibility.
- **services/** — Data access and business logic layer:
  - `VoyageStorageService` — Abstraction that routes to SharedPreferences (free tier, max 3 voyages) or SQLite (premium) based on `SubscriptionService.isPremium()`
  - `VoyageDatabase` — SQLite singleton. Schema: `voyages` table with JSON-encoded columns for participants, photos, tags, evenements
  - `PhotoService` — Saves photos as thumbnail (600px) + HD (1920px) variants under `photos/{voyageId}/`
  - `ImportExportService` — ZIP-based export/import with photos. Supports replace/merge/addNew modes
  - `GeocodingService` — Reverse geocoding via Nominatim (OpenStreetMap)
- **screens/** — Four screens: `MainScreen` (map + timeline master view), `DetailScreen` (voyage details with events/photos), `AddVoyageScreen`, `AddEventScreen`
- **widgets/** — `TimelineWidget`, `PhotoGallery`, `PhotoViewer`, `MapPicker`

### Key patterns

- **State management**: StatefulWidget + setState throughout (no BLoC/Provider/Riverpod)
- **Map**: flutter_map with CartoDB Voyager tiles, configured in `config/map_config.dart`
- **Freemium model**: Free tier stores up to 3 voyages in SharedPreferences as JSON; premium uses SQLite. Migration via `migrateToPremium()`
- **Bidirectional sync**: Timeline selection zooms/pans the map; map interaction highlights timeline entries
- **Responsive**: Breakpoints in `utils/responsive.dart` (mobile 600, tablet 900, desktop 1200, largeDesktop 1600)

### Data flow

MainScreen loads voyages via `VoyageStorageService.loadVoyages()` → renders map pins + timeline. Detail/Add screens receive voyage data, modify it, and save back through the storage service. Photos are managed separately on disk by `PhotoService`.

## Conversion Tools

`conversion/` contains Python scripts (`convert_tripit.py`, `convert_memoires.py`) for converting TripIt ICS exports to the app's JSON format (`assets/voyages.json`).
