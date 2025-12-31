import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../config/map_config.dart';

class MapPicker extends StatefulWidget {
  final LatLng? initialPosition;
  final String? locationName;
  
  const MapPicker({
    super.key,
    this.initialPosition,
    this.locationName,
  });

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  late LatLng _selectedPosition;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.initialPosition ?? LatLng(48.8566, 2.3522); // Paris par défaut
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Placer le pin'),
        backgroundColor: const Color(0xFF1A3A52),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => Navigator.pop(context, _selectedPosition),
            tooltip: 'Valider',
          ),
        ],
      ),
      body: Stack(
        children: [
          // CARTE
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPosition,
              initialZoom: 12.0,
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedPosition = point;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: MapConfig.tileUrl,
                subdomains: MapConfig.subdomains,
                userAgentPackageName: MapConfig.userAgent,
                maxNativeZoom: MapConfig.maxNativeZoom,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedPosition,
                    width: 80,
                    height: 80,
                    alignment: Alignment.bottomCenter,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FaIcon(
                          FontAwesomeIcons.locationDot,
                          color: Colors.red,
                          size: 40,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          // INSTRUCTIONS EN HAUT
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.locationName != null)
                      Text(
                        widget.locationName!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.touch_app, size: 16, color: Colors.grey),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tapez sur la carte pour placer le pin',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // COORDONNÉES EN BAS
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lat: ${_selectedPosition.latitude.toStringAsFixed(6)}\n'
                        'Lng: ${_selectedPosition.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
