import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';

class CargoBookingPage extends StatefulWidget {
  const CargoBookingPage({super.key});

  @override
  State<CargoBookingPage> createState() =>
      _CargoBookingPageState();
}

class _CargoBookingPageState
    extends State<CargoBookingPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final TextEditingController _pickupController =
      TextEditingController();

  final TextEditingController _destinationController =
      TextEditingController();

  final TextEditingController _goodsController =
      TextEditingController();

  final TextEditingController _weightController =
      TextEditingController();

  final TextEditingController _notesController =
      TextEditingController();

  String _vehicleType = 'Mini Tempo';

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  bool _isBooking = false;

  final List<String> _vehicleTypes = [
    'Mini Tempo',
    'Tempo',
    'Pickup Van',
    'Light Truck',
  ];

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _goodsController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(
        const Duration(days: 90),
      ),
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
      initialTime: _selectedTime,
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final String hour = time.hourOfPeriod == 0
        ? '12'
        : time.hourOfPeriod.toString();

    final String minute =
        time.minute.toString().padLeft(2, '0');

    final String period =
        time.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hour:$minute $period';
  }

  Future<void> _showBookingSummary() async {
    if (_pickupController.text.trim().isEmpty ||
        _destinationController.text.trim().isEmpty ||
        _goodsController.text.trim().isEmpty ||
        _weightController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill all required cargo details.',
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cargo Booking Summary',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                _summaryRow(
                  Icons.local_shipping_outlined,
                  'Vehicle',
                  _vehicleType,
                ),

                _summaryRow(
                  Icons.location_on_outlined,
                  'Pickup',
                  _pickupController.text.trim(),
                ),

                _summaryRow(
                  Icons.flag_outlined,
                  'Destination',
                  _destinationController.text.trim(),
                ),

                _summaryRow(
                  Icons.inventory_2_outlined,
                  'Goods',
                  _goodsController.text.trim(),
                ),

                _summaryRow(
                  Icons.scale_outlined,
                  'Weight',
                  '${_weightController.text.trim()} kg',
                ),

                _summaryRow(
                  Icons.calendar_today_outlined,
                  'Date',
                  _formatDate(_selectedDate),
                ),

                _summaryRow(
                  Icons.access_time,
                  'Time',
                  _formatTime(_selectedTime),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isBooking
                        ? null
                        : () async {
                            Navigator.pop(context);
                            await _confirmBooking();
                          },
                    icon: _isBooking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.check_circle_outline,
                          ),
                    label: Text(
                      _isBooking
                          ? 'Booking...'
                          : 'Confirm Cargo Booking',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _summaryRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 22,
            color:
                Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmBooking() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please login before booking.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isBooking = true;
    });

    try {
      final DocumentReference<Map<String, dynamic>>
          bookingReference =
          _firestore.collection('bookings').doc();

      await bookingReference.set({
        'bookingId': bookingReference.id,
        'customerId': user.uid,
        'serviceType': 'cargo',
        'pickup': _pickupController.text.trim(),
        'destination':
            _destinationController.text.trim(),
        'vehicleType': _vehicleType,
        'goodsType': _goodsController.text.trim(),
        'weightKg':
            double.tryParse(_weightController.text.trim()) ?? 0,
        'notes': _notesController.text.trim(),
        'bookingDate': _formatDate(_selectedDate),
        'bookingTime': _formatTime(_selectedTime),
        'status': 'requested',
        'paymentStatus': 'pending',
        'driverId': null,
        'partnerId': null,
        'fare': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _isBooking = false;
      });

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cargo Booking Created',
                  ),
                ),
              ],
            ),
            content: Text(
              'Your cargo transport request has been '
              'created successfully.\n\n'
              'Booking ID:\n${bookingReference.id}',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Done'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      _pickupController.clear();
      _destinationController.clear();
      _goodsController.clear();
      _weightController.clear();
      _notesController.clear();
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        _isBooking = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ??
                'Unable to create cargo booking.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isBooking = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Something went wrong. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cargo / Tempo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor:
                          Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                      child: Icon(
                        Icons.local_shipping,
                        size: 30,
                        color: Theme.of(context)
                            .colorScheme
                            .primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cargo & Tempo',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Book a vehicle for goods transportation',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),

            const Text(
              'Vehicle Type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _vehicleTypes.length,
                separatorBuilder:
                    (context, index) =>
                        const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final String type =
                      _vehicleTypes[index];

                  final bool selected =
                      _vehicleType == type;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _vehicleType = type;
                      });
                    },
                    child: AnimatedContainer(
                      duration:
                          const Duration(milliseconds: 200),
                      width: 140,
                      padding:
                          const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected
                            ? Theme.of(context)
                                .colorScheme
                                .primaryContainer
                            : Theme.of(context)
                                .colorScheme
                                .surface,
                        borderRadius:
                            BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                              : Colors.grey.shade300,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.local_shipping,
                            size: 30,
                            color: selected
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                : Colors.grey.shade700,
                          ),
                          const SizedBox(height: 7),
                          Text(
                            type,
                            textAlign:
                                TextAlign.center,
                            style: TextStyle(
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            TextField(
              controller: _pickupController,
              textInputAction:
                  TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Pickup Location',
                hintText:
                    'Enter goods pickup location',
                prefixIcon: Icon(
                  Icons.location_on_outlined,
                ),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller:
                  _destinationController,
              textInputAction:
                  TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Delivery Location',
                hintText:
                    'Enter goods delivery location',
                prefixIcon: Icon(
                  Icons.flag_outlined,
                ),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: _goodsController,
              textInputAction:
                  TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Goods Details',
                hintText:
                    'Example: Boxes, furniture, material',
                prefixIcon: Icon(
                  Icons.inventory_2_outlined,
                ),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: _weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction:
                  TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Approximate Weight',
                hintText: 'Enter weight in kg',
                suffixText: 'kg',
                prefixIcon: Icon(
                  Icons.scale_outlined,
                ),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: _notesController,
              maxLines: 3,
              textInputAction:
                  TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Additional Notes',
                hintText:
                    'Any special instructions',
                prefixIcon: Icon(
                  Icons.notes_outlined,
                ),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 22),

            const Text(
              'Pickup Schedule',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectDate,
                    icon: const Icon(
                      Icons.calendar_today_outlined,
                    ),
                    label: Text(
                      _formatDate(_selectedDate),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectTime,
                    icon: const Icon(
                      Icons.access_time,
                    ),
                    label: Text(
                      _formatTime(_selectedTime),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _isBooking
                    ? null
                    : _showBookingSummary,
                icon: const Icon(
                  Icons.arrow_forward,
                ),
                label: const Text(
                  'Continue Booking',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            Center(
              child: Text(
                AppConfig.companyName,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 4),

            Center(
              child: Text(
                AppConfig.appTagline,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}