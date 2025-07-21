import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:isolate';
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Capital &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          department == other.department;

  @override
  int get hashCode => name.hashCode ^ department.hashCode;
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
  final _markerCache = <Capital, Marker>{};
  final bool _debugMode = kDebugMode;

  late RangeValues _currentPopulationRange;
  // CAMBIO CLAVE 1: Ahora es una lista para multiselección
  List<String> _selectedDepartments = [];
  List<String> _allDepartments = []; // Almacena todos los departamentos únicos

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
      population: 7500,
      coordinates: LatLng(-21.0475, -57.8767),
    ),
  ];

  late double _minPopulation;
  late double _maxPopulation;

  static const _initialMapCenter = LatLng(-23.4425, -58.4438);
  static const _initialZoom = 7.0;
  static const _detailZoom = 10.0;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculatePopulationRange();
      _populateDepartments();
      _applyFilters();
    });
  }

  void _calculatePopulationRange() {
    if (paraguayanCapitals.isEmpty) {
      _minPopulation = 0;
      _maxPopulation = 1000;
    } else {
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
    _currentPopulationRange = RangeValues(_minPopulation, _maxPopulation);
  }

  void _populateDepartments() {
    final uniqueDepartments = paraguayanCapitals
        .map((c) => c.department)
        .toSet()
        .toList();
    uniqueDepartments.sort();
    setState(() {
      _allDepartments = uniqueDepartments;
      // MODIFICADO: Inicializar con todos los departamentos seleccionados
      _selectedDepartments = List.from(uniqueDepartments);
    });
  }

  Future<void> _applyFilters() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      List<Capital> filteredCapitals;
      List<Marker> markers;

      if (_debugMode) {
        filteredCapitals = _filterCapitalsSync(
          paraguayanCapitals,
          _currentPopulationRange,
          _selectedDepartments, // Pasa la lista de departamentos seleccionados
        );
        markers = filteredCapitals.map(_createMarker).toList();
      } else {
        filteredCapitals = await compute(
          _filterCapitals,
          _FilterData(
            allCapitals: paraguayanCapitals,
            range: _currentPopulationRange,
            departments: _selectedDepartments, // Pasa la lista
          ),
        );
        markers = await _computeMarkers(filteredCapitals);
      }

      if (mounted) {
        setState(() {
          _markers.clear();
          _markers.addAll(markers);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      if (_debugMode) {
        debugPrint('Error applying filters: $e');
      }
    }
  }

  // CAMBIO CLAVE 3: _filterCapitalsSync ahora toma una lista de departamentos
  List<Capital> _filterCapitalsSync(
    List<Capital> allCapitals,
    RangeValues range,
    List<String> departments,
  ) {
    return allCapitals.where((capital) {
      final inPopulationRange =
          capital.population >= range.start && capital.population <= range.end;
      // MODIFICADO: Si la lista está vacía, no mostrar ninguno
      final byDepartment =
          departments.isNotEmpty && departments.contains(capital.department);
      return inPopulationRange && byDepartment;
    }).toList();
  }

  Future<List<Marker>> _computeMarkers(List<Capital> filteredCapitals) async {
    if (_debugMode) {
      return filteredCapitals.map(_createMarker).toList();
    }

    final receivePort = ReceivePort();
    await Isolate.spawn(
      _createMarkersIsolate,
      _IsolateData(
        filteredCapitals: filteredCapitals,
        sendPort: receivePort.sendPort,
      ),
    );
    return await receivePort.first as List<Marker>;
  }

  static void _createMarkersIsolate(_IsolateData data) {
    final markers = data.filteredCapitals.map((capital) {
      final markerColor = _getMarkerColorStatic(capital.population);
      return Marker(
        point: capital.coordinates,
        width: 40.0,
        height: 40.0,
        child: Tooltip(
          message:
              //'${capital.name}\n${capital.department}\n${capital.population.toStringAsFixed(0)} hab.\n'
              '${capital.name}\n${capital.department}\n${formatNumberWithThousandsSeparator(capital.population.toStringAsFixed(0))} hab.\n'
              '${capital.coordinates.latitude.toStringAsFixed(4)}, '
              '${capital.coordinates.longitude.toStringAsFixed(4)}',
          preferBelow: false,
          textStyle: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
          ),
          waitDuration: const Duration(milliseconds: 500),
          showDuration: const Duration(seconds: 3),
          child: Container(
            decoration: BoxDecoration(
              color: markerColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
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
      );
    }).toList();
    Isolate.exit(data.sendPort, markers);
  }

  static Color _getMarkerColorStatic(int population) {
    if (population >= 200000) return Colors.green;
    if (population >= 100000) return Colors.orange;
    return Colors.red;
  }

  Color _getMarkerColor(int population) {
    return _getMarkerColorStatic(population);
  }

  String _getPopulationCategory(int population) {
    if (population >= 200000) return 'Más de 200.000 hab.';
    if (population >= 100000) return '100.000 - 200.000 hab.';
    return 'Menos de 100.000 hab.';
  }

  Marker _createMarker(Capital capital) {
    if (_markerCache.containsKey(capital)) {
      return _markerCache[capital]!;
    }

    final marker = Marker(
      point: capital.coordinates,
      width: 40.0,
      height: 40.0,
      child: Tooltip(
        message:
            //'${capital.name}\n${capital.department}\n${capital.population.toStringAsFixed(0)} hab.\n'
            '${capital.name}\n${capital.department}\n${formatNumberWithThousandsSeparator(capital.population.toStringAsFixed(0))} hab.\n'
            '${capital.coordinates.latitude.toStringAsFixed(4)}, '
            '${capital.coordinates.longitude.toStringAsFixed(4)}',
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
              color: _getMarkerColor(capital.population),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
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

    _markerCache[capital] = marker;
    return marker;
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
                //'${capital.population.toStringAsFixed(0)} hab.',
                '${formatNumberWithThousandsSeparator(capital.population.toStringAsFixed(0))} hab.',
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
                '${capital.coordinates.latitude.toStringAsFixed(4)}, '
                    '${capital.coordinates.longitude.toStringAsFixed(4)}',
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
    mapController.move(location, _detailZoom);
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
                _buildMap(),
                _buildLegend(),
                _buildPopulationFilter(),
                _buildDepartmentFilter(), // Este es el widget modificado
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          mapController.move(_initialMapCenter, _initialZoom);
        },
        child: const Icon(Icons.home),
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: _initialMapCenter,
        initialZoom: _initialZoom,
        minZoom: 7.0,
        maxZoom: 18.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        // 1. Capa Base: Imagen Satelital (fija como fondo)
        TileLayer(
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'com.example.paraguay_capitals_map',
          maxZoom: 18,
          // **IMPORTANTE**: No te olvides de la atribución si usas Esri.
          // Puedes añadirla con un RichAttributionWidget en nonRotatedChildren
          // o directamente en el TileLayer si la librería lo soporta (depende de la versión).
          // Para Flutter Map 8.x.x es mejor nonRotatedChildren.
        ),

        // 2. Capa de Superposición: OpenStreetMap (semitransparente para límites y calles)
        Opacity(
          opacity:
              0.5, // Ajusta este valor para la transparencia de las calles/límites
          child: TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.paraguay_capitals_map',
            maxZoom: 18,
          ),
        ),

        // 3. Marcadores
        MarkerLayer(markers: _markers),
      ],
    );
  }

  Widget _buildLegend() {
    return Positioned(
      top: 16,
      right: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Leyenda',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              _buildLegendItem(Colors.green, '+200k hab.'),
              _buildLegendItem(Colors.orange, '100k-200k hab.'),
              _buildLegendItem(Colors.red, '-100k hab.'),
              const SizedBox(height: 8),
              Text(
                'Total: ${paraguayanCapitals.length}',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const Icon(
              Icons.location_city,
              color: Colors.white,
              size: 10,
            ),
          ),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPopulationFilter() {
    return Positioned(
      top: 16,
      left: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          width: 250,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Filtrar por Población',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              RangeSlider(
                values: _currentPopulationRange,
                min: _minPopulation,
                max: _maxPopulation,
                divisions: ((_maxPopulation - _minPopulation) / 5000)
                    .round()
                    .clamp(1, 20),
                labels: RangeLabels(
                  _currentPopulationRange.start.round().toString(),
                  _currentPopulationRange.end.round().toString(),
                ),
                onChanged: (RangeValues newRange) {
                  setState(() => _currentPopulationRange = newRange);
                },
                onChangeEnd: (_) => _applyFilters(),
              ),
              Text(
                'Rango: ${_currentPopulationRange.start.round()} - '
                '${_currentPopulationRange.end.round()} hab.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // CAMBIO CLAVE 2: Nuevo widget de filtro por departamento multiselect
  Widget _buildDepartmentFilter() {
    return Positioned(
      top: 150,
      left: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Filtrar por Departamento',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  final List<String>? result = await showDialog<List<String>>(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      List<String> tempSelectedDepartments = List.from(
                        _selectedDepartments,
                      );
                      return StatefulBuilder(
                        builder: (context, setDialogState) {
                          // NUEVO: Calcular si todos están seleccionados
                          bool allSelected =
                              tempSelectedDepartments.length ==
                              _allDepartments.length;

                          return AlertDialog(
                            title: const Text('Seleccionar Departamentos'),
                            content: SingleChildScrollView(
                              child: Column(
                                children: [
                                  // NUEVO: Opción "Todos"
                                  CheckboxListTile(
                                    title: const Text(
                                      'Todos',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    value: allSelected,
                                    onChanged: (bool? isChecked) {
                                      setDialogState(() {
                                        if (isChecked == true) {
                                          // Seleccionar todos
                                          tempSelectedDepartments = List.from(
                                            _allDepartments,
                                          );
                                        } else {
                                          // Deseleccionar todos
                                          tempSelectedDepartments.clear();
                                        }
                                      });
                                    },
                                  ),
                                  const Divider(), // Separador visual
                                  // Lista de departamentos individuales
                                  ..._allDepartments.map((department) {
                                    return CheckboxListTile(
                                      title: Text(department),
                                      value: tempSelectedDepartments.contains(
                                        department,
                                      ),
                                      onChanged: (bool? isChecked) {
                                        setDialogState(() {
                                          if (isChecked == true) {
                                            tempSelectedDepartments.add(
                                              department,
                                            );
                                          } else {
                                            tempSelectedDepartments.remove(
                                              department,
                                            );
                                          }
                                        });
                                      },
                                    );
                                  }),
                                ],
                              ),
                            ),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('Cancelar'),
                                onPressed: () {
                                  Navigator.of(dialogContext).pop(null);
                                },
                              ),
                              ElevatedButton(
                                child: const Text('Aplicar'),
                                onPressed: () {
                                  Navigator.of(
                                    dialogContext,
                                  ).pop(tempSelectedDepartments);
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );

                  if (result != null) {
                    setState(() {
                      _selectedDepartments = result;
                    });
                    _applyFilters();
                  }
                },
                child: Text(
                  _selectedDepartments.isEmpty
                      ? 'Seleccionar Departamentos'
                      : _selectedDepartments.length == _allDepartments.length
                      ? 'Todos los Departamentos'
                      : 'Departamentos Seleccionados (${_selectedDepartments.length})',
                ),
              ),
              // Mostrar los departamentos seleccionados como texto
              if (_selectedDepartments.isNotEmpty &&
                  _selectedDepartments.length < _allDepartments.length)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _selectedDepartments.join(', '),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
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
          content: const SingleChildScrollView(
            child: Column(
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
                Text(
                  '• Filtro por departamento (multiselección)',
                ), // Actualizado
                Text('• Optimizado para rendimiento'),
                SizedBox(height: 16),
                Text(
                  'Toca cualquier marcador para ver información detallada.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
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

class _IsolateData {
  final List<Capital> filteredCapitals;
  final SendPort sendPort;

  _IsolateData({required this.filteredCapitals, required this.sendPort});
}

class _FilterData {
  final List<Capital> allCapitals;
  final RangeValues range;
  // CAMBIO CLAVE 3: Ahora es una lista de departamentos
  final List<String> departments;

  _FilterData({
    required this.allCapitals,
    required this.range,
    required this.departments,
  });
}

// CAMBIO CLAVE 3: _filterCapitals ahora toma una lista de departamentos
List<Capital> _filterCapitals(_FilterData data) {
  return data.allCapitals.where((capital) {
    final inPopulationRange =
        capital.population >= data.range.start &&
        capital.population <= data.range.end;
    // MODIFICADO: Si la lista está vacía, no mostrar ninguno
    final byDepartment =
        data.departments.isNotEmpty &&
        data.departments.contains(capital.department);
    return inPopulationRange && byDepartment;
  }).toList();
}

String formatNumberWithThousandsSeparator(String numberString) {
  // Eliminar cualquier caracter no numérico (excepto el punto decimal, si lo hubiera)
  String cleanedString = numberString.replaceAll(RegExp(r'[^\d.]'), '');

  // Separar la parte entera de la parte decimal
  List<String> parts = cleanedString.split('.');
  String integerPart = parts[0];
  String decimalPart = parts.length > 1 ? '.${parts[1]}' : '';

  // Usar una expresión regular para insertar puntos cada tres dígitos desde la derecha en la parte entera
  RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  String formattedIntegerPart = integerPart.replaceAllMapped(
    reg,
    (Match match) => '${match[1]}.',
  );

  return formattedIntegerPart + decimalPart;
}
