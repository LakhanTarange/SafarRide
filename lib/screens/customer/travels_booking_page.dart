import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';

class TravelsBookingPage extends StatefulWidget {
  const TravelsBookingPage({super.key});

  @override
  State<TravelsBookingPage> createState() =>
      _TravelsBookingPageState();
}

class _TravelsBookingPageState
    extends State<TravelsBookingPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final TextEditingController _fromController =
      TextEditingController();

  final TextEditingController _toController =
      TextEditingController();

  int _passengers = 1;

  String _travelType = 'Bus';

  DateTime _journeyDate = DateTime.now();

  bool _isBooking = false;

  final List<String> _travelTypes = [
    'Bus',
    'Mini Bus',
    'Tempo Traveller',
    'Tourist Vehicle',
  ];

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  Future<void> _selectJourneyDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _journeyDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(
        const Duration(days: 365),
      ),
    );

    if (picked != null) {
      setState(() {
        _journeyDate = picked;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  void _increasePassengers() {
    if (_passengers >= 50) {
      return;
    }

    setState(() {
      _passengers++;
    });
  }

  void _decreasePassengers() {
    if (_passengers <= 1) {
      return;
    }

    setState(() {
      _passengers--;
    });
  }

  Future<void> _showBookingSummary() async {
    if (_fromController.text.trim().isEmpty ||
        _toController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter departure and destination.',
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
                  'Booking Summary',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                _summaryRow(
                  Icons.directions_bus,
                  'Travel Type',
                  _travelType,
                ),

                _summaryRow(
                  Icons.location_on_outlined,
                  'From',
                  _fromController.text.trim(),
                ),

                _summaryRow(
                  Icons.flag_outlined,
                  'To',
                  _toController.text.trim(),
                ),

                _summaryRow(
                  Icons.calendar_today_outlined,
                  'Journey Date',
                  _formatDate(_journeyDate),
                ),

                _summaryRow(
                  Icons.people_outline,
                  'Passengers',
                  _passengers.toString(),
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
                          : 'Confirm Travels Booking',
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
        'serviceType': 'travels',
        'pickup': _fromController.text.trim(),
        'destination': _toController.text.trim(),
        'vehicleType': _travelType,
        'bookingDate': _formatDate(_journeyDate),
        'bookingTime': null,
        'passengers': _passengers,
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
                    'Booking Created',
                  ),
                ),
              ],
            ),
            content: Text(
              'Your travels booking request has been '
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

      _fromController.clear();
      _toController.clear();

      setState(() {
        _passengers = 1;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        _isBooking = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ??
                'Unable to create travels booking.',
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
        title: const Text('Travels Booking'),
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
                        Icons.directions_bus,
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
                            'Book Travels',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          SizedBox(height: 4),

                          Text(
                            'Plan your inter-city journey with ease',
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
              'Travel Type',
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
                itemCount: _travelTypes.length,

                separatorBuilder:
                    (context, index) =>
                        const SizedBox(width: 12),

                itemBuilder: (context, index) {
                  final String type =
                      _travelTypes[index];

                  final bool selected =
                      _travelType == type;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _travelType = type;
                      });
                    },

                    child: AnimatedContainer(
                      duration: const Duration(
                        milliseconds: 200,
                      ),

                      width: 145,

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
                            Icons.directions_bus,
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
              controller: _fromController,

              textInputAction:
                  TextInputAction.next,

              decoration:
                  const InputDecoration(
                labelText: 'From',
                hintText:
                    'Enter departure location',

                prefixIcon: Icon(
                  Icons.location_on_outlined,
                ),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: _toController,

              textInputAction:
                  TextInputAction.done,

              decoration:
                  const InputDecoration(
                labelText: 'To',
                hintText:
                    'Enter destination',

                prefixIcon: Icon(
                  Icons.flag_outlined,
                ),
              ),
            ),

            const SizedBox(height: 22),

            const Text(
              'Journey Date',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,

              child: OutlinedButton.icon(
                onPressed: _selectJourneyDate,

                icon: const Icon(
                  Icons.calendar_today_outlined,
                ),

                label: Text(
                  _formatDate(_journeyDate),
                ),
              ),
            ),

            const SizedBox(height: 22),

            const Text(
              'Passengers',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),

                child: Row(
                  children: [
                    const Icon(
                      Icons.people_outline,
                    ),

                    const SizedBox(width: 12),

                    const Expanded(
                      child: Text(
                        'Number of Passengers',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),

                    IconButton(
                      onPressed:
                          _decreasePassengers,
                      icon: const Icon(
                        Icons.remove_circle_outline,
                      ),
                    ),

                    Text(
                      _passengers.toString(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    IconButton(
                      onPressed:
                          _increasePassengers,
                      icon: const Icon(
                        Icons.add_circle_outline,
                      ),
                    ),
                  ],
                ),
              ),
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
                    fontWeight:
                        FontWeight.bold,
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