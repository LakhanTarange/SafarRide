import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VehicleVerificationPage extends StatefulWidget {
  const VehicleVerificationPage({super.key});

  @override
  State<VehicleVerificationPage> createState() =>
      _VehicleVerificationPageState();
}

class _VehicleVerificationPageState extends State<VehicleVerificationPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _approveVehicle(String vehicleId) async {
    try {
      await _firestore.collection('vehicles').doc(vehicleId).update({
        'status': 'active',
        'verificationStatus': 'verified',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showMessage('Vehicle approved. It is now bookable.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Unable to approve: $error');
    }
  }

  Future<void> _rejectVehicle(String vehicleId) async {
    final TextEditingController reasonController = TextEditingController();

    final String? reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reject Vehicle'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Rejection Reason',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final String value = reasonController.text.trim();
                Navigator.pop(
                  dialogContext,
                  value.isEmpty ? 'Documents not valid' : value,
                );
              },
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (reason == null) return;

    try {
      await _firestore.collection('vehicles').doc(vehicleId).update({
        'status': 'rejected',
        'verificationStatus': 'rejected',
        'rejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showMessage('Vehicle rejected.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Unable to reject: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _vehicleCard(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? {};

    final String number = data['vehicleNumber']?.toString() ?? '-';
    final String type = data['vehicleType']?.toString() ?? '-';
    final String brand = data['brand']?.toString() ?? '-';
    final String model = data['model']?.toString() ?? '-';
    final String year = data['year']?.toString() ?? '-';
    final String fuel = data['fuelType']?.toString() ?? '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              number,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text('$type • $brand $model • $year • $fuel'),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectVehicle(document.id),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _approveVehicle(document.id),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Verification')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('vehicles')
            .where('status', isEqualTo: 'pending_verification')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('No vehicles pending verification.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) => _vehicleCard(docs[index]),
          );
        },
      ),
    );
  }
}
