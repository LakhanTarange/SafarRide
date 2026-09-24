import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';

class RentalBookingPage extends StatefulWidget {
  const RentalBookingPage({super.key});

  @override
  State<RentalBookingPage> createState() => _RentalBookingPageState();
}

class _RentalBookingPageState extends State<RentalBookingPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _vehicleType = 'Car';
  String _rentalUnit = 'Hours';
  int _duration = 4;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool _isLoading = false;

  final List<String> _vehicleTypes = [
    'Bike',
    'Car',
    'SUV',
    'Auto',
    'Tempo',
  ];

  @override
  void dispose() {
    _pickupController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime now = DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
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

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Select rental date';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) {
      return 'Select pickup time';
    }

    return time.format(context);
  }

  Future<void> _showBookingSummary() async {
    if (_pickupController.text.trim().isEmpty) {
      _showMessage('Please enter pickup location.');
      return;
    }

    if (_selectedDate == null) {
      _showMessage('Please select rental date.');
      return;
    }

    if (_selectedTime == null) {
      _showMessage('Please select pickup time.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rental Booking Summary',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _summaryRow('Vehicle', _vehicleType),
              _summaryRow(
                'Duration',
                '$_duration $_rentalUnit',
              ),
              _summaryRow(
                'Pickup',
                _pickupController.text.trim(),
              ),
              _summaryRow(
                'Date',
                _formatDate(_selectedDate),
              ),
              _summaryRow(
                'Time',
                _formatTime(_selectedTime),
              ),
              if (_notesController.text.trim().isNotEmpty)
                _summaryRow(
                  'Notes',
                  _notesController.text.trim(),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          Navigator.pop(context);
                          await _confirmBooking();
                        },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirm Rental Booking'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmBooking() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please login first.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final DocumentReference<Map<String, dynamic>> bookingReference =
          _firestore.collection('bookings').doc();

      final String bookingDate =
          '${_selectedDate!.year}-'
          '${_selectedDate!.month.toString().padLeft(2, '0')}-'
          '${_selectedDate!.day.toString().padLeft(2, '0')}';

      final String bookingTime =
          '${_selectedTime!.hour.toString().padLeft(2, '0')}:'
          '${_selectedTime!.minute.toString().padLeft(2, '0')}';

      await bookingReference.set({
        'bookingId': bookingReference.id,
        'customerId': user.uid,
        'serviceType': 'rental',
        'vehicleType': _vehicleType,
        'rentalDuration': _duration,
        'rentalUnit': _rentalUnit,
        'pickup': _pickupController.text.trim(),
        'bookingDate': bookingDate,
        'bookingTime': bookingTime,
        'notes': _notesController.text.trim(),
        'status': 'requested',
        'paymentStatus': 'pending',
        'driverId': null,
        'partnerId': null,
        'fare': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            icon: const Icon(
              Icons.check_circle,
              size: 56,
              color: Colors.green,
            ),
            title: const Text('Booking Requested'),
            content: const Text(
              'Your rental booking request has been submitted successfully.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      _pickupController.clear();
      _notesController.clear();

      setState(() {
        _selectedDate = null;
        _selectedTime = null;
        _duration = 4;
        _rentalUnit = 'Hours';
        _vehicleType = 'Car';
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;

      _showMessage(
        e.message ?? 'Unable to create rental booking.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rental Booking'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rent a Vehicle',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose a vehicle and rental duration.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Vehicle Type',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                initialValue: _vehicleType,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.directions_car_outlined),
                  border: OutlineInputBorder(),
                ),
                items: _vehicleTypes.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (String? value) {
                  if (value == null) return;

                  setState(() {
                    _vehicleType = value;
                  });
                },
              ),

              const SizedBox(height: 20),

              const Text(
                'Rental Duration',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _rentalUnit,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Hours',
                          child: Text('Hours'),
                        ),
                        DropdownMenuItem(
                          value: 'Days',
                          child: Text('Days'),
                        ),
                      ],
                      onChanged: (String? value) {
                        if (value == null) return;

                        setState(() {
                          _rentalUnit = value;
                          _duration = value == 'Hours' ? 4 : 1;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<int>(
                      initialValue: _duration,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: (_rentalUnit == 'Hours'
                              ? [1, 2, 4, 6, 8, 12, 24]
                              : [1, 2, 3, 5, 7, 15, 30])
                          .map((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text('$value'),
                        );
                      }).toList(),
                      onChanged: (int? value) {
                        if (value == null) return;

                        setState(() {
                          _duration = value;
                        });
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              TextField(
                controller: _pickupController,
                decoration: const InputDecoration(
                  labelText: 'Pickup Location',
                  hintText: 'Enter pickup location',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),

              const SizedBox(height: 16),

              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Rental Date',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  child: Text(_formatDate(_selectedDate)),
                ),
              ),

              const SizedBox(height: 16),

              InkWell(
                onTap: _selectTime,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Pickup Time',
                    prefixIcon: Icon(Icons.access_time_outlined),
                  ),
                  child: Text(_formatTime(_selectedTime)),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Additional requirements',
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : _showBookingSummary,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.car_rental),
                  label: Text(
                    _isLoading
                        ? 'Processing...'
                        : 'Review Rental Booking',
                  ),
                ),
              ),

              const SizedBox(height: 30),

              Center(
                child: Text(
                  '${AppConfig.appName} • ${AppConfig.companyName}',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}