import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CarBookingPage extends StatefulWidget {
  final String? preselectedVehicleId;
  final Map<String, dynamic>? preselectedVehicle;

  const CarBookingPage({
    super.key,
    this.preselectedVehicleId,
    this.preselectedVehicle,
  });

  @override
  State<CarBookingPage> createState() => _CarBookingPageState();
}

class _CarBookingPageState extends State<CarBookingPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _fromController = TextEditingController();

  final TextEditingController _toController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  String? _selectedVehicleId;
  Map<String, dynamic>? _selectedVehicle;

  bool _isBooking = false;

  bool get _hasPreselectedVehicle =>
      widget.preselectedVehicleId != null && widget.preselectedVehicle != null;

  @override
  void initState() {
    super.initState();

    if (_hasPreselectedVehicle) {
      _selectedVehicleId = widget.preselectedVehicleId;
      _selectedVehicle = widget.preselectedVehicle;
    }
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _availableCarsStream() {
    return _firestore
        .collection('vehicles')
        .where('vehicleType', isEqualTo: 'Car')
        .where('status', isEqualTo: 'active')
        .snapshots();
  }

  Future<void> _selectDate() async {
    final DateTime now = DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _selectedDate ?? now,
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<String> _generateBookingId(Transaction transaction) async {
    final counterRef = _firestore.collection('bookingCounters').doc('main');

    final snapshot = await transaction.get(counterRef);

    int nextNumber = 100001;

    if (snapshot.exists) {
      final dynamic currentNumber = snapshot.data()?['lastNumber'];

      if (currentNumber is int) {
        nextNumber = currentNumber + 1;
      } else if (currentNumber is num) {
        nextNumber = currentNumber.toInt() + 1;
      }
    }

    transaction.set(counterRef, {
      'lastNumber': nextNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return 'SR$nextNumber';
  }

  Future<void> _bookCar() async {
    FocusScope.of(context).unfocus();

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Please login again.');
      return;
    }

    if (_selectedVehicleId == null || _selectedVehicle == null) {
      _showMessage('Please select a car.');
      return;
    }

    if (_fromController.text.trim().isEmpty) {
      _showMessage('Please enter pickup location.');
      return;
    }

    if (_toController.text.trim().isEmpty) {
      _showMessage('Please enter destination.');
      return;
    }

    if (_selectedDate == null) {
      _showMessage('Please select journey date.');
      return;
    }

    if (_selectedTime == null) {
      _showMessage('Please select journey time.');
      return;
    }

    final String? driverId = _selectedVehicle?['driverId']?.toString();

    final String? ownerId = _selectedVehicle?['ownerId']?.toString();

    if (driverId == null ||
        driverId.isEmpty ||
        ownerId == null ||
        ownerId.isEmpty) {
      _showMessage('This car does not have an assigned driver.');
      return;
    }

    final String bookingTime = _selectedTime!.format(context);

    final String bookingDate =
        '${_selectedDate!.day.toString().padLeft(2, '0')}/'
        '${_selectedDate!.month.toString().padLeft(2, '0')}/'
        '${_selectedDate!.year}';

    final String fromLocation = _fromController.text.trim();

    final String toLocation = _toController.text.trim();

    final String vehicleId = _selectedVehicleId!;

    final String vehicleNumber =
        _selectedVehicle?['vehicleNumber']?.toString() ?? '';

    final String vehicleBrand = _selectedVehicle?['brand']?.toString() ?? '';

    final String vehicleModel = _selectedVehicle?['model']?.toString() ?? '';

    final String driverName = _selectedVehicle?['driverName']?.toString() ?? '';

    setState(() {
      _isBooking = true;
    });

    try {
      final bookingRef = _firestore.collection('bookings').doc();

      String generatedBookingId = '';

      await _firestore.runTransaction((transaction) async {
        generatedBookingId = await _generateBookingId(transaction);

        transaction.set(bookingRef, {
          'bookingId': generatedBookingId,
          'customerId': user.uid,
          'serviceType': 'car',
          'vehicleType': 'Car',
          'vehicleId': vehicleId,
          'vehicleNumber': vehicleNumber,
          'vehicleBrand': vehicleBrand,
          'vehicleModel': vehicleModel,
          'partnerId': ownerId,
          'driverId': driverId,
          'driverName': driverName,
          'from': fromLocation,
          'to': toLocation,
          'bookingDate': bookingDate,
          'bookingTime': bookingTime,
          'fare': 0,
          'paymentStatus': 'pending',
          'status': 'requested',
          'ratingSubmitted': false,
          'hasComplaint': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 10),
                Text('Booking Successful'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Your booking has been created successfully.'),
                const SizedBox(height: 16),
                const Text(
                  'Booking ID',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  generatedBookingId,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Done'),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
    } on FirebaseException catch (e) {
      _showMessage(e.message ?? 'Unable to create booking.');
    } catch (_) {
      _showMessage('Unable to create booking.');
    } finally {
      if (mounted) {
        setState(() {
          _isBooking = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _selectVehicle(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    setState(() {
      _selectedVehicleId = document.id;
      _selectedVehicle = document.data();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasPreselectedVehicle) {
      return _buildBookingPage(context, [_selectedVehicle!]);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Book a Car')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _availableCarsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load cars.\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final cars = snapshot.data?.docs ?? [];

          final availableCars = cars.where((document) {
            final data = document.data();

            final String driverId = data['driverId']?.toString() ?? '';

            final bool isAvailable = data['isAvailable'] == true;

            return driverId.isNotEmpty && isAvailable;
          }).toList();

          return _buildBookingPage(context, availableCars);
        },
      ),
    );
  }

  Widget _buildBookingPage(BuildContext context, List<dynamic> cars) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book a Car')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selected Car',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (_selectedVehicle != null)
              _SelectedCarSummary(data: _selectedVehicle!)
            else
              ...cars.map((item) {
                final document =
                    item as QueryDocumentSnapshot<Map<String, dynamic>>;

                return _CarCard(
                  documentId: document.id,
                  data: document.data(),
                  selected: document.id == _selectedVehicleId,
                  onTap: () {
                    _selectVehicle(document);
                  },
                );
              }),

            const SizedBox(height: 24),

            const Text(
              'Journey Details',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _fromController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Pickup Location',
                hintText: 'Enter pickup location',
                prefixIcon: Icon(Icons.my_location),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: _toController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Destination',
                hintText: 'Enter destination',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectDate,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      _selectedDate == null
                          ? 'Select Date'
                          : '${_selectedDate!.day.toString().padLeft(2, '0')}/'
                                '${_selectedDate!.month.toString().padLeft(2, '0')}/'
                                '${_selectedDate!.year}',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      _selectedTime == null
                          ? 'Select Time'
                          : _selectedTime!.format(context),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _isBooking ? null : _bookCar,
                icon: _isBooking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.local_taxi),
                label: Text(_isBooking ? 'Booking...' : 'Book Car'),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _CarCard extends StatelessWidget {
  final String documentId;
  final Map<String, dynamic> data;
  final bool selected;
  final VoidCallback onTap;

  const _CarCard({
    required this.documentId,
    required this.data,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String vehicleNumber = data['vehicleNumber']?.toString() ?? '';

    final String brand = data['brand']?.toString() ?? '';

    final String model = data['model']?.toString() ?? '';

    final String driverName = data['driverName']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: selected ? 3 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 28,
                child: Icon(Icons.directions_car, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        brand,
                        model,
                      ].where((value) => value.isNotEmpty).join(' '),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (vehicleNumber.isNotEmpty) Text(vehicleNumber),
                    if (driverName.isNotEmpty) Text('Driver: $driverName'),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedCarSummary extends StatelessWidget {
  final Map<String, dynamic> data;

  const _SelectedCarSummary({required this.data});

  @override
  Widget build(BuildContext context) {
    final String number = data['vehicleNumber']?.toString() ?? '';

    final String brand = data['brand']?.toString() ?? '';

    final String model = data['model']?.toString() ?? '';

    final String driver = data['driverName']?.toString() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [brand, model].where((value) => value.isNotEmpty).join(' '),
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          if (number.isNotEmpty) Text('Vehicle: $number'),
          if (driver.isNotEmpty) Text('Driver: $driver'),
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.verified, size: 18),
              SizedBox(width: 5),
              Text('Selected nearby vehicle'),
            ],
          ),
        ],
      ),
    );
  }
}
