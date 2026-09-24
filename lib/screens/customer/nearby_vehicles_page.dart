import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'auto_booking_page.dart';
import 'bike_booking_page.dart';
import 'car_booking_page.dart';

class NearbyVehiclesPage extends StatefulWidget {
  final String initialType;

  const NearbyVehiclesPage({super.key, this.initialType = 'All'});

  @override
  State<NearbyVehiclesPage> createState() => _NearbyVehiclesPageState();
}

class _NearbyVehiclesPageState extends State<NearbyVehiclesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const double _nearbyRadiusKm = 10.0;

  Position? _customerPosition;

  bool _loadingLocation = true;
  String? _locationError;

  late String _selectedType;

  final List<String> _vehicleTypes = const [
    'All',
    'Car',
    'Bike',
    'Auto',
    'Tempo',
  ];

  @override
  void initState() {
    super.initState();

    _selectedType = _vehicleTypes.contains(widget.initialType)
        ? widget.initialType
        : 'All';

    _loadCustomerLocation();
  }

  Future<void> _loadCustomerLocation() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _loadingLocation = true;
      _locationError = null;
    });

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) {
          return;
        }

        setState(() {
          _loadingLocation = false;
          _locationError = 'Location service is turned off. Please turn it on.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) {
          return;
        }

        setState(() {
          _loadingLocation = false;
          _locationError =
              'Location permission is required to find nearby vehicles.';
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) {
          return;
        }

        setState(() {
          _loadingLocation = false;
          _locationError = 'Location permission is permanently denied. Please enable it from device settings.';
        });
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _customerPosition = position;
        _loadingLocation = false;
        _locationError = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingLocation = false;
        _locationError = 'Unable to get your current location.';
      });
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _vehiclesStream() {
    return _firestore
        .collection('vehicles')
        .where('status', isEqualTo: 'active')
        .snapshots();
  }

  double? _distanceInKm(Map<String, dynamic> data) {
    final Position? customerPosition = _customerPosition;

    if (customerPosition == null) {
      return null;
    }

    final dynamic latitudeValue = data['latitude'];

    final dynamic longitudeValue = data['longitude'];

    if (latitudeValue is! num || longitudeValue is! num) {
      return null;
    }

    return _calculateDistance(
      customerPosition.latitude,
      customerPosition.longitude,
      latitudeValue.toDouble(),
      longitudeValue.toDouble(),
    );
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371.0;

    final double dLat = _degreesToRadians(lat2 - lat1);

    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  void _openVehicleDetails(
    BuildContext context,
    Map<String, dynamic> data,
    String documentId,
  ) {
    final String vehicleType = data['vehicleType']?.toString() ?? '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _VehicleDetailsPage(
          data: data,
          documentId: documentId,
          distanceInKm: _distanceInKm(data),
          onBook: () {
            Navigator.pop(context);

            if (vehicleType == 'Car') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CarBookingPage(
                    preselectedVehicleId: documentId,
                    preselectedVehicle: data,
                  ),
                ),
              );
            } else if (vehicleType == 'Bike') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BikeBookingPage(
                    preselectedVehicleId: documentId,
                    preselectedVehicle: data,
                  ),
                ),
              );
            } else if (vehicleType == 'Auto') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AutoBookingPage(
                    preselectedVehicleId: documentId,
                    preselectedVehicle: data,
                  ),
                ),
              );
            } else if (vehicleType == 'Tempo') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Tempo booking will be connected in the next module.',
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Vehicles'),
        actions: [
          IconButton(
            tooltip: 'Refresh location',
            onPressed: _loadCustomerLocation,
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildLocationStatus(),
          _buildVehicleTypeFilter(),
          Expanded(child: _buildVehicleList()),
        ],
      ),
    );
  }

  Widget _buildVehicleList() {
    if (_loadingLocation) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_customerPosition == null) {
      return _buildLocationRequiredState();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _vehiclesStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Unable to load vehicles.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> documents =
            snapshot.data?.docs ?? [];

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> nearbyVehicles =
            documents.where((document) {
              final Map<String, dynamic> data = document.data();

              final String type = data['vehicleType']?.toString() ?? '';

              final String driverId = data['driverId']?.toString() ?? '';

              final bool isAvailable = data['isAvailable'] == true;

              final double? distance = _distanceInKm(data);

              final bool typeMatches =
                  _selectedType == 'All' || type == _selectedType;

              return typeMatches &&
                  driverId.isNotEmpty &&
                  isAvailable &&
                  distance != null &&
                  distance <= _nearbyRadiusKm;
            }).toList();

        nearbyVehicles.sort((a, b) {
          final double distanceA = _distanceInKm(a.data()) ?? double.infinity;

          final double distanceB = _distanceInKm(b.data()) ?? double.infinity;

          return distanceA.compareTo(distanceB);
        });

        if (nearbyVehicles.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: _loadCustomerLocation,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: nearbyVehicles.length,
            itemBuilder: (context, index) {
              final QueryDocumentSnapshot<Map<String, dynamic>> document =
                  nearbyVehicles[index];

              final Map<String, dynamic> data = document.data();

              return _NearbyVehicleCard(
                data: data,
                distanceInKm: _distanceInKm(data),
                onTap: () {
                  _openVehicleDetails(context, data, document.id);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLocationStatus() {
    if (_loadingLocation) {
      return const LinearProgressIndicator();
    }

    if (_locationError != null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_off),
            const SizedBox(width: 10),
            Expanded(child: Text(_locationError!)),
            TextButton(
              onPressed: _loadCustomerLocation,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Showing available vehicles within ${_nearbyRadiusKm.toStringAsFixed(0)} km of your location.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRequiredState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, size: 70, color: Colors.grey.shade500),
            const SizedBox(height: 16),
            const Text(
              'Location is required',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Turn on location permission to find nearby vehicles.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _loadCustomerLocation,
              icon: const Icon(Icons.my_location),
              label: const Text('Get My Location'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleTypeFilter() {
    return SizedBox(
      height: 62,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: _vehicleTypes.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final String type = _vehicleTypes[index];

          final bool selected = type == _selectedType;

          return ChoiceChip(
            selected: selected,
            label: Text(type),
            avatar: Icon(_vehicleIcon(type), size: 18),
            onSelected: (_) {
              setState(() {
                _selectedType = type;
              });
            },
          );
        },
      ),
    );
  }

  IconData _vehicleIcon(String type) {
    switch (type) {
      case 'Car':
        return Icons.directions_car;
      case 'Bike':
        return Icons.two_wheeler;
      case 'Auto':
        return Icons.local_taxi;
      case 'Tempo':
        return Icons.local_shipping;
      default:
        return Icons.apps;
    }
  }

  Widget _buildEmptyState() {
    final String typeText = _selectedType == 'All'
        ? 'vehicles'
        : _selectedType.toLowerCase();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.near_me_disabled, size: 70, color: Colors.grey.shade500),
            const SizedBox(height: 16),
            Text(
              'No nearby $typeText available.',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Only available vehicles within ${_nearbyRadiusKm.toStringAsFixed(0)} km are shown.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadCustomerLocation,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyVehicleCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final double? distanceInKm;
  final VoidCallback onTap;

  const _NearbyVehicleCard({
    required this.data,
    required this.distanceInKm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String type = data['vehicleType']?.toString() ?? '';

    final String brand = data['brand']?.toString() ?? '';

    final String model = data['model']?.toString() ?? '';

    final String number = data['vehicleNumber']?.toString() ?? '';

    final String driverName = data['driverName']?.toString() ?? '';

    final String rating = data['rating']?.toString() ?? '';

    final String title = [
      brand,
      model,
    ].where((value) => value.isNotEmpty).join(' ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                child: Icon(_vehicleIcon(type), size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? type : title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      number.isEmpty ? type : '$type • $number',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    if (driverName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Driver: $driverName'),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (distanceInKm != null)
                          _SmallChip(
                            icon: Icons.near_me,
                            text: '${distanceInKm!.toStringAsFixed(1)} km',
                          ),
                        if (rating.isNotEmpty && rating != '0')
                          _SmallChip(icon: Icons.star, text: rating),
                        const _SmallChip(icon: Icons.circle, text: 'Available'),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  IconData _vehicleIcon(String type) {
    switch (type) {
      case 'Car':
        return Icons.directions_car;
      case 'Bike':
        return Icons.two_wheeler;
      case 'Auto':
        return Icons.local_taxi;
      case 'Tempo':
        return Icons.local_shipping;
      default:
        return Icons.directions_car;
    }
  }
}

class _SmallChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SmallChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

class _VehicleDetailsPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final String documentId;
  final double? distanceInKm;
  final VoidCallback onBook;

  const _VehicleDetailsPage({
    required this.data,
    required this.documentId,
    required this.distanceInKm,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    final String type = data['vehicleType']?.toString() ?? '';

    final String brand = data['brand']?.toString() ?? '';

    final String model = data['model']?.toString() ?? '';

    final String number = data['vehicleNumber']?.toString() ?? '';

    final String year = data['year']?.toString() ?? '';

    final String fuel = data['fuelType']?.toString() ?? '';

    final String seats = data['seatingCapacity']?.toString() ?? '';

    final String driver = data['driverName']?.toString() ?? '';

    final String rating = data['rating']?.toString() ?? '';

    final String title = [
      brand,
      model,
    ].where((value) => value.isNotEmpty).join(' ');

    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 55,
                child: Icon(_vehicleIcon(type), size: 55),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                title.isEmpty ? type : title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                number.isEmpty ? type : number,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _DetailRow(
              icon: Icons.directions_car,
              label: 'Vehicle Type',
              value: type.isEmpty ? 'Not available' : type,
            ),
            _DetailRow(
              icon: Icons.confirmation_number,
              label: 'Vehicle Number',
              value: number.isEmpty ? 'Not available' : number,
            ),
            _DetailRow(
              icon: Icons.business,
              label: 'Brand',
              value: brand.isEmpty ? 'Not available' : brand,
            ),
            _DetailRow(
              icon: Icons.model_training,
              label: 'Model',
              value: model.isEmpty ? 'Not available' : model,
            ),
            _DetailRow(
              icon: Icons.calendar_today,
              label: 'Year',
              value: year.isEmpty ? 'Not available' : year,
            ),
            _DetailRow(
              icon: Icons.local_gas_station,
              label: 'Fuel',
              value: fuel.isEmpty ? 'Not available' : fuel,
            ),
            _DetailRow(
              icon: Icons.event_seat,
              label: 'Seats',
              value: seats.isEmpty ? 'Not available' : seats,
            ),
            _DetailRow(
              icon: Icons.person,
              label: 'Driver',
              value: driver.isEmpty ? 'Available' : driver,
            ),
            _DetailRow(
              icon: Icons.star,
              label: 'Rating',
              value: rating.isEmpty || rating == '0' ? 'No rating yet' : rating,
            ),
            if (distanceInKm != null)
              _DetailRow(
                icon: Icons.near_me,
                label: 'Distance',
                value: '${distanceInKm!.toStringAsFixed(1)} km away',
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: onBook,
                icon: const Icon(Icons.event_available),
                label: const Text('Book This Vehicle'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  IconData _vehicleIcon(String type) {
    switch (type) {
      case 'Car':
        return Icons.directions_car;
      case 'Bike':
        return Icons.two_wheeler;
      case 'Auto':
        return Icons.local_taxi;
      case 'Tempo':
        return Icons.local_shipping;
      default:
        return Icons.directions_car;
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
