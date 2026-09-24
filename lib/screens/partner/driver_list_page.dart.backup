import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import 'add_driver_page.dart';
import 'driver_kyc_page.dart';

class DriverListPage extends StatefulWidget {
  const DriverListPage({super.key});

  @override
  State<DriverListPage> createState() => _DriverListPageState();
}

class _DriverListPageState extends State<DriverListPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _openAddDriverPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddDriverPage(),
      ),
    );
  }

  Future<void> _openKycPage(String driverId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverKycPage(
          driverId: driverId,
        ),
      ),
    );
  }

  Future<void> _assignVehicle({
    required String driverId,
    required String driverName,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return;
    }

    final QuerySnapshot<Map<String, dynamic>> vehicleSnapshot =
        await _firestore
            .collection('vehicles')
            .where(
              'ownerId',
              isEqualTo: user.uid,
            )
            .get();

    if (!mounted) {
      return;
    }

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> vehicles =
        vehicleSnapshot.docs;

    if (vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No vehicles available. Please add a vehicle first.',
          ),
        ),
      );
      return;
    }

    String? selectedVehicleId;

    final String? result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Assign Vehicle'),
              content: DropdownButtonFormField<String>(
                initialValue: selectedVehicleId,
                decoration: const InputDecoration(
                  labelText: 'Select Vehicle',
                  prefixIcon: Icon(
                    Icons.directions_car_outlined,
                  ),
                ),
                items: vehicles.map((vehicle) {
                  final Map<String, dynamic> data =
                      vehicle.data();

                  final String vehicleId =
                      data['vehicleId']?.toString() ?? vehicle.id;

                  final String vehicleNumber =
                      data['vehicleNumber']?.toString() ?? '-';

                  final String vehicleType =
                      data['vehicleType']?.toString() ?? '';

                  final String displayText =
                      vehicleType.isEmpty
                          ? vehicleNumber
                          : '$vehicleNumber - $vehicleType';

                  return DropdownMenuItem<String>(
                    value: vehicleId,
                    child: Text(displayText),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedVehicleId = value;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selectedVehicleId == null
                      ? null
                      : () {
                          Navigator.pop(
                            dialogContext,
                            selectedVehicleId,
                          );
                        },
                  child: const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || result.isEmpty) {
      return;
    }

    final QuerySnapshot<Map<String, dynamic>> selectedVehicleSnapshot =
        await _firestore
            .collection('vehicles')
            .where(
              'vehicleId',
              isEqualTo: result,
            )
            .where(
              'ownerId',
              isEqualTo: user.uid,
            )
            .limit(1)
            .get();

    if (selectedVehicleSnapshot.docs.isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected vehicle was not found.'),
        ),
      );
      return;
    }

    final DocumentSnapshot<Map<String, dynamic>> vehicleDocument =
        selectedVehicleSnapshot.docs.first;

    final Map<String, dynamic> vehicleData =
        vehicleDocument.data() ?? <String, dynamic>{};

    final String vehicleId =
        vehicleData['vehicleId']?.toString() ??
            vehicleDocument.id;

    final String vehicleNumber =
        vehicleData['vehicleNumber']?.toString() ?? '-';

    final String previousDriverId =
        vehicleData['driverId']?.toString() ?? '';

    final WriteBatch batch = _firestore.batch();

    final DocumentReference<Map<String, dynamic>> driverReference =
        _firestore.collection('drivers').doc(driverId);

    final DocumentReference<Map<String, dynamic>> vehicleReference =
        vehicleDocument.reference;

    if (previousDriverId.isNotEmpty &&
        previousDriverId != driverId) {
      final DocumentReference<Map<String, dynamic>>
          previousDriverReference =
          _firestore
              .collection('drivers')
              .doc(previousDriverId);

      batch.update(previousDriverReference, {
        'vehicleId': null,
        'vehicleNumber': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    batch.update(driverReference, {
      'vehicleId': vehicleId,
      'vehicleNumber': vehicleNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(vehicleReference, {
      'driverId': driverId,
      'driverName': driverName,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$vehicleNumber assigned to $driverName.',
        ),
      ),
    );
  }

  Future<void> _removeVehicle({
    required String driverId,
    required String vehicleId,
  }) async {
    final WriteBatch batch = _firestore.batch();

    final DocumentReference<Map<String, dynamic>> driverReference =
        _firestore.collection('drivers').doc(driverId);

    final DocumentReference<Map<String, dynamic>> vehicleReference =
        _firestore.collection('vehicles').doc(vehicleId);

    batch.update(driverReference, {
      'vehicleId': null,
      'vehicleNumber': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(vehicleReference, {
      'driverId': null,
      'driverName': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vehicle removed from driver.'),
      ),
    );
  }

  Future<void> _showVehicleOptions({
    required String driverId,
    required String driverName,
    required String? vehicleId,
    required String? vehicleNumber,
  }) async {
    if (vehicleId == null || vehicleId.isEmpty) {
      await _assignVehicle(
        driverId: driverId,
        driverName: driverName,
      );
      return;
    }

    final String? action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.directions_car),
                ),
                title: Text(
                  vehicleNumber ?? 'Assigned Vehicle',
                ),
                subtitle: Text(
                  'Currently assigned to $driverName',
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.swap_horiz,
                ),
                title: const Text('Change Vehicle'),
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                    'change',
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.remove_circle_outline,
                ),
                title: const Text('Remove Vehicle'),
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                    'remove',
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (action == 'change') {
      await _assignVehicle(
        driverId: driverId,
        driverName: driverName,
      );
    }

    if (action == 'remove') {
      await _removeVehicle(
        driverId: driverId,
        vehicleId: vehicleId,
      );
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'pending_verification':
        return Colors.orange;
      case 'suspended':
        return Colors.red;
      case 'inactive':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  Color _kycColor(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return Colors.green;
      case 'submitted':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _kycText(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return 'Verified';
      case 'submitted':
        return 'Submitted';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  Widget _statusChip({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 85,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
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

  Widget _driverCard(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data =
        document.data() ?? <String, dynamic>{};

    final String driverId =
        data['driverId']?.toString() ?? document.id;

    final String name =
        data['name']?.toString() ?? 'Unknown Driver';

    final String phone =
        data['phone']?.toString() ?? '-';

    final String email =
        data['email']?.toString() ?? '-';

    final String licenseNumber =
        data['licenseNumber']?.toString() ?? '-';

    final String status =
        data['status']?.toString() ??
            'pending_verification';

    final String kycStatus =
        data['kycStatus']?.toString() ?? 'pending';

    final String? vehicleId =
        data['vehicleId']?.toString();

    final String? vehicleNumber =
        data['vehicleNumber']?.toString();

    final num rating =
        data['rating'] is num
            ? data['rating'] as num
            : 0;

    final num totalTrips =
        data['totalTrips'] is num
            ? data['totalTrips'] as num
            : 0;

    final bool hasVehicle =
        vehicleId != null &&
        vehicleId.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 26,
                  child: Icon(
                    Icons.person,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        phone,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusChip(
                  label: status.replaceAll(
                    '_',
                    ' ',
                  ),
                  color: _statusColor(status),
                ),
              ],
            ),

            const SizedBox(height: 16),

            const Divider(),

            const SizedBox(height: 8),

            _infoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: email,
            ),

            _infoRow(
              icon: Icons.credit_card_outlined,
              label: 'License',
              value: licenseNumber,
            ),

            _infoRow(
              icon: Icons.star_outline,
              label: 'Rating',
              value: rating.toStringAsFixed(1),
            ),

            _infoRow(
              icon: Icons.route_outlined,
              label: 'Total Trips',
              value: totalTrips.toString(),
            ),

            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: hasVehicle
                    ? Colors.green.withValues(
                        alpha: 0.07,
                      )
                    : Colors.orange.withValues(
                        alpha: 0.07,
                      ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasVehicle
                        ? Icons.directions_car
                        : Icons.directions_car_outlined,
                    color: hasVehicle
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasVehicle
                              ? 'Assigned Vehicle'
                              : 'No Vehicle Assigned',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (hasVehicle) ...[
                          const SizedBox(height: 3),
                          Text(
                            vehicleNumber ?? '-',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  _showVehicleOptions(
                    driverId: driverId,
                    driverName: name,
                    vehicleId: vehicleId,
                    vehicleNumber: vehicleNumber,
                  );
                },
                icon: Icon(
                  hasVehicle
                      ? Icons.manage_accounts
                      : Icons.directions_car,
                ),
                label: Text(
                  hasVehicle
                      ? 'Manage Vehicle'
                      : 'Assign Vehicle',
                ),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                const Text(
                  'KYC Status: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _statusChip(
                  label: _kycText(kycStatus),
                  color: _kycColor(kycStatus),
                ),
              ],
            ),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _openKycPage(driverId);
                },
                icon: const Icon(
                  Icons.verified_user_outlined,
                ),
                label: Text(
                  kycStatus.toLowerCase() == 'verified'
                      ? 'View KYC'
                      : 'Manage KYC',
                ),
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
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 72,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Drivers Added',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first driver to start '
              'managing your fleet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _openAddDriverPage,
              icon: const Icon(
                Icons.person_add,
              ),
              label: const Text(
                'Add Driver',
              ),
            ),
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
        appBar: AppBar(
          title: const Text('Drivers'),
        ),
        body: const Center(
          child: Text(
            'Please login to view drivers.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drivers'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('drivers')
            .where(
              'ownerId',
              isEqualTo: user.uid,
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load drivers.\n\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final List<
                  DocumentSnapshot<Map<String, dynamic>>>
              drivers =
              snapshot.data?.docs ??
                  <DocumentSnapshot<
                      Map<String, dynamic>>>[];

          if (drivers.isEmpty) {
            return _emptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              return _driverCard(
                drivers[index],
              );
            },
          );
        },
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: _openAddDriverPage,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Driver'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            bottom: 4,
          ),
          child: Text(
            '${AppConfig.appName} • '
            '${AppConfig.companyName}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}