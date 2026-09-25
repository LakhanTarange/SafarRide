import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    _DriverHomePage(),
    _DriverTripsPage(),
    _DriverProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No new notifications.')),
              );
            },
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _DriverHomePage extends StatefulWidget {
  const _DriverHomePage();

  @override
  State<_DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<_DriverHomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Timer? _locationTimer;

  bool _isLinking = true;
  bool _isLinked = false;
  bool _isUpdatingAvailability = false;
  bool _isUpdatingLocation = false;

  String? _driverDocumentId;
  Map<String, dynamic>? _driverData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _linkDriverAccount();
  }

  @override
  void dispose() {
    _stopLocationUpdates();
    super.dispose();
  }

  Future<void> _linkDriverAccount() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _isLinking = false;
          _errorMessage = 'Please login as a driver.';
        });
      }
      return;
    }

    final String email = user.email?.trim().toLowerCase() ?? '';

    if (email.isEmpty) {
      if (mounted) {
        setState(() {
          _isLinking = false;
          _errorMessage = 'Driver account email is not available.';
        });
      }
      return;
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('drivers')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        _stopLocationUpdates();

        if (mounted) {
          setState(() {
            _isLinking = false;
            _isLinked = false;
            _errorMessage =
                'No driver profile found for this email.\n\n'
                'Please contact your fleet owner.';
          });
        }
        return;
      }

      final DocumentSnapshot<Map<String, dynamic>> driverDocument =
          snapshot.docs.first;

      final Map<String, dynamic> data =
          driverDocument.data() ?? <String, dynamic>{};

      final String existingUid = data['uid']?.toString().trim() ?? '';

      if (existingUid.isNotEmpty && existingUid != user.uid) {
        _stopLocationUpdates();

        if (mounted) {
          setState(() {
            _isLinking = false;
            _isLinked = false;
            _errorMessage =
                'This driver profile is already linked to another account.';
          });
        }
        return;
      }

      if (existingUid.isEmpty) {
        await driverDocument.reference.update({
          'uid': user.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final DocumentSnapshot<Map<String, dynamic>> updatedDocument =
          await driverDocument.reference.get();

      final Map<String, dynamic> updatedData = updatedDocument.data() ?? data;

      if (mounted) {
        setState(() {
          _isLinking = false;
          _isLinked = true;
          _driverDocumentId = driverDocument.id;
          _driverData = updatedData;
          _errorMessage = null;
        });
      }

      final bool isAvailable = updatedData['isAvailable'] == true;

      if (isAvailable) {
        await _startLocationUpdates();
      } else {
        _stopLocationUpdates();
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() {
          _isLinking = false;
          _errorMessage =
              'Unable to link driver account.\n\n${e.message ?? e.code}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLinking = false;
          _errorMessage = 'Something went wrong.\n\n$e';
        });
      }
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (mounted) {
        _showMessage(
          context,
          'Location service is turned off. Please enable GPS.',
        );
      }
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (mounted) {
        _showMessage(
          context,
          'Location permission is required while you are available.',
        );
      }
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        _showMessage(
          context,
          'Location permission is permanently denied. Please enable it from device settings.',
        );
      }
      return false;
    }

    return true;
  }

  Future<void> _updateDriverLocation() async {
    if (!_isLinked || _driverDocumentId == null) {
      return;
    }

    if (_isUpdatingLocation) {
      return;
    }

    final bool isAvailable = _driverData?['isAvailable'] == true;

    if (!isAvailable) {
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    if (!await _ensureLocationPermission()) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isUpdatingLocation = true;
    });

    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final Timestamp locationUpdatedAt = Timestamp.now();

      final DocumentReference<Map<String, dynamic>> driverReference = _firestore
          .collection('drivers')
          .doc(_driverDocumentId);

      final String vehicleId =
          _driverData?['vehicleId']?.toString().trim() ?? '';

      final WriteBatch batch = _firestore.batch();

      batch.update(driverReference, {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'locationUpdatedAt': locationUpdatedAt,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (vehicleId.isNotEmpty) {
        final DocumentReference<Map<String, dynamic>> vehicleReference =
            _firestore.collection('vehicles').doc(vehicleId);

        batch.update(vehicleReference, {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'locationUpdatedAt': locationUpdatedAt,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (!mounted) {
        return;
      }

      setState(() {
        _driverData = {
          ...?_driverData,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'locationUpdatedAt': locationUpdatedAt,
        };
        _isUpdatingLocation = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isUpdatingLocation = false;
      });

      _showMessage(context, e.message ?? 'Unable to update driver location.');
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isUpdatingLocation = false;
      });

      _showMessage(context, 'Unable to get or update your current location.');
    }
  }

  Future<void> _startLocationUpdates() async {
    _stopLocationUpdates();

    final bool permissionAvailable = await _ensureLocationPermission();

    if (!permissionAvailable) {
      return;
    }

    if (!mounted) {
      return;
    }

    await _updateDriverLocation();

    if (!mounted) {
      return;
    }

    _locationTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _updateDriverLocation();
    });
  }

  void _stopLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  Future<void> _toggleAvailability() async {
    if (!_isLinked || _driverDocumentId == null) {
      return;
    }

    if (_isUpdatingAvailability) {
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(context, 'Please login again.');
      return;
    }

    final bool currentAvailability = _driverData?['isAvailable'] == true;

    final bool newAvailability = !currentAvailability;

    if (newAvailability) {
      final String banStatus = _driverData?['banStatus']?.toString() ?? '';
      final String accountStatus = _driverData?['accountStatus']?.toString() ?? '';

      if (banStatus == 'blacklisted' || accountStatus == 'banned') {
        _showMessage(
          context,
          'Your account has been permanently blocked. Contact support.',
        );
        return;
      }

      if (banStatus == 'suspended') {
        final dynamic suspendedUntilRaw = _driverData?['suspendedUntil'];

        if (suspendedUntilRaw is Timestamp &&
            suspendedUntilRaw.toDate().isAfter(DateTime.now())) {
          _showMessage(
            context,
            'Your account is suspended until '
            '${suspendedUntilRaw.toDate().toString().split('.').first}.',
          );
          return;
        }
      }
    }

    final String vehicleId = _driverData?['vehicleId']?.toString().trim() ?? '';

    if (newAvailability) {
      final bool locationReady = await _ensureLocationPermission();

      if (!locationReady) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isUpdatingAvailability = true;
    });

    try {
      final WriteBatch batch = _firestore.batch();

      final DocumentReference<Map<String, dynamic>> driverReference = _firestore
          .collection('drivers')
          .doc(_driverDocumentId);

      batch.update(driverReference, {
        'isAvailable': newAvailability,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (vehicleId.isNotEmpty) {
        final DocumentReference<Map<String, dynamic>> vehicleReference =
            _firestore.collection('vehicles').doc(vehicleId);

        batch.update(vehicleReference, {
          'isAvailable': newAvailability,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (!mounted) {
        return;
      }

      setState(() {
        _driverData = {...?_driverData, 'isAvailable': newAvailability};
        _isUpdatingAvailability = false;
      });

      if (newAvailability) {
        await _startLocationUpdates();

        if (!mounted) {
          return;
        }

        if (vehicleId.isEmpty) {
          _showMessage(
            context,
            'You are now available. No vehicle is assigned.',
          );
        } else {
          _showMessage(
            context,
            'You are available. Your location is now being updated.',
          );
        }
      } else {
        _stopLocationUpdates();

        _showMessage(
          context,
          vehicleId.isEmpty
              ? 'You are now unavailable.'
              : 'You are unavailable. Vehicle is now hidden from bookings.',
        );
      }
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isUpdatingAvailability = false;
      });

      _showMessage(context, e.message ?? 'Unable to update availability.');
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isUpdatingAvailability = false;
      });

      _showMessage(
        context,
        'Something went wrong while updating availability.',
      );
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLinking) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isLinked) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_off_outlined, size: 72),
              const SizedBox(height: 16),
              const Text(
                'Driver Profile Not Linked',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage ?? 'Your driver profile could not be linked.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _linkDriverAccount,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final String driverName = _driverData?['name']?.toString() ?? 'Driver';

    final String vehicleNumber =
        _driverData?['vehicleNumber']?.toString() ?? 'Not Assigned';

    final String vehicleType =
        _driverData?['vehicleType']?.toString() ?? 'Vehicle';

    final String kycStatus = _driverData?['kycStatus']?.toString() ?? 'pending';

    final bool isAvailable = _driverData?['isAvailable'] == true;

    final bool hasLocation =
        _driverData?['latitude'] is num && _driverData?['longitude'] is num;

    return RefreshIndicator(
      onRefresh: _linkDriverAccount,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    child: Text(
                      driverName.isNotEmpty ? driverName[0].toUpperCase() : 'D',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, $driverName',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          vehicleNumber,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DriverInfoCard(
                  icon: Icons.directions_car_outlined,
                  title: vehicleType,
                  subtitle: vehicleNumber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DriverInfoCard(
                  icon: Icons.verified_user_outlined,
                  title: 'KYC',
                  subtitle: kycStatus.toUpperCase(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    child: _isUpdatingAvailability
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(isAvailable ? Icons.wifi : Icons.wifi_off),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Driver Status',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isAvailable
                              ? 'You are available for trips.'
                              : 'You are currently offline.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isAvailable,
                    onChanged: _isUpdatingAvailability
                        ? null
                        : (_) {
                            _toggleAvailability();
                          },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                child: _isUpdatingLocation
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        hasLocation ? Icons.location_on : Icons.location_off,
                      ),
              ),
              title: const Text(
                'Driver Location',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                isAvailable
                    ? hasLocation
                          ? 'Your current location is being shared for nearby bookings.'
                          : 'Waiting for your current location.'
                    : 'Location sharing is paused while you are offline.',
              ),
              trailing: hasLocation
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore
                .collection('bookings')
                .where(
                  'driverId',
                  isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                )
                .where('status', whereIn: ['driver_assigned', 'started'])
                .snapshots(),
            builder: (context, snapshot) {
              final int tripCount = snapshot.data?.docs.length ?? 0;

              return Row(
                children: [
                  Expanded(
                    child: _DriverInfoCard(
                      icon: Icons.route_outlined,
                      title: tripCount.toString(),
                      subtitle: 'Active Trips',
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: _DriverInfoCard(
                      icon: Icons.star_outline,
                      title: '0.0',
                      subtitle: 'Rating',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.link)),
              title: const Text(
                'Account Linked',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Your Firebase driver account is linked successfully.',
              ),
              trailing: const Icon(Icons.check_circle),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverTripsPage extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> _bookings = FirebaseFirestore
      .instance
      .collection('bookings');

  String _serviceName(String serviceType) {
    switch (serviceType) {
      case 'car':
        return 'Car Ride';
      case 'bike':
        return 'Bike Ride';
      case 'auto':
        return 'Auto Ride';
      case 'travels':
        return 'Travels';
      case 'cargo':
        return 'Cargo / Tempo';
      case 'rental':
        return 'Rental';
      case 'carpool':
        return 'Carpool';
      default:
        return 'Trip';
    }
  }

  IconData _serviceIcon(String serviceType) {
    switch (serviceType) {
      case 'car':
        return Icons.directions_car_outlined;
      case 'bike':
        return Icons.two_wheeler;
      case 'auto':
        return Icons.electric_rickshaw_outlined;
      case 'travels':
        return Icons.directions_bus_outlined;
      case 'cargo':
        return Icons.local_shipping_outlined;
      case 'rental':
        return Icons.car_rental;
      case 'carpool':
        return Icons.people_outline;
      default:
        return Icons.route_outlined;
    }
  }

  Future<void> _startTrip(
    BuildContext context,
    String bookingDocumentId,
  ) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(context, 'Please login again.');
      return;
    }

    try {
      await _bookings.doc(bookingDocumentId).update({
        'status': 'started',
        'tripStartedBy': user.uid,
        'tripStartedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) {
        return;
      }

      _showMessage(context, 'Trip started successfully.');
    } on FirebaseException catch (e) {
      if (!context.mounted) {
        return;
      }

      _showMessage(context, e.message ?? 'Unable to start trip.');
    }
  }

  Future<void> _completeTrip(
    BuildContext context,
    String bookingDocumentId,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Complete Trip'),
          content: const Text(
            'Are you sure you want to mark this trip as completed?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Complete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(context, 'Please login again.');
      return;
    }

    try {
      await _bookings.doc(bookingDocumentId).update({
        'status': 'completed',
        'completedBy': user.uid,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) {
        return;
      }

      _showMessage(context, 'Trip completed successfully.');
    } on FirebaseException catch (e) {
      if (!context.mounted) {
        return;
      }

      _showMessage(context, e.message ?? 'Unable to complete trip.');
    }
  }

  void _showDetails(BuildContext context, Map<String, dynamic> data) {
    final String bookingId = data['bookingId']?.toString() ?? '-';

    final String serviceType = data['serviceType']?.toString() ?? '';

    final String from =
        data['from']?.toString() ?? data['pickup']?.toString() ?? '-';

    final String to = data['to']?.toString() ?? data['drop']?.toString() ?? '-';

    final String date =
        data['bookingDate']?.toString() ??
        data['journeyDate']?.toString() ??
        '-';

    final String time =
        data['bookingTime']?.toString() ??
        data['journeyTime']?.toString() ??
        '-';

    final String vehicle = data['vehicleNumber']?.toString() ?? '-';

    final String fare = data['fare']?.toString() ?? '0';

    final String payment = data['paymentStatus']?.toString() ?? 'pending';

    final String notes = data['notes']?.toString() ?? '-';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(child: Icon(_serviceIcon(serviceType))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _serviceName(serviceType),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _DetailRow(label: 'Booking ID', value: bookingId),
                  _DetailRow(label: 'From', value: from),
                  _DetailRow(label: 'To', value: to),
                  _DetailRow(label: 'Date', value: date),
                  _DetailRow(label: 'Time', value: time),
                  _DetailRow(label: 'Vehicle', value: vehicle),
                  _DetailRow(label: 'Fare', value: fare),
                  _DetailRow(label: 'Payment', value: payment),
                  _DetailRow(label: 'Notes', value: notes),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('Please login as a driver.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _bookings
          .where('driverId', isEqualTo: user.uid)
          .where('status', whereIn: ['driver_assigned', 'started'])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load assigned trips.\n\n'
                '${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final documents = snapshot.data?.docs ?? [];

        if (documents.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.route_outlined, size: 72),
                  SizedBox(height: 16),
                  Text(
                    'No Assigned Trips',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Trips assigned to you will appear here.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: documents.length,
          separatorBuilder: (_, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final DocumentSnapshot<Map<String, dynamic>> document =
                documents[index];

            final Map<String, dynamic> data =
                document.data() ?? <String, dynamic>{};

            final String status =
                data['status']?.toString() ?? 'driver_assigned';

            final String serviceType = data['serviceType']?.toString() ?? '';

            final String from =
                data['from']?.toString() ?? data['pickup']?.toString() ?? '-';

            final String to =
                data['to']?.toString() ?? data['drop']?.toString() ?? '-';

            final String bookingId =
                data['bookingId']?.toString() ?? document.id;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(child: Icon(_serviceIcon(serviceType))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _serviceName(serviceType),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                bookingId,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Theme.of(context).colorScheme.primary
                                .withValues(alpha: 0.10),
                          ),
                          child: Text(
                            status == 'started' ? 'STARTED' : 'ASSIGNED',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _TripLocationRow(
                      icon: Icons.my_location,
                      label: 'From',
                      value: from,
                    ),
                    const SizedBox(height: 8),
                    _TripLocationRow(
                      icon: Icons.location_on_outlined,
                      label: 'To',
                      value: to,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            data['bookingDate']?.toString() ??
                                data['journeyDate']?.toString() ??
                                '-',
                          ),
                        ),
                        const Icon(Icons.access_time, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          data['bookingTime']?.toString() ??
                              data['journeyTime']?.toString() ??
                              '-',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _showDetails(context, data);
                            },
                            child: const Text('Details'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: status == 'started'
                                ? () {
                                    _completeTrip(context, document.id);
                                  }
                                : () {
                                    _startTrip(context, document.id);
                                  },
                            icon: Icon(
                              status == 'started'
                                  ? Icons.check_circle_outline
                                  : Icons.play_arrow,
                            ),
                            label: Text(
                              status == 'started' ? 'Complete' : 'Start Trip',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DriverProfilePage extends StatelessWidget {
  const _DriverProfilePage();

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) {
      return;
    }

    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(radius: 42, child: Icon(Icons.person, size: 42)),
            const SizedBox(height: 16),
            Text(
              user?.displayName ?? 'Driver',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              user?.email ?? 'No email available',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _logout(context);
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _DriverInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 30, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripLocationRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TripLocationRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
