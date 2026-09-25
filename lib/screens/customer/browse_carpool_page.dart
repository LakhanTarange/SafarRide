import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BrowseCarpoolPage extends StatefulWidget {
  const BrowseCarpoolPage({super.key});

  @override
  State<BrowseCarpoolPage> createState() => _BrowseCarpoolPageState();
}

class _BrowseCarpoolPageState extends State<BrowseCarpoolPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _joinCarpool(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please login again.');
      return;
    }

    final data = document.data() ?? {};

    if (data['ownerId'] == user.uid) {
      _showMessage('You cannot join your own carpool.');
      return;
    }

    final List<dynamic> existingPassengers =
        (data['passengers'] as List<dynamic>?) ?? [];

    final bool alreadyJoined = existingPassengers.any(
      (p) => (p as Map<String, dynamic>)['customerId'] == user.uid,
    );

    if (alreadyJoined) {
      _showMessage('You have already joined this carpool.');
      return;
    }

    final TextEditingController seatController =
        TextEditingController(text: '1');

    final int? seatsToBook = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Join Carpool'),
          content: TextField(
            controller: seatController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Number of Seats',
              prefixIcon: Icon(Icons.event_seat_outlined),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final int? seats = int.tryParse(
                  seatController.text.trim(),
                );
                Navigator.pop(dialogContext, seats);
              },
              child: const Text('Join'),
            ),
          ],
        );
      },
    );

    if (seatsToBook == null || seatsToBook < 1) return;

    try {
      await _firestore.runTransaction((transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> freshDoc =
            await transaction.get(document.reference);

        final Map<String, dynamic> freshData = freshDoc.data() ?? {};

        final int availableSeats =
            (freshData['availableSeats'] as num?)?.toInt() ?? 0;
        final int bookedSeats =
            (freshData['bookedSeats'] as num?)?.toInt() ?? 0;

        final int remaining = availableSeats - bookedSeats;

        if (remaining < seatsToBook) {
          throw Exception('Only $remaining seat(s) left.');
        }

        final List<dynamic> passengers =
            (freshData['passengers'] as List<dynamic>?) ?? [];

        passengers.add({
          'customerId': user.uid,
          'customerName': user.displayName ?? '',
          'customerEmail': user.email ?? '',
          'customerPhone': user.phoneNumber ?? '',
          'seatsBooked': seatsToBook,
          'status': 'joined',
          'joinedAt': Timestamp.now(),
        });

        transaction.update(document.reference, {
          'bookedSeats': bookedSeats + seatsToBook,
          'passengers': passengers,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.check_circle,
              size: 56,
              color: Colors.green,
            ),
            title: const Text('Seat Joined'),
            content: const Text(
              'You have successfully joined this carpool. '
              'Contact the owner for pickup coordination.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _carpoolCard(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    final String from = data['from']?.toString() ?? '-';
    final String to = data['to']?.toString() ?? '-';
    final String date = data['journeyDate']?.toString() ?? '-';
    final String time = data['journeyTime']?.toString() ?? '-';
    final String vehicleType = data['vehicleType']?.toString() ?? '-';
    final String ownerName = data['ownerName']?.toString() ?? 'Owner';
    final num fuelCost = data['fuelCostSharing'] ?? 0;
    final int availableSeats =
        (data['availableSeats'] as num?)?.toInt() ?? 0;
    final int bookedSeats = (data['bookedSeats'] as num?)?.toInt() ?? 0;
    final int remaining = availableSeats - bookedSeats;

    final User? user = _auth.currentUser;
    final bool isOwner = data['ownerId'] == user?.uid;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$from → $to',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: remaining > 0
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    remaining > 0 ? '$remaining seats left' : 'Full',
                    style: TextStyle(
                      color: remaining > 0 ? Colors.green : Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'By $ownerName • $vehicleType',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text('$date • $time'),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.currency_rupee,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text('₹${fuelCost.toStringAsFixed(0)} fuel share'),
              ],
            ),
            if ((data['notes']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                data['notes'].toString(),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (isOwner)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.blue.withValues(alpha: 0.06),
                ),
                child: const Text(
                  'This is your carpool posting.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: remaining > 0
                      ? () => _joinCarpool(document)
                      : null,
                  icon: const Icon(Icons.group_add_outlined),
                  label: Text(remaining > 0 ? 'Join Carpool' : 'Full'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.groups_outlined,
              size: 72,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Carpools Available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later or post your own journey.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Carpools'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('carpools')
            .where('status', isEqualTo: 'active')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load carpools.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          final sorted = [...docs]..sort((a, b) {
            final ta = a.data()['createdAt'] as Timestamp?;
            final tb = b.data()['createdAt'] as Timestamp?;
            if (ta == null || tb == null) return 0;
            return tb.compareTo(ta);
          });

          if (sorted.isEmpty) return _emptyState();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            itemBuilder: (context, index) => _carpoolCard(sorted[index]),
          );
        },
      ),
    );
  }
}