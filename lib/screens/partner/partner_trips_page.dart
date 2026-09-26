import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PartnerTripsPage extends StatefulWidget {
  const PartnerTripsPage({super.key});

  @override
  State<PartnerTripsPage> createState() => _PartnerTripsPageState();
}

class _PartnerTripsPageState extends State<PartnerTripsPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  late final TabController _tabController;

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection('bookings');

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 2,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _serviceName(String? serviceType) {
    switch (serviceType) {
      case 'car':
        return 'Car';
      case 'bike':
        return 'Bike';
      case 'auto':
        return 'Auto';
      case 'travels':
        return 'Travels';
      case 'cargo':
        return 'Cargo';
      case 'rental':
        return 'Rental';
      default:
        return 'Booking';
    }
  }

  IconData _serviceIcon(String? serviceType) {
    switch (serviceType) {
      case 'car':
        return Icons.directions_car;
      case 'bike':
        return Icons.two_wheeler;
      case 'auto':
        return Icons.local_taxi;
      case 'travels':
        return Icons.directions_bus;
      case 'cargo':
        return Icons.local_shipping;
      case 'rental':
        return Icons.car_rental;
      default:
        return Icons.receipt_long;
    }
  }

  Future<void> _acceptBooking(
    BuildContext context,
    String bookingId,
  ) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(context, 'Partner login required.');
      return;
    }

    try {
      await _bookings.doc(bookingId).update({
        'status': 'accepted',
        'partnerId': user.uid,
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;

      _showMessage(
        context,
        'Booking accepted successfully.',
      );
    } on FirebaseException catch (e) {
      if (!context.mounted) return;

      _showMessage(
        context,
        e.message ?? 'Unable to accept booking.',
      );
    }
  }

  Future<void> _rejectBooking(
    BuildContext context,
    String bookingId,
  ) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(context, 'Partner login required.');
      return;
    }

    final TextEditingController reasonController =
        TextEditingController();

    final String? reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reject Booking'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Enter rejection reason',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final String value =
                    reasonController.text.trim();

                Navigator.pop(
                  dialogContext,
                  value.isEmpty ? 'Not available' : value,
                );
              },
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    reasonController.dispose();

    if (reason == null) return;

    try {
      await _bookings.doc(bookingId).update({
        'status': 'rejected',
        'partnerId': user.uid,
        'rejectedBy': user.uid,
        'rejectionReason': reason,
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;

      _showMessage(
        context,
        'Booking rejected.',
      );
    } on FirebaseException catch (e) {
      if (!context.mounted) return;

      _showMessage(
        context,
        e.message ?? 'Unable to reject booking.',
      );
    }
  }

  Future<void> _assignDriver(
    BuildContext context,
    String bookingId,
  ) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(context, 'Partner login required.');
      return;
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _firestore
              .collection('drivers')
              .where('ownerId', isEqualTo: user.uid)
              .where('accountStatus', isEqualTo: 'active')
              .get();

      if (!context.mounted) return;

      final List<QueryDocumentSnapshot<Map<String, dynamic>>>
          drivers = snapshot.docs;

      if (drivers.isEmpty) {
        _showMessage(
          context,
          'No active drivers available. Add and activate a driver first.',
        );
        return;
      }

      final QueryDocumentSnapshot<Map<String, dynamic>>?
          selectedDriver =
          await showDialog<QueryDocumentSnapshot<Map<String, dynamic>>>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Assign Driver'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: drivers.length,
                separatorBuilder: (_, index) =>
                    const Divider(),
                itemBuilder: (context, index) {
                  final driver = drivers[index];
                  final data = driver.data();

                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    title: Text(
                      data['name']?.toString() ??
                          'Driver',
                    ),
                    subtitle: Text(
                      '${data['phone'] ?? '-'}\n'
                      'Vehicle: ${data['vehicleNumber'] ?? 'Not assigned'}',
                    ),
                    isThreeLine: true,
                    onTap: () {
                      Navigator.pop(
                        dialogContext,
                        driver,
                      );
                    },
                  );
                },
              ),
            ),
          );
        },
      );

      if (selectedDriver == null) return;

      final Map<String, dynamic> driverData =
          selectedDriver.data();

      final String driverId = selectedDriver.id;
      final String driverName =
          driverData['name']?.toString() ?? '';
      final String vehicleId =
          driverData['vehicleId']?.toString() ?? '';
      final String vehicleNumber =
          driverData['vehicleNumber']?.toString() ?? '';

      if (vehicleId.isEmpty) {
        if (!context.mounted) return;

        _showMessage(
          context,
          'Selected driver has no vehicle assigned.',
        );
        return;
      }

      await _bookings.doc(bookingId).update({
        'partnerId': user.uid,
        'driverId': driverId,
        'driverName': driverName,
        'vehicleId': vehicleId,
        'vehicleNumber': vehicleNumber,
        'status': 'driver_assigned',
        'driverAssignedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;

      _showMessage(
        context,
        'Driver assigned successfully.',
      );
    } on FirebaseException catch (e) {
      if (!context.mounted) return;

      _showMessage(
        context,
        e.message ?? 'Unable to assign driver.',
      );
    }
  }

  Future<void> _startTrip(
    BuildContext context,
    String bookingId,
  ) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(context, 'Partner login required.');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Start Trip'),
          content: const Text(
            'Are you sure you want to start this trip?',
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
              child: const Text('Start Trip'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _bookings.doc(bookingId).update({
        'status': 'started',
        'tripStartedBy': user.uid,
        'tripStartedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;

      _showMessage(
        context,
        'Trip started successfully.',
      );
    } on FirebaseException catch (e) {
      if (!context.mounted) return;

      _showMessage(
        context,
        e.message ?? 'Unable to start trip.',
      );
    }
  }

  Future<void> _completeTrip(
    BuildContext context,
    String bookingId,
  ) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(context, 'Partner login required.');
      return;
    }

    final TextEditingController fareController = TextEditingController();
    String paymentMethod = 'cash';

    final Map<String, dynamic>? result =
        await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Complete Trip'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter the final fare collected for this trip.',
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: fareController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Fare Amount',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Payment Method',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Cash'),
                      value: 'cash',
                      groupValue: paymentMethod,
                      onChanged: (value) {
                        setDialogState(() {
                          paymentMethod = value ?? 'cash';
                        });
                      },
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Online / UPI'),
                      value: 'online',
                      groupValue: paymentMethod,
                      onChanged: (value) {
                        setDialogState(() {
                          paymentMethod = value ?? 'cash';
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final double? fare =
                        double.tryParse(fareController.text.trim());

                    if (fare == null || fare <= 0) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a valid fare amount.'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(dialogContext, {
                      'fare': fare,
                      'paymentMethod': paymentMethod,
                    });
                  },
                  child: const Text('Complete'),
                ),
              ],
            );
          },
        );
      },
    );

    fareController.dispose();

    if (result == null) return;

    if (!context.mounted) return;

    try {
      await _bookings.doc(bookingId).update({
        'status': 'completed',
        'completedBy': user.uid,
        'completedAt': FieldValue.serverTimestamp(),
        'fare': result['fare'],
        'paymentStatus': 'collected',
        'paymentMethod': result['paymentMethod'],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;

      _showMessage(
        context,
        'Trip completed successfully.',
      );
    } on FirebaseException catch (e) {
      if (!context.mounted) return;

      _showMessage(
        context,
        e.message ?? 'Unable to complete trip.',
      );
    }
  }

  void _showDetails(
    BuildContext context,
    String bookingId,
    Map<String, dynamic> data,
  ) {
    final String serviceType =
        data['serviceType']?.toString() ?? '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              30,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trip Details',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 20),
                _DetailRow(
                  label: 'Booking ID',
                  value: bookingId,
                ),
                _DetailRow(
                  label: 'Service',
                  value: _serviceName(serviceType),
                ),
                _DetailRow(
                  label: 'Status',
                  value: data['status']?.toString() ?? '-',
                ),
                _DetailRow(
                  label: 'Vehicle',
                  value: data['vehicleType']?.toString() ??
                      data['vehicleNumber']?.toString() ??
                      '-',
                ),
                _DetailRow(
                  label: 'Driver',
                  value:
                      data['driverName']?.toString() ?? '-',
                ),
                _DetailRow(
                  label: 'Driver ID',
                  value:
                      data['driverId']?.toString() ?? '-',
                ),
                _DetailRow(
                  label: 'From',
                  value: data['from']?.toString() ??
                      data['pickup']?.toString() ??
                      '-',
                ),
                _DetailRow(
                  label: 'To',
                  value: data['to']?.toString() ??
                      data['drop']?.toString() ??
                      '-',
                ),
                _DetailRow(
                  label: 'Date',
                  value: data['bookingDate']?.toString() ??
                      data['journeyDate']?.toString() ??
                      '-',
                ),
                _DetailRow(
                  label: 'Time',
                  value: data['bookingTime']?.toString() ??
                      data['journeyTime']?.toString() ??
                      '-',
                ),
                _DetailRow(
                  label: 'Passengers',
                  value:
                      data['passengers']?.toString() ?? '-',
                ),
                _DetailRow(
                  label: 'Weight',
                  value: data['weight']?.toString() ??
                      data['cargoWeight']?.toString() ??
                      '-',
                ),
                _DetailRow(
                  label: 'Duration',
                  value:
                      data['rentalDuration']?.toString() ??
                          '-',
                ),
                _DetailRow(
                  label: 'Fare',
                  value: data['fare']?.toString() ?? '0',
                ),
                _DetailRow(
                  label: 'Payment',
                  value:
                      data['paymentStatus']?.toString() ??
                          'pending',
                ),
                _DetailRow(
                  label: 'Notes',
                  value:
                      data['notes']?.toString() ?? '-',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessage(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>
      _requestedBookingsStream() {
    return _bookings
        .where(
          'status',
          isEqualTo: 'requested',
        )
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>
      _acceptedBookingsStream() {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Stream<
          QuerySnapshot<Map<String, dynamic>>>.empty();
    }

    return _bookings
        .where(
          'partnerId',
          isEqualTo: user.uid,
        )
        .where(
          'status',
          whereIn: [
            'accepted',
            'driver_assigned',
            'started',
          ],
        )
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                icon: Icon(Icons.notifications_active_outlined),
                text: 'Requests',
              ),
              Tab(
                icon: Icon(Icons.route_outlined),
                text: 'My Trips',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildRequestedBookings(),
              _buildAcceptedBookings(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequestedBookings() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _requestedBookingsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorView(
            'Unable to load booking requests.\n\n'
            '${snapshot.error}',
          );
        }

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>>
            documents = snapshot.data?.docs ?? [];

        if (documents.isEmpty) {
          return _emptyView(
            icon: Icons.receipt_long_outlined,
            title: 'No Requested Trips',
            message:
                'New customer booking requests will appear here.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            24,
          ),
          itemCount: documents.length,
          separatorBuilder: (_, index) =>
              const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _buildRequestedCard(
              documents[index],
            );
          },
        );
      },
    );
  }

  Widget _buildAcceptedBookings() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _acceptedBookingsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorView(
            'Unable to load your trips.\n\n'
            '${snapshot.error}',
          );
        }

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>>
            documents = snapshot.data?.docs ?? [];

        if (documents.isEmpty) {
          return _emptyView(
            icon: Icons.route_outlined,
            title: 'No Active Trips',
            message:
                'Accepted trips will appear here.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            24,
          ),
          itemCount: documents.length,
          separatorBuilder: (_, index) =>
              const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _buildAcceptedCard(
              documents[index],
            );
          },
        );
      },
    );
  }

  Widget _buildRequestedCard(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data =
        document.data();

    final String bookingId =
        data['bookingId']?.toString() ?? document.id;

    final String serviceType =
        data['serviceType']?.toString() ?? '';

    final String from =
        data['from']?.toString() ??
            data['pickup']?.toString() ??
            '-';

    final String to =
        data['to']?.toString() ??
            data['drop']?.toString() ??
            '-';

    final String date =
        data['bookingDate']?.toString() ??
            data['journeyDate']?.toString() ??
            '-';

    final String time =
        data['bookingTime']?.toString() ??
            data['journeyTime']?.toString() ??
            '-';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeader(
              serviceType,
              bookingId,
              'REQUESTED',
            ),
            const SizedBox(height: 16),
            _buildLocationInfo(
              from,
              to,
              date,
              time,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _showDetails(
                        context,
                        bookingId,
                        data,
                      );
                    },
                    child: const Text('Details'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _rejectBooking(
                        context,
                        bookingId,
                      );
                    },
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      _acceptBooking(
                        context,
                        bookingId,
                      );
                    },
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptedCard(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data =
        document.data();

    final String bookingId =
        data['bookingId']?.toString() ?? document.id;

    final String serviceType =
        data['serviceType']?.toString() ?? '';

    final String status =
        data['status']?.toString() ?? 'accepted';

    final String from =
        data['from']?.toString() ??
            data['pickup']?.toString() ??
            '-';

    final String to =
        data['to']?.toString() ??
            data['drop']?.toString() ??
            '-';

    final String date =
        data['bookingDate']?.toString() ??
            data['journeyDate']?.toString() ??
            '-';

    final String time =
        data['bookingTime']?.toString() ??
            data['journeyTime']?.toString() ??
            '-';

    final String driverName =
        data['driverName']?.toString() ?? '';

    final String vehicleNumber =
        data['vehicleNumber']?.toString() ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeader(
              serviceType,
              bookingId,
              _statusLabel(status),
            ),
            const SizedBox(height: 16),
            _buildLocationInfo(
              from,
              to,
              date,
              time,
            ),
            const SizedBox(height: 14),
            if (driverName.isNotEmpty ||
                vehicleNumber.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.06),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            driverName.isEmpty
                                ? 'Driver'
                                : driverName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            vehicleNumber.isEmpty
                                ? 'Vehicle assigned'
                                : vehicleNumber,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            _buildTripActionButtons(
              bookingId,
              status,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  _showDetails(
                    context,
                    bookingId,
                    data,
                  );
                },
                child: const Text('View Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripActionButtons(
    String bookingId,
    String status,
  ) {
    if (status == 'accepted') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () {
            _assignDriver(
              context,
              bookingId,
            );
          },
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Assign Driver'),
        ),
      );
    }

    if (status == 'driver_assigned') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () {
            _startTrip(
              context,
              bookingId,
            );
          },
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start Trip'),
        ),
      );
    }

    if (status == 'started') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () {
            _completeTrip(
              context,
              bookingId,
            );
          },
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Complete Trip'),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildHeader(
    String serviceType,
    String bookingId,
    String status,
  ) {
    return Row(
      children: [
        CircleAvatar(
          child: Icon(
            _serviceIcon(serviceType),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
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
                'Booking ID: $bookingId',
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
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.10),
          ),
          child: Text(
            status,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInfo(
    String from,
    String to,
    String date,
    String time,
  ) {
    return Column(
      children: [
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
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(date),
            ),
            const Icon(
              Icons.access_time,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(time),
          ],
        ),
      ],
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'ACCEPTED';
      case 'driver_assigned':
        return 'DRIVER ASSIGNED';
      case 'started':
        return 'STARTED';
      default:
        return status.toUpperCase();
    }
  }

  Widget _emptyView({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 70,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
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
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 19,
          color: Theme.of(context)
              .colorScheme
              .primary,
        ),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(value),
        ),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}