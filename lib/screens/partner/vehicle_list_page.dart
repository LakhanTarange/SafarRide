import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import 'add_vehicle_page.dart';

class VehicleListPage extends StatefulWidget {
  const VehicleListPage({super.key});

  @override
  State<VehicleListPage> createState() => _VehicleListPageState();
}

class _VehicleListPageState extends State<VehicleListPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _openAddVehiclePage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddVehiclePage()),
    );
  }

  Future<void> _assignDriver({
    required String vehicleId,
    required String vehicleNumber,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> driverSnapshot =
          await _firestore
              .collection('drivers')
              .where('ownerId', isEqualTo: user.uid)
              .where('accountStatus', isEqualTo: 'active')
              .get();

      if (!mounted) {
        return;
      }

      final List<QueryDocumentSnapshot<Map<String, dynamic>>> drivers =
          driverSnapshot.docs;

      if (drivers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No active drivers available. Please add and activate a driver first.',
            ),
          ),
        );
        return;
      }

      String? selectedDriverDocumentId;

      final String? result = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Assign Driver'),
                content: DropdownButtonFormField<String>(
                  initialValue: selectedDriverDocumentId,
                  decoration: const InputDecoration(
                    labelText: 'Select Driver',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: drivers.map((driver) {
                    final Map<String, dynamic> data = driver.data();

                    final String name =
                        data['name']?.toString() ?? 'Unknown Driver';

                    final String phone = data['phone']?.toString() ?? '';

                    final String linkedUid = data['uid']?.toString() ?? '';

                    final bool isLinked = linkedUid.isNotEmpty;

                    return DropdownMenuItem<String>(
                      value: driver.id,
                      child: Text(
                        phone.isEmpty
                            ? isLinked
                                  ? name
                                  : '$name (Not Linked)'
                            : isLinked
                            ? '$name - $phone'
                            : '$name - $phone (Not Linked)',
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedDriverDocumentId = value;
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
                    onPressed: selectedDriverDocumentId == null
                        ? null
                        : () {
                            Navigator.pop(
                              dialogContext,
                              selectedDriverDocumentId,
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

      final DocumentSnapshot<Map<String, dynamic>> driverDocument =
          await _firestore.collection('drivers').doc(result).get();

      if (!driverDocument.exists) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected driver was not found.')),
        );
        return;
      }

      final Map<String, dynamic> driverData =
          driverDocument.data() ?? <String, dynamic>{};

      final String driverUid = driverData['uid']?.toString() ?? '';

      if (driverUid.isEmpty) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This driver has not logged in yet. Ask the driver to create/login to their account first.',
            ),
          ),
        );
        return;
      }

      final String driverName = driverData['name']?.toString() ?? 'Driver';

      final bool driverAvailable = driverData['isAvailable'] == true;

      final String driverStatus =
          driverData['accountStatus']?.toString() ?? 'active';

      if (driverStatus != 'active') {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected driver account is not active.'),
          ),
        );
        return;
      }

      final WriteBatch batch = _firestore.batch();

      final DocumentReference<Map<String, dynamic>> vehicleReference =
          _firestore.collection('vehicles').doc(vehicleId);

      final DocumentReference<Map<String, dynamic>> driverReference =
          driverDocument.reference;

      batch.update(vehicleReference, {
        'driverId': driverUid,
        'driverDocumentId': driverDocument.id,
        'driverName': driverName,
        'isAvailable': driverAvailable,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.update(driverReference, {
        'vehicleId': vehicleId,
        'vehicleNumber': vehicleNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            driverAvailable
                ? '$driverName assigned to $vehicleNumber. Vehicle is available.'
                : '$driverName assigned to $vehicleNumber. Driver is currently offline.',
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Unable to assign driver.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to assign driver.')));
    }
  }

  Future<void> _removeDriver({
    required String vehicleId,
    required String driverId,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> driverSnapshot =
          await _firestore
              .collection('drivers')
              .where('ownerId', isEqualTo: user.uid)
              .where('uid', isEqualTo: driverId)
              .limit(1)
              .get();

      final WriteBatch batch = _firestore.batch();

      final DocumentReference<Map<String, dynamic>> vehicleReference =
          _firestore.collection('vehicles').doc(vehicleId);

      batch.update(vehicleReference, {
        'driverId': null,
        'driverDocumentId': null,
        'driverName': null,
        'isAvailable': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (driverSnapshot.docs.isNotEmpty) {
        final DocumentReference<Map<String, dynamic>> driverReference =
            driverSnapshot.docs.first.reference;

        batch.update(driverReference, {
          'vehicleId': null,
          'vehicleNumber': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Driver removed from vehicle. Vehicle is now unavailable.',
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Unable to remove driver.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to remove driver.')));
    }
  }

  Future<void> _showVehicleOptions({
    required String vehicleId,
    required String vehicleNumber,
    required String? driverId,
    required String? driverName,
  }) async {
    if (driverId == null || driverId.isEmpty) {
      await _assignDriver(vehicleId: vehicleId, vehicleNumber: vehicleNumber);
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
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(driverName ?? 'Assigned Driver'),
                subtitle: Text('Currently assigned to $vehicleNumber'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('Change Driver'),
                onTap: () {
                  Navigator.pop(sheetContext, 'change');
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_remove_outlined),
                title: const Text('Remove Driver'),
                onTap: () {
                  Navigator.pop(sheetContext, 'remove');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (action == 'change') {
      await _assignDriver(vehicleId: vehicleId, vehicleNumber: vehicleNumber);
    }

    if (action == 'remove') {
      await _removeDriver(vehicleId: vehicleId, driverId: driverId);
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'verified':
        return Colors.green;
      case 'pending_verification':
        return Colors.orange;
      case 'inactive':
        return Colors.grey;
      case 'suspended':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _statusChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _availabilityCard(Map<String, dynamic> data) {
    final bool isAvailable = data['isAvailable'] == true;

    final String driverId = data['driverId']?.toString() ?? '';

    final bool hasDriver = driverId.isNotEmpty;

    final bool vehicleActive =
        (data['status']?.toString().toLowerCase() ?? '') == 'active';

    final bool customerVisible = vehicleActive && hasDriver && isAvailable;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: customerVisible
            ? Colors.green.withValues(alpha: 0.08)
            : Colors.grey.withValues(alpha: 0.08),
        border: Border.all(
          color: customerVisible
              ? Colors.green.withValues(alpha: 0.25)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            customerVisible ? Icons.visibility : Icons.visibility_off,
            color: customerVisible ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customerVisible
                      ? 'Visible to Customers'
                      : 'Not Visible to Customers',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  !vehicleActive
                      ? 'Vehicle verification is pending.'
                      : !hasDriver
                      ? 'Assign a driver first.'
                      : !isAvailable
                      ? 'Driver is currently unavailable.'
                      : 'Customer can book this vehicle.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vehicleCard(DocumentSnapshot<Map<String, dynamic>> document) {
    final Map<String, dynamic> data = document.data() ?? <String, dynamic>{};

    final String vehicleId = data['vehicleId']?.toString() ?? document.id;

    final String vehicleNumber = data['vehicleNumber']?.toString() ?? '-';

    final String vehicleType = data['vehicleType']?.toString() ?? '-';

    final String brand = data['brand']?.toString() ?? '-';

    final String model = data['model']?.toString() ?? '-';

    final String year = data['year']?.toString() ?? '-';

    final String fuelType = data['fuelType']?.toString() ?? '-';

    final String seatingCapacity = data['seatingCapacity']?.toString() ?? '-';

    final String status = data['status']?.toString() ?? 'pending_verification';

    final String? driverId = data['driverId']?.toString();

    final String? driverName = data['driverName']?.toString();

    final bool hasDriver = driverId != null && driverId.isNotEmpty;

    final bool isAvailable = data['isAvailable'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 27,
                  child: Icon(_vehicleIcon(vehicleType), size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicleNumber,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$brand $model',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                _statusChip(
                  label: status.replaceAll('_', ' '),
                  color: _statusColor(status),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            _infoRow(
              icon: Icons.category_outlined,
              label: 'Vehicle Type',
              value: vehicleType,
            ),

            _infoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Year',
              value: year,
            ),

            _infoRow(
              icon: Icons.local_gas_station_outlined,
              label: 'Fuel',
              value: fuelType,
            ),

            _infoRow(
              icon: Icons.event_seat_outlined,
              label: 'Seats',
              value: seatingCapacity,
            ),

            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: hasDriver
                    ? Colors.green.withValues(alpha: 0.07)
                    : Colors.orange.withValues(alpha: 0.07),
              ),
              child: Row(
                children: [
                  Icon(
                    hasDriver ? Icons.person : Icons.person_outline,
                    color: hasDriver ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasDriver ? 'Assigned Driver' : 'No Driver Assigned',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (hasDriver) ...[
                          const SizedBox(height: 3),
                          Text(
                            driverName ?? 'Driver',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isAvailable
                                ? 'Driver Available'
                                : 'Driver Unavailable',
                            style: TextStyle(
                              color: isAvailable ? Colors.green : Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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

            _availabilityCard(data),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  _showVehicleOptions(
                    vehicleId: vehicleId,
                    vehicleNumber: vehicleNumber,
                    driverId: driverId,
                    driverName: driverName,
                  );
                },
                icon: Icon(
                  hasDriver ? Icons.manage_accounts : Icons.person_add,
                ),
                label: Text(hasDriver ? 'Manage Driver' : 'Assign Driver'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _vehicleIcon(String vehicleType) {
    switch (vehicleType.toLowerCase()) {
      case 'car':
        return Icons.directions_car;
      case 'bike':
        return Icons.two_wheeler;
      case 'auto':
        return Icons.electric_rickshaw;
      case 'tempo':
        return Icons.local_shipping;
      case 'travels':
        return Icons.directions_bus;
      default:
        return Icons.directions_car;
    }
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 72,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Vehicles Added',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first vehicle to start managing your fleet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _openAddVehiclePage,
              icon: const Icon(Icons.add),
              label: const Text('Add Vehicle'),
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
        appBar: AppBar(title: const Text('Vehicles')),
        body: const Center(child: Text('Please login to view vehicles.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Vehicles')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('vehicles')
            .where('ownerId', isEqualTo: user.uid)
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
                  'Unable to load vehicles.\n\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final List<DocumentSnapshot<Map<String, dynamic>>> vehicles =
              snapshot.data?.docs ?? <DocumentSnapshot<Map<String, dynamic>>>[];

          if (vehicles.isEmpty) {
            return _emptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              return _vehicleCard(vehicles[index]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddVehiclePage,
        icon: const Icon(Icons.add),
        label: const Text('Add Vehicle'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '${AppConfig.appName} • ${AppConfig.companyName}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
        ),
      ),
    );
  }
}
