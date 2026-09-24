import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';

class CarpoolPage extends StatefulWidget {
  const CarpoolPage({super.key});

  @override
  State<CarpoolPage> createState() => _CarpoolPageState();
}

class _CarpoolPageState extends State<CarpoolPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _vehicleType = 'Car';
  int _availableSeats = 1;

  DateTime? _journeyDate;
  TimeOfDay? _journeyTime;

  bool _isLoading = false;

  final List<String> _vehicleTypes = [
    'Car',
    'SUV',
    'Bike',
  ];

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime now = DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _journeyDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _journeyDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _journeyTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _journeyTime = picked;
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Select journey date';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) {
      return 'Select journey time';
    }

    return time.format(context);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> _showSummary() async {
    if (_fromController.text.trim().isEmpty) {
      _showMessage('Please enter starting location.');
      return;
    }

    if (_toController.text.trim().isEmpty) {
      _showMessage('Please enter destination.');
      return;
    }

    if (_journeyDate == null) {
      _showMessage('Please select journey date.');
      return;
    }

    if (_journeyTime == null) {
      _showMessage('Please select journey time.');
      return;
    }

    if (_costController.text.trim().isEmpty) {
      _showMessage('Please enter fuel cost sharing amount.');
      return;
    }

    final double? cost = double.tryParse(
      _costController.text.trim(),
    );

    if (cost == null || cost < 0) {
      _showMessage('Please enter a valid cost amount.');
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
                'Carpool Summary',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _summaryRow(
                'Vehicle',
                _vehicleType,
              ),
              _summaryRow(
                'From',
                _fromController.text.trim(),
              ),
              _summaryRow(
                'To',
                _toController.text.trim(),
              ),
              _summaryRow(
                'Date',
                _formatDate(_journeyDate),
              ),
              _summaryRow(
                'Time',
                _formatTime(_journeyTime),
              ),
              _summaryRow(
                'Seats',
                '$_availableSeats',
              ),
              _summaryRow(
                'Fuel Share',
                '₹${cost.toStringAsFixed(2)}',
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
                          await _createCarpool();
                        },
                  icon: const Icon(
                    Icons.check_circle_outline,
                  ),
                  label: const Text(
                    'Post Carpool',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryRow(
    String title,
    String value,
  ) {
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

  Future<void> _createCarpool() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please login first.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final DocumentReference<Map<String, dynamic>> carpoolReference =
          _firestore.collection('carpools').doc();

      final String journeyDate =
          '${_journeyDate!.year}-'
          '${_journeyDate!.month.toString().padLeft(2, '0')}-'
          '${_journeyDate!.day.toString().padLeft(2, '0')}';

      final String journeyTime =
          '${_journeyTime!.hour.toString().padLeft(2, '0')}:'
          '${_journeyTime!.minute.toString().padLeft(2, '0')}';

      final double fuelCost = double.parse(
        _costController.text.trim(),
      );

      await carpoolReference.set({
        'carpoolId': carpoolReference.id,
        'ownerId': user.uid,
        'ownerName': user.displayName ?? '',
        'ownerEmail': user.email ?? '',
        'vehicleType': _vehicleType,
        'from': _fromController.text.trim(),
        'to': _toController.text.trim(),
        'journeyDate': journeyDate,
        'journeyTime': journeyTime,
        'availableSeats': _availableSeats,
        'bookedSeats': 0,
        'fuelCostSharing': fuelCost,
        'notes': _notesController.text.trim(),
        'status': 'active',
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
            title: const Text(
              'Carpool Posted',
            ),
            content: const Text(
              'Your carpool journey has been posted successfully.',
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

      _fromController.clear();
      _toController.clear();
      _costController.clear();
      _notesController.clear();

      setState(() {
        _vehicleType = 'Car';
        _availableSeats = 1;
        _journeyDate = null;
        _journeyTime = null;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;

      _showMessage(
        e.message ?? 'Unable to post carpool.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carpool'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share Your Journey',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Post your route and share available seats.',
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
                  prefixIcon: Icon(
                    Icons.directions_car_outlined,
                  ),
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

              TextField(
                controller: _fromController,
                decoration: const InputDecoration(
                  labelText: 'Starting Location',
                  hintText: 'Enter starting location',
                  prefixIcon: Icon(
                    Icons.my_location_outlined,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _toController,
                decoration: const InputDecoration(
                  labelText: 'Destination',
                  hintText: 'Enter destination',
                  prefixIcon: Icon(
                    Icons.location_on_outlined,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Journey Date',
                    prefixIcon: Icon(
                      Icons.calendar_month_outlined,
                    ),
                  ),
                  child: Text(
                    _formatDate(_journeyDate),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              InkWell(
                onTap: _selectTime,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Journey Time',
                    prefixIcon: Icon(
                      Icons.access_time_outlined,
                    ),
                  ),
                  child: Text(
                    _formatTime(_journeyTime),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Available Seats',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              DropdownButtonFormField<int>(
                initialValue: _availableSeats,
                decoration: const InputDecoration(
                  prefixIcon: Icon(
                    Icons.event_seat_outlined,
                  ),
                  border: OutlineInputBorder(),
                ),
                items: List.generate(
                  7,
                  (index) => index + 1,
                ).map((int seats) {
                  return DropdownMenuItem<int>(
                    value: seats,
                    child: Text('$seats seat${seats == 1 ? '' : 's'}'),
                  );
                }).toList(),
                onChanged: (int? value) {
                  if (value == null) return;

                  setState(() {
                    _availableSeats = value;
                  });
                },
              ),

              const SizedBox(height: 20),

              TextField(
                controller: _costController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Fuel Cost Sharing',
                  hintText: 'Enter amount',
                  prefixText: '₹ ',
                  prefixIcon: Icon(
                    Icons.currency_rupee,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Additional information',
                  prefixIcon: Icon(
                    Icons.notes_outlined,
                  ),
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
                      : _showSummary,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.groups_outlined,
                        ),
                  label: Text(
                    _isLoading
                        ? 'Posting...'
                        : 'Review & Post Carpool',
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