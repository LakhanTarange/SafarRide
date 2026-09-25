import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyCarpoolsPage extends StatefulWidget {
  const MyCarpoolsPage({super.key});

  @override
  State<MyCarpoolsPage> createState() => _MyCarpoolsPageState();
}

class _MyCarpoolsPageState extends State<MyCarpoolsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _cancelCarpool(String carpoolId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Carpool'),
          content: const Text(
            'Are you sure you want to cancel this carpool posting?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _firestore.collection('carpools').doc(carpoolId).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Carpool cancelled.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to cancel: $error')),
      );
    }
  }

  Widget _passengerTile(Map<String, dynamic> passenger) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text(
        (passenger['customerName']?.toString().isNotEmpty ?? false)
            ? passenger['customerName'].toString()
            : 'Passenger',
      ),
      subtitle: Text(
        '${passenger['customerEmail'] ?? ''}\n'
        '${passenger['seatsBooked'] ?? 1} seat(s)',
      ),
      isThreeLine: true,
    );
  }

  Widget _carpoolCard(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? {};

    final String from = data['from']?.toString() ?? '-';
    final String to = data['to']?.toString() ?? '-';
    final String date = data['journeyDate']?.toString() ?? '-';
    final String status = data['status']?.toString() ?? 'active';
    final int availableSeats =
        (data['availableSeats'] as num?)?.toInt() ?? 0;
    final int bookedSeats = (data['bookedSeats'] as num?)?.toInt() ?? 0;
    final List<dynamic> passengers =
        (data['passengers'] as List<dynamic>?) ?? [];

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
                    color: status == 'active'
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: status == 'active'
                          ? Colors.green
                          : Colors.grey.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('$date • $bookedSeats / $availableSeats seats booked'),
            const SizedBox(height: 12),
            if (passengers.isEmpty)
              Text(
                'No passengers joined yet.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else ...[
              const Divider(),
              const Text(
                'Passengers',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...passengers.map(
                (p) => _passengerTile(p as Map<String, dynamic>),
              ),
            ],
            if (status == 'active') ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _cancelCarpool(document.id),
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  label: const Text(
                    'Cancel Carpool',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Carpools')),
        body: const Center(child: Text('Please login to view carpools.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Carpools')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('carpools')
            .where('ownerId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text('You have not posted any carpool yet.'),
            );
          }

          final sorted = [...docs]..sort((a, b) {
            final ta = a.data()['createdAt'] as Timestamp?;
            final tb = b.data()['createdAt'] as Timestamp?;
            if (ta == null || tb == null) return 0;
            return tb.compareTo(ta);
          });

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