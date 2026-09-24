import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BikeBookingPage extends StatefulWidget {
  final String? preselectedVehicleId;
  final Map<String, dynamic>? preselectedVehicle;

  const BikeBookingPage({
    super.key,
    this.preselectedVehicleId,
    this.preselectedVehicle,
  });

  @override
  State<BikeBookingPage> createState() => _BikeBookingPageState();
}

class _BikeBookingPageState extends State<BikeBookingPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _fromController = TextEditingController();

  final TextEditingController _toController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  String _bikeType = 'Bike';

  bool _isBooking = false;

  @override
  void initState() {
    super.initState();

    final String? vehicleType = widget.preselectedVehicle?['vehicleType']
        ?.toString();

    if (vehicleType != null && vehicleType.isNotEmpty) {
      _bikeType = vehicleType;
    }
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  bool get _hasPreselectedVehicle =>
      widget.preselectedVehicleId != null && widget.preselectedVehicle != null;

  Future<void> _selectDate() async {
    final DateTime now = DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _selectedDate ?? now,
    );

    if (picked != null && mounted) {
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

    if (picked != null && mounted) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _confirmBooking() async {
    FocusScope.of(context).unfocus();

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Please login again.');
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

    String? vehicleId;
    String? driverId;
    String? partnerId;

    String vehicleNumber = '';
    String vehicleBrand = '';
    String vehicleModel = '';
    String driverName = '';

    if (_hasPreselectedVehicle) {
      final Map<String, dynamic> vehicle = widget.preselectedVehicle!;

      vehicleId = widget.preselectedVehicleId;

      driverId = vehicle['driverId']?.toString();

      partnerId = vehicle['ownerId']?.toString();

      vehicleNumber = vehicle['vehicleNumber']?.toString() ?? '';

      vehicleBrand = vehicle['brand']?.toString() ?? '';

      vehicleModel = vehicle['model']?.toString() ?? '';

      driverName = vehicle['driverName']?.toString() ?? '';

      if (vehicleId == null || vehicleId.isEmpty) {
        _showMessage('Selected vehicle is invalid.');
        return;
      }

      if (driverId == null || driverId.isEmpty) {
        _showMessage('This bike does not have an assigned driver.');
        return;
      }

      if (partnerId == null || partnerId.isEmpty) {
        _showMessage('This bike does not have an assigned owner.');
        return;
      }
    }

    final String bookingDate =
        '${_selectedDate!.day.toString().padLeft(2, '0')}/'
        '${_selectedDate!.month.toString().padLeft(2, '0')}/'
        '${_selectedDate!.year}';

    final String bookingTime = _selectedTime!.format(context);

    setState(() {
      _isBooking = true;
    });

    try {
      final DocumentReference<Map<String, dynamic>> bookingReference =
          _firestore.collection('bookings').doc();

      await bookingReference.set({
        'bookingId': bookingReference.id,
        'customerId': user.uid,

        'serviceType': 'bike',
        'vehicleType': _bikeType,

        'vehicleId': vehicleId,
        'vehicleNumber': vehicleNumber,
        'vehicleBrand': vehicleBrand,
        'vehicleModel': vehicleModel,

        'driverId': driverId,
        'driverName': driverName,
        'partnerId': partnerId,

        'pickup': _fromController.text.trim(),
        'destination': _toController.text.trim(),

        'from': _fromController.text.trim(),
        'to': _toController.text.trim(),

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
                const Text('Your bike booking has been created successfully.'),
                const SizedBox(height: 16),
                const Text(
                  'Booking ID',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  bookingReference.id,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
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
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? vehicle = widget.preselectedVehicle;

    return Scaffold(
      appBar: AppBar(title: const Text('Book a Bike')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_hasPreselectedVehicle && vehicle != null)
              _SelectedBikeCard(data: vehicle)
            else ...[
              const Text(
                'Bike Type',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _BikeTypeChip(
                    label: 'Bike',
                    selected: _bikeType == 'Bike',
                    onTap: () {
                      setState(() {
                        _bikeType = 'Bike';
                      });
                    },
                  ),
                  _BikeTypeChip(
                    label: 'Scooter',
                    selected: _bikeType == 'Scooter',
                    onTap: () {
                      setState(() {
                        _bikeType = 'Scooter';
                      });
                    },
                  ),
                  _BikeTypeChip(
                    label: 'Premium Bike',
                    selected: _bikeType == 'Premium Bike',
                    onTap: () {
                      setState(() {
                        _bikeType = 'Premium Bike';
                      });
                    },
                  ),
                ],
              ),
            ],

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
                border: OutlineInputBorder(),
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
                border: OutlineInputBorder(),
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

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: _isBooking ? null : _confirmBooking,
                icon: _isBooking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.two_wheeler),
                label: Text(_isBooking ? 'Booking...' : 'Confirm Bike Booking'),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SelectedBikeCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _SelectedBikeCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final String brand = data['brand']?.toString() ?? '';

    final String model = data['model']?.toString() ?? '';

    final String number = data['vehicleNumber']?.toString() ?? '';

    final String driver = data['driverName']?.toString() ?? '';

    final String type = data['vehicleType']?.toString() ?? 'Bike';

    final String title = [
      brand,
      model,
    ].where((value) => value.isNotEmpty).join(' ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selected Vehicle',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const CircleAvatar(
                radius: 28,
                child: Icon(Icons.two_wheeler, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? type : title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (number.isNotEmpty) Text('Vehicle: $number'),
                    Text('Type: $type'),
                    if (driver.isNotEmpty) Text('Driver: $driver'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BikeTypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BikeTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        onTap();
      },
    );
  }
}
