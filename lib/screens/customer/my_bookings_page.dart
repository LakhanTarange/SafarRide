import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyBookingsPage extends StatefulWidget {
  const MyBookingsPage({super.key});

  @override
  State<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    final User? user = _currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Bookings'),
        ),
        body: const Center(
          child: Text('Please login again.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('bookings')
            .where('customerId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load bookings.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final List<QueryDocumentSnapshot<Map<String, dynamic>>> bookings =
              snapshot.data?.docs.toList() ?? [];

          bookings.sort((a, b) {
            final Timestamp? aTime =
                a.data()['createdAt'] as Timestamp?;
            final Timestamp? bTime =
                b.data()['createdAt'] as Timestamp?;

            if (aTime == null && bTime == null) {
              return 0;
            }

            if (aTime == null) {
              return 1;
            }

            if (bTime == null) {
              return -1;
            }

            return bTime.compareTo(aTime);
          });

          if (bookings.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No bookings yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your bookings will appear here.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final QueryDocumentSnapshot<Map<String, dynamic>> document =
                    bookings[index];

                return _BookingCard(
                  document: document,
                  onTap: () {
                    _showBookingDetails(
                      context,
                      document,
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showBookingDetails(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> booking = document.data();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: _BookingDetails(
              booking: booking,
              bookingDocumentId: document.id,
              onRating: () {
                Navigator.pop(sheetContext);
                _showRatingDialog(
                  context,
                  document,
                );
              },
              onComplaint: () {
                Navigator.pop(sheetContext);
                _showComplaintDialog(
                  context,
                  document,
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showRatingDialog(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final Map<String, dynamic> booking = document.data();

    final String status =
        (booking['status'] ?? '').toString().toLowerCase();

    if (status != 'completed') {
      _showMessage(
        context,
        'Rating is available after trip completion.',
      );
      return;
    }

    final String bookingDocumentId = document.id;
    final String driverId =
        (booking['driverId'] ?? '').toString();

    if (driverId.isEmpty) {
      _showMessage(
        context,
        'Driver information is not available for this booking.',
      );
      return;
    }

    final String existingRating =
        (booking['rating'] ?? '').toString();

    int selectedRating =
        int.tryParse(existingRating) ?? 0;

    final TextEditingController feedbackController =
        TextEditingController(
      text: (booking['feedback'] ?? '').toString(),
    );

    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Rate Your Trip'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'How was your experience?',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (index) {
                          final int starNumber = index + 1;

                          return IconButton(
                            onPressed: isSaving
                                ? null
                                : () {
                                    setDialogState(() {
                                      selectedRating = starNumber;
                                    });
                                  },
                            icon: Icon(
                              starNumber <= selectedRating
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 38,
                              color: starNumber <= selectedRating
                                  ? Colors.amber
                                  : Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: feedbackController,
                      maxLines: 4,
                      maxLength: 500,
                      enabled: !isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Feedback',
                        hintText: 'Tell us about your experience',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (selectedRating < 1 ||
                              selectedRating > 5) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please select a rating from 1 to 5.',
                                ),
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                          });

                          try {
                            await _firestore
                                .collection('bookings')
                                .doc(bookingDocumentId)
                                .update({
                              'rating': selectedRating,
                              'feedback':
                                  feedbackController.text.trim(),
                              'ratingSubmitted': true,
                              'ratingSubmittedAt':
                                  FieldValue.serverTimestamp(),
                              'updatedAt':
                                  FieldValue.serverTimestamp(),
                            });

                            if (!dialogContext.mounted) {
                              return;
                            }

                            Navigator.pop(dialogContext);

                            _showMessage(
                              context,
                              'Rating and feedback saved successfully.',
                            );
                          } on FirebaseException catch (e) {
                            setDialogState(() {
                              isSaving = false;
                            });

                            if (!dialogContext.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.message ??
                                      'Unable to save rating.',
                                ),
                              ),
                            );
                          } catch (e) {
                            setDialogState(() {
                              isSaving = false;
                            });

                            if (!dialogContext.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Unable to save rating.',
                                ),
                              ),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    feedbackController.dispose();
  }

  Future<void> _showComplaintDialog(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final Map<String, dynamic> booking = document.data();

    final String status =
        (booking['status'] ?? '').toString().toLowerCase();

    if (status != 'completed' &&
        status != 'started' &&
        status != 'driver_assigned') {
      _showMessage(
        context,
        'Complaint can be submitted after driver assignment.',
      );
      return;
    }

    final TextEditingController complaintController =
        TextEditingController();

    String selectedCategory = 'Driver behaviour';

    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Submit Complaint'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Complaint Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Driver behaviour',
                          child: Text('Driver behaviour'),
                        ),
                        DropdownMenuItem(
                          value: 'Vehicle issue',
                          child: Text('Vehicle issue'),
                        ),
                        DropdownMenuItem(
                          value: 'Trip issue',
                          child: Text('Trip issue'),
                        ),
                        DropdownMenuItem(
                          value: 'Payment issue',
                          child: Text('Payment issue'),
                        ),
                        DropdownMenuItem(
                          value: 'Other',
                          child: Text('Other'),
                        ),
                      ],
                      onChanged: isSaving
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }

                              setDialogState(() {
                                selectedCategory = value;
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: complaintController,
                      maxLines: 5,
                      maxLength: 1000,
                      enabled: !isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Complaint',
                        hintText: 'Describe your complaint',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final String complaint =
                              complaintController.text.trim();

                          if (complaint.isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter your complaint.',
                                ),
                              ),
                            );
                            return;
                          }

                          final User? user =
                              FirebaseAuth.instance.currentUser;

                          if (user == null) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please login again.',
                                ),
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                          });

                          try {
                            final DocumentReference<Map<String, dynamic>>
                                complaintReference =
                                _firestore.collection('complaints').doc();

                            await complaintReference.set({
                              'complaintId': complaintReference.id,
                              'bookingId': document.id,
                              'customerId': user.uid,
                              'partnerId':
                                  booking['partnerId'],
                              'driverId':
                                  booking['driverId'],
                              'driverName':
                                  booking['driverName'],
                              'vehicleId':
                                  booking['vehicleId'],
                              'vehicleNumber':
                                  booking['vehicleNumber'],
                              'serviceType':
                                  booking['serviceType'],
                              'category': selectedCategory,
                              'complaint': complaint,
                              'status': 'open',
                              'createdAt':
                                  FieldValue.serverTimestamp(),
                              'updatedAt':
                                  FieldValue.serverTimestamp(),
                            });

                            await _firestore
                                .collection('bookings')
                                .doc(document.id)
                                .update({
                              'hasComplaint': true,
                              'complaintId':
                                  complaintReference.id,
                              'updatedAt':
                                  FieldValue.serverTimestamp(),
                            });

                            if (!dialogContext.mounted) {
                              return;
                            }

                            Navigator.pop(dialogContext);

                            _showMessage(
                              context,
                              'Complaint submitted successfully.',
                            );
                          } on FirebaseException catch (e) {
                            setDialogState(() {
                              isSaving = false;
                            });

                            if (!dialogContext.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.message ??
                                      'Unable to submit complaint.',
                                ),
                              ),
                            );
                          } catch (e) {
                            setDialogState(() {
                              isSaving = false;
                            });

                            if (!dialogContext.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Unable to submit complaint.',
                                ),
                              ),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Submit Complaint'),
                ),
              ],
            );
          },
        );
      },
    );

    complaintController.dispose();
  }

  void _showMessage(
    BuildContext context,
    String message,
  ) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final VoidCallback onTap;

  const _BookingCard({
    required this.document,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> booking = document.data();

    final String serviceType =
        (booking['serviceType'] ?? 'Ride').toString();

    final String status =
        (booking['status'] ?? 'requested').toString();

    final String from =
        (booking['from'] ?? booking['pickup'] ?? '').toString();

    final String to =
        (booking['to'] ?? booking['drop'] ?? '').toString();

    final String bookingDate =
        (booking['bookingDate'] ?? '').toString();

    final String bookingTime =
        (booking['bookingTime'] ?? '').toString();

    final String driverName =
        (booking['driverName'] ?? '').toString();

    final String vehicleNumber =
        (booking['vehicleNumber'] ?? '').toString();

    final bool isCompleted =
        status.toLowerCase() == 'completed';

    final bool hasRating =
        booking['ratingSubmitted'] == true;

    final bool hasComplaint =
        booking['hasComplaint'] == true;

    return Card(
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    child: Icon(
                      _serviceIcon(serviceType),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _formatServiceName(serviceType),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _StatusChip(status: status),
                ],
              ),
              const SizedBox(height: 16),
              if (from.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.my_location,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(from),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (to.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(to),
                    ),
                  ],
                ),
              ],
              if (bookingDate.isNotEmpty ||
                  bookingTime.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        [
                          bookingDate,
                          bookingTime,
                        ]
                            .where((value) => value.isNotEmpty)
                            .join(' • '),
                      ),
                    ),
                  ],
                ),
              ],
              if (driverName.isNotEmpty ||
                  vehicleNumber.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.person,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        driverName.isEmpty
                            ? 'Driver assigned'
                            : driverName,
                      ),
                    ),
                  ],
                ),
                if (vehicleNumber.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.directions_car,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(vehicleNumber),
                    ],
                  ),
                ],
              ],
              if (isCompleted) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      hasRating
                          ? Icons.star
                          : Icons.star_border,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasRating
                            ? 'Rating submitted'
                            : 'Rate your trip',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (hasComplaint)
                      const Tooltip(
                        message: 'Complaint submitted',
                        child: Icon(
                          Icons.flag,
                          color: Colors.orange,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static IconData _serviceIcon(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'car':
        return Icons.directions_car;
      case 'bike':
        return Icons.two_wheeler;
      case 'auto':
        return Icons.electric_rickshaw;
      case 'travels':
        return Icons.directions_bus;
      case 'cargo':
        return Icons.local_shipping;
      case 'rental':
        return Icons.car_rental;
      case 'carpool':
        return Icons.group;
      default:
        return Icons.local_taxi;
    }
  }

  static String _formatServiceName(String value) {
    if (value.isEmpty) {
      return 'Ride';
    }

    return value[0].toUpperCase() +
        value.substring(1).toLowerCase();
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final String normalized =
        status.toLowerCase();

    String label;

    switch (normalized) {
      case 'requested':
        label = 'Requested';
        break;
      case 'accepted':
        label = 'Accepted';
        break;
      case 'driver_assigned':
        label = 'Driver Assigned';
        break;
      case 'started':
        label = 'Started';
        break;
      case 'completed':
        label = 'Completed';
        break;
      case 'rejected':
        label = 'Rejected';
        break;
      default:
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: _statusColor(normalized).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _statusColor(normalized),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'requested':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'driver_assigned':
        return Colors.deepPurple;
      case 'started':
        return Colors.teal;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _BookingDetails extends StatelessWidget {
  final Map<String, dynamic> booking;
  final String bookingDocumentId;
  final VoidCallback onRating;
  final VoidCallback onComplaint;

  const _BookingDetails({
    required this.booking,
    required this.bookingDocumentId,
    required this.onRating,
    required this.onComplaint,
  });

  @override
  Widget build(BuildContext context) {
    final String status =
        (booking['status'] ?? 'requested').toString();

    final bool isCompleted =
        status.toLowerCase() == 'completed';

    final bool canComplaint =
        status.toLowerCase() == 'completed' ||
        status.toLowerCase() == 'started' ||
        status.toLowerCase() == 'driver_assigned';

    final bool hasRating =
        booking['ratingSubmitted'] == true;

    final bool hasComplaint =
        booking['hasComplaint'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Booking Details',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        _DetailRow(
          label: 'Booking ID',
          value: booking['bookingId']?.toString() ??
              bookingDocumentId,
        ),
        _DetailRow(
          label: 'Service',
          value: booking['serviceType']?.toString() ?? 'Ride',
        ),
        _DetailRow(
          label: 'Status',
          value: status,
        ),
        if (booking['from'] != null)
          _DetailRow(
            label: 'From',
            value: booking['from'].toString(),
          ),
        if (booking['to'] != null)
          _DetailRow(
            label: 'To',
            value: booking['to'].toString(),
          ),
        if (booking['pickup'] != null)
          _DetailRow(
            label: 'Pickup',
            value: booking['pickup'].toString(),
          ),
        if (booking['bookingDate'] != null)
          _DetailRow(
            label: 'Date',
            value: booking['bookingDate'].toString(),
          ),
        if (booking['bookingTime'] != null)
          _DetailRow(
            label: 'Time',
            value: booking['bookingTime'].toString(),
          ),
        if (booking['driverName'] != null &&
            booking['driverName'].toString().isNotEmpty)
          _DetailRow(
            label: 'Driver',
            value: booking['driverName'].toString(),
          ),
        if (booking['vehicleNumber'] != null &&
            booking['vehicleNumber'].toString().isNotEmpty)
          _DetailRow(
            label: 'Vehicle',
            value: booking['vehicleNumber'].toString(),
          ),
        if (booking['rating'] != null)
          _DetailRow(
            label: 'Rating',
            value: '${booking['rating']} / 5',
          ),
        if (booking['feedback'] != null &&
            booking['feedback'].toString().isNotEmpty)
          _DetailRow(
            label: 'Feedback',
            value: booking['feedback'].toString(),
          ),
        const SizedBox(height: 16),
        _ProgressSection(status: status),
        const SizedBox(height: 20),
        if (isCompleted)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onRating,
              icon: Icon(
                hasRating
                    ? Icons.edit
                    : Icons.star,
              ),
              label: Text(
                hasRating
                    ? 'Update Rating & Feedback'
                    : 'Rate & Give Feedback',
              ),
            ),
          ),
        if (canComplaint) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onComplaint,
              icon: Icon(
                hasComplaint
                    ? Icons.flag
                    : Icons.report_problem_outlined,
              ),
              label: Text(
                hasComplaint
                    ? 'Complaint Submitted'
                    : 'Submit Complaint',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
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
}

class _ProgressSection extends StatelessWidget {
  final String status;

  const _ProgressSection({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> steps = [
      'requested',
      'accepted',
      'driver_assigned',
      'started',
      'completed',
    ];

    final String normalized =
        status.toLowerCase();

    if (normalized == 'rejected') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.cancel,
              color: Colors.red,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'This booking was rejected.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    int currentIndex = steps.indexOf(normalized);

    if (currentIndex < 0) {
      currentIndex = 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trip Progress',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(
          steps.length,
          (index) {
            final bool completed =
                index <= currentIndex;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Icon(
                      completed
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 22,
                      color: completed
                          ? Colors.green
                          : Colors.grey,
                    ),
                    if (index < steps.length - 1)
                      Container(
                        width: 2,
                        height: 24,
                        color: index < currentIndex
                            ? Colors.green
                            : Colors.grey.shade300,
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _stepLabel(steps[index]),
                    style: TextStyle(
                      fontWeight: completed
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: completed
                          ? Colors.black87
                          : Colors.grey,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _stepLabel(String value) {
    switch (value) {
      case 'requested':
        return 'Booking Requested';
      case 'accepted':
        return 'Booking Accepted';
      case 'driver_assigned':
        return 'Driver Assigned';
      case 'started':
        return 'Trip Started';
      case 'completed':
        return 'Trip Completed';
      default:
        return value;
    }
  }
}