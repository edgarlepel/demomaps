import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Capitales de Paraguay',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MapScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Capital {
  final String name;
  final String department;
  final int population;
  final LatLng coordinates;

  const Capital({
    required this.name,
    required this.department,
    required this.population,
    required this.coordinates,
  });
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late MapController mapController;
  final List<Marker> _markers = [];
  bool _isLoading = true;

  late RangeValues _currentPopulationRange;
  String? _selectedDepartment;
  List<String> _departments = ['Todos'];

  // Datos actualizados de las capitales de Paraguay (2025)
  static const List<Capital> paraguayanCapitals = [
    Capital(
      name: 'Asunción',
      department: 'Distrito Capital',
      population: 505043,
      coordinates: LatLng(-25.2637, -57.5759),
    ),
    Capital(
      name: 'Concepción',
      department: 'Concepción',
      population: 68630,
      coordinates: LatLng(-23.4079, -57.4338),
    ),
    Capital(
      name: 'San Pedro de Ycuamandiyú',
      department: 'San Pedro',
      population: 34359,
      coordinates: LatLng(-24.1009, -57.0862),
    ),
    Capital(
      name: 'Caacupé',
      department: 'Cordillera',
      population: 52037,
      coordinates: LatLng(-25.3855, -57.1415),
    ),
    Capital(
      name: 'Villarrica',
      department: 'Guairá',
      population: 84553,
      coordinates: LatLng(-25.7958, -56.4449),
    ),
    Capital(
      name: 'Coronel Oviedo',
      department: 'Caaguazú',
      population: 84961,
      coordinates: LatLng(-25.4414, -56.4428),
    ),
    Capital(
      name: 'Caazapá',
      department: 'Caazapá',
      population: 30000,
      coordinates: LatLng(-26.0601, -56.3756),
    ),
    Capital(
      name: 'Encarnación',
      department: 'Itapúa',
      population: 100987,
      coordinates: LatLng(-27.3323, -55.8679),
    ),
    Capital(
      name: 'San Juan Bautista',
      department: 'Misiones',
      population: 25000,
      coordinates: LatLng(-26.6806, -57.1477),
    ),
    Capital(
      name: 'Paraguarí',
      department: 'Paraguarí',
      population: 35000,
      coordinates: LatLng(-25.6200, -57.1517),
    ),
    Capital(
      name: 'Ciudad del Este',
      department: 'Alto Paraná',
      population: 320000,
      coordinates: LatLng(-25.5097, -54.6148),
    ),
    Capital(
      name: 'Areguá',
      department: 'Central',
      population: 95000,
      coordinates: LatLng(-25.2974, -57.3980),
    ),
    Capital(
      name: 'Pilar',
      department: 'Ñeembucú',
      population: 40000,
      coordinates: LatLng(-26.8634, -58.2919),
    ),
    Capital(
      name: 'Pedro Juan Caballero',
      department: 'Amambay',
      population: 120000,
      coordinates: LatLng(-22.5647, -55.7337),
    ),
    Capital(
      name: 'Salto del Guairá',
      department: 'Canindeyú',
      population: 25000,
      coordinates: LatLng(-24.0619, -54.2982),
    ),
    Capital(
      name: 'Villa Hayes',
      department: 'Presidente Hayes',
      population: 85000,
      coordinates: LatLng(-25.0975, -57.5190),
    ),
    Capital(
      name: 'Filadelfia',
      department: 'Boquerón',
      population: 25000,
      coordinates: LatLng(-22.3503, -60.0306),
    ),
    Capital(
      name: 'Fuerte Olimpo',
      department: 'Alto Paraguay',
      population: 6000,
      coordinates: LatLng(-21.0475, -57.8767),
    ),
  ];

  late double _minPopulation;
  late double _maxPopulation;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    _calculatePopulationRange();
    _populateDepartments();
    _applyFilters();
  }

  void _calculatePopulationRange() {
    if (paraguayanCapitals.isEmpty) {
      _minPopulation = 0;
      _maxPopulation = 1000;
    } else {
      // Usamos .fold para encontrar min y max de forma segura
      _minPopulation = paraguayanCapitals
          .fold<int>(
            paraguayanCapitals.first.population,
            (prev, capital) => min(prev, capital.population),
          )
          .toDouble();

      _maxPopulation = paraguayanCapitals
          .fold<int>(
            paraguayanCapitals.first.population,
            (prev, capital) => max(prev, capital.population),
          )
          .toDouble();
    }
    // Inicializa el rango actual con los valores calculados
    _currentPopulationRange = RangeValues(_minPopulation, _maxPopulation);

    // Puedes imprimir para depurar
    if (kDebugMode) {
      print('Población mínima calculada: $_minPopulation');
    }
    if (kDebugMode) {
      print('Población máxima calculada: $_maxPopulation');
    }
  }

  void _populateDepartments() {
    final uniqueDepartments = paraguayanCapitals
        .map((c) => c.department)
        .toSet()
        .toList();
    uniqueDepartments.sort();
    setState(() {
      _departments = ['Todos', ...uniqueDepartments];
    });
  }

  void _applyFilters() {
    setState(() {
      _isLoading = true;
      _markers.clear();

      final filteredCapitals = paraguayanCapitals.where((capital) {
        final inPopulationRange =
            capital.population >= _currentPopulationRange.start &&
            capital.population <= _currentPopulationRange.end;

        final byDepartment =
            _selectedDepartment == null ||
            _selectedDepartment == 'Todos' ||
            capital.department == _selectedDepartment;
        return inPopulationRange && byDepartment;
      }).toList();

      for (final capital in filteredCapitals) {
        _markers.add(_createMarker(capital));
      }
      _isLoading = false;
    });
  }

  Color _getMarkerColor(int population) {
    if (population >= 200000) {
      return Colors.green;
    } else if (population >= 100000) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  String _getPopulationCategory(int population) {
    if (population >= 200000) {
      return 'Más de 200,000 hab.';
    } else if (population >= 100000) {
      return '100,000 - 200,000 hab.';
    } else {
      return 'Menos de 100,000 hab.';
    }
  }

  Marker _createMarker(Capital capital) {
    final markerColor = _getMarkerColor(capital.population);

    return Marker(
      point: capital.coordinates,
      width: 40.0,
      height: 40.0,
      child: Tooltip(
        message:
            '${capital.name}\n${capital.department}\n${capital.population.toStringAsFixed(0)} hab.\n${capital.coordinates.latitude.toStringAsFixed(4)}, ${capital.coordinates.longitude.toStringAsFixed(4)}',
        preferBelow: false,
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),

          borderRadius: BorderRadius.circular(8),
        ),
        waitDuration: const Duration(milliseconds: 500),
        showDuration: const Duration(seconds: 3),
        child: GestureDetector(
          onTap: () => _showCapitalInfo(capital),
          child: Container(
            decoration: BoxDecoration(
              color: markerColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.8),

                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.location_city,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  void _showCapitalInfo(Capital capital) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.location_city,
                color: _getMarkerColor(capital.population),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  capital.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(Icons.map, 'Departamento', capital.department),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.people,
                'Población',
                '${capital.population.toStringAsFixed(0)} hab.',
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.category,
                'Categoría',
                _getPopulationCategory(capital.population),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.my_location,
                'Coordenadas',
                '${capital.coordinates.latitude.toStringAsFixed(4)}, ${capital.coordinates.longitude.toStringAsFixed(4)}',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _centerOnLocation(capital.coordinates);
              },
              child: const Text('Centrar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(value, style: TextStyle(color: Colors.grey[700])),
        ),
      ],
    );
  }

  void _centerOnLocation(LatLng location) {
    mapController.move(location, 10.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capitales de Paraguay'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAppInfo(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(-23.4425, -58.4438),
                    initialZoom: 6.0,
                    minZoom: 5.0,
                    maxZoom: 18.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.paraguay_capitals_map',
                      maxZoom: 18,
                    ),
                    MarkerLayer(markers: _markers),
                  ],
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),

                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Leyenda',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_city,
                                color: Colors.white,
                                size: 10,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '+200k hab.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_city,
                                color: Colors.white,
                                size: 10,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '100k-200k hab.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_city,
                                color: Colors.white,
                                size: 10,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '-100k hab.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total: ${paraguayanCapitals.length}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),

                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Filtrar por Población',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 250,
                          child: RangeSlider(
                            values: _currentPopulationRange,
                            min: _minPopulation,
                            max: _maxPopulation,
                            // Dividimos por un número que asegure que el menor incremento sea 1
                            // o una cifra significativa. Por ejemplo, si el rango es grande, 1 puede ser muy granular.
                            // Para poblaciones, 1000 podría ser un buen incremento para divisiones.
                            divisions:
                                ((_maxPopulation - _minPopulation) / 1000)
                                    .round()
                                    .clamp(1, 1000)
                                    .toInt(),
                            labels: RangeLabels(
                              _currentPopulationRange.start.round().toString(),
                              _currentPopulationRange.end.round().toString(),
                            ),
                            onChanged: (RangeValues newRange) {
                              setState(() {
                                _currentPopulationRange = newRange;
                              });
                              _applyFilters();
                            },
                          ),
                        ),
                        Text(
                          'Rango: ${_currentPopulationRange.start.round()} - ${_currentPopulationRange.end.round()} hab.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 150,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),

                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Filtrar por Departamento',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButton<String>(
                          value: _selectedDepartment,
                          hint: const Text('Seleccione un departamento'),
                          items: _departments.map((String department) {
                            return DropdownMenuItem<String>(
                              value: department == 'Todos' ? null : department,
                              child: Text(department),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedDepartment = newValue;
                            });
                            _applyFilters();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          mapController.move(const LatLng(-23.4425, -58.4438), 6.0);
        },
        tooltip: 'Centrar en Paraguay',
        child: const Icon(Icons.home),
      ),
    );
  }

  void _showAppInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Acerca de la App'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mapa interactivo de las capitales de los 18 departamentos de Paraguay.',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              Text(
                'Características:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Mapas de OpenStreetMap'),
              Text('• Información detallada de cada capital'),
              Text('• Colores por población:'),
              Text('   - Verde: +200,000 hab.'),
              Text('   - Naranja: 100,000-200,000 hab.'),
              Text('   - Rojo: -100,000 hab.'),
              Text('• Navegación interactiva'),
              Text('• Filtro por rango de población'),
              Text('• Filtro por departamento'),
              Text('• Optimizado para rendimiento'),
              SizedBox(height: 16),
              Text(
                'Toca cualquier marcador para ver información detallada.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }
}
