import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ComplaintHistoryPage extends StatelessWidget {
  const ComplaintHistoryPage({super.key});

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Color _statusColor(String status) {
    switch (status) {
      case 'verified':
        return Colors.red;
      case 'dismissed':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _historyCard(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? {};

    final String category = data['category']?.toString() ?? '-';
    final String complaint = data['complaint']?.toString() ?? '-';
    final String driverName = data['driverName']?.toString() ?? '-';
    final String vehicleNumber = data['vehicleNumber']?.toString() ?? '-';
    final String status = data['status']?.toString() ?? '-';
    final int? strikeApplied = (data['strikeApplied'] as num?)?.toInt();

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 10),
            Text(complaint),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 17),
                const SizedBox(width: 8),
                Text('Driver: $driverName'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.directions_car_outlined, size: 17),
                const SizedBox(width: 8),
                Text('Vehicle: $vehicleNumber'),
              ],
            ),
            if (strikeApplied != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.warning_amber_outlined, size: 17),
                  const SizedBox(width: 8),
                  Text('Strike applied: #$strikeApplied'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complaint History')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('complaints')
            .where('status', whereIn: ['verified', 'dismissed'])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Unable to load history.\n${snapshot.error}'),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          final sorted = [...docs]..sort((a, b) {
            final ta = a.data()['verifiedAt'] as Timestamp?;
            final tb = b.data()['verifiedAt'] as Timestamp?;
            if (ta == null || tb == null) return 0;
            return tb.compareTo(ta);
          });

          if (sorted.isEmpty) {
            return const Center(
              child: Text('No complaint history yet.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            itemBuilder: (context, index) => _historyCard(sorted[index]),
          );
        },
      ),
    );
  }
}
