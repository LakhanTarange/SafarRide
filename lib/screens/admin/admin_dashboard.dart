import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _dismissComplaint(String complaintId) async {
    final User? admin = _auth.currentUser;
    if (admin == null) return;

    try {
      await _firestore.collection('complaints').doc(complaintId).update({
        'status': 'dismissed',
        'verifiedBy': admin.uid,
        'verifiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showMessage('Complaint dismissed.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Unable to dismiss: $error');
    }
  }

  Future<void> _verifyComplaint(
    String complaintId,
    String? driverId,
  ) async {
    final User? admin = _auth.currentUser;
    if (admin == null) return;

    if (driverId == null || driverId.isEmpty) {
      _showMessage('No driver linked to this complaint.');
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Verify Complaint'),
          content: const Text(
            'This will add a strike to the driver. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Verify & Strike'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      String resultMessage = '';

      await _firestore.runTransaction((transaction) async {
        final DocumentReference<Map<String, dynamic>> driverRef =
            _firestore.collection('drivers').doc(driverId);

        final DocumentSnapshot<Map<String, dynamic>> driverSnap =
            await transaction.get(driverRef);

        if (!driverSnap.exists) {
          throw Exception('Driver not found.');
        }

        final Map<String, dynamic> driverData = driverSnap.data() ?? {};

        final int currentStrikes =
            (driverData['strikeCount'] as num?)?.toInt() ?? 0;

        final int newStrikes = currentStrikes + 1;

        String banStatus;
        String accountStatus;
        Timestamp? suspendedUntil;

        if (newStrikes == 1) {
          banStatus = 'warned';
          accountStatus = 'active';
          suspendedUntil = null;
          resultMessage = 'Strike 1: Driver warned.';
        } else if (newStrikes == 2) {
          banStatus = 'suspended';
          accountStatus = 'inactive';
          suspendedUntil = Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 15)),
          );
          resultMessage = 'Strike 2: Driver suspended for 15 days.';
        } else {
          banStatus = 'blacklisted';
          accountStatus = 'banned';
          suspendedUntil = null;
          resultMessage = 'Strike 3: Driver permanently blacklisted.';
        }

        transaction.update(driverRef, {
          'strikeCount': newStrikes,
          'banStatus': banStatus,
          'accountStatus': accountStatus,
          'suspendedUntil': suspendedUntil,
          'isAvailable': newStrikes >= 2 ? false : driverData['isAvailable'],
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final DocumentReference<Map<String, dynamic>> complaintRef =
            _firestore.collection('complaints').doc(complaintId);

        transaction.update(complaintRef, {
          'status': 'verified',
          'verifiedBy': admin.uid,
          'verifiedAt': FieldValue.serverTimestamp(),
          'strikeApplied': newStrikes,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      _showMessage(resultMessage);
    } catch (error) {
      if (!mounted) return;
      _showMessage('Unable to verify: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _complaintCard(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? {};

    final String category = data['category']?.toString() ?? '-';
    final String complaint = data['complaint']?.toString() ?? '-';
    final String driverName = data['driverName']?.toString() ?? '-';
    final String? driverId = data['driverId']?.toString();
    final String vehicleNumber = data['vehicleNumber']?.toString() ?? '-';
    final String serviceType = data['serviceType']?.toString() ?? '-';

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
                Text(
                  serviceType,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
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
            const SizedBox(height: 14),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: driverId != null && driverId.isNotEmpty
                  ? _firestore.collection('drivers').doc(driverId).snapshots()
                  : null,
              builder: (context, snapshot) {
                final int strikes = snapshot.hasData
                    ? ((snapshot.data!.data()?['strikeCount'] as num?)
                              ?.toInt() ??
                          0)
                    : 0;

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.red.withValues(alpha: 0.06),
                  ),
                  child: Text('Current strikes on this driver: $strikes'),
                );
              },
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _dismissComplaint(document.id),
                    child: const Text('Dismiss'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _verifyComplaint(document.id, driverId),
                    child: const Text('Verify & Strike'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _adminBody() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('complaints')
          .where('status', isEqualTo: 'open')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Unable to load complaints.\n${snapshot.error}'),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 70,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Pending Complaints',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) => _complaintCard(docs[index]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: const Center(child: Text('Please login again.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin • Complaints',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _firestore.collection('users').doc(user.uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final String role =
              snapshot.data?.data()?['role']?.toString() ?? '';

          if (role != 'admin') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 70,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Access Denied',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This section is only for admins.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return _adminBody();
        },
      ),
    );
  }
}
