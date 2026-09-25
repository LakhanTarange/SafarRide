import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';

class AddDriverPage extends StatefulWidget {
  const AddDriverPage({super.key});

  @override
  State<AddDriverPage> createState() => _AddDriverPageState();
}

class _AddDriverPageState extends State<AddDriverPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController =
      TextEditingController();

  final TextEditingController _phoneController =
      TextEditingController();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _licenseController =
      TextEditingController();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  String? _selectedVehicleId;
  String? _selectedVehicleNumber;

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _saveDriver() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Please login again.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final DocumentReference<Map<String, dynamic>>
          driverReference =
          _firestore.collection('drivers').doc();

      final String driverId = driverReference.id;

      await driverReference.set({
        'driverId': driverId,
        'ownerId': user.uid,

        // Driver personal details
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),

        // Licence details
        'licenseNumber': _licenseController.text
            .trim()
            .toUpperCase(),

        // Vehicle assignment
        'vehicleId': _selectedVehicleId,
        'vehicleNumber': _selectedVehicleNumber,

        // Verification
        'status': 'pending_verification',
        'kycStatus': 'pending',

        // Account management
        'accountStatus': 'active',

        // Driver availability
        'isAvailable': false,

        // GPS fields - future use
        'latitude': null,
        'longitude': null,
        'locationUpdatedAt': null,

        // Driver statistics
        'rating': 0,
        'totalTrips': 0,
        'completedTrips': 0,

        // Future KYC fields
        'licenseVerified': false,
        'identityVerified': false,
        'kycVerifiedAt': null,

        // Timestamps
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // If vehicle was selected, update vehicle too.
      if (_selectedVehicleId != null &&
          _selectedVehicleId!.isNotEmpty) {
        final QuerySnapshot<
                Map<String, dynamic>> vehicleSnapshot =
            await _firestore
                .collection('vehicles')
                .where(
                  'ownerId',
                  isEqualTo: user.uid,
                )
                .where(
                  'vehicleId',
                  isEqualTo: _selectedVehicleId,
                )
                .limit(1)
                .get();

        if (vehicleSnapshot.docs.isNotEmpty) {
          final DocumentReference<
                  Map<String, dynamic>>
              vehicleReference =
              vehicleSnapshot.docs.first.reference;

          await vehicleReference.update({
            'driverId': driverId,
            'driverDocumentId': driverId,
            'driverName':
                _nameController.text.trim(),
            'driverPhone':
                _phoneController.text.trim(),
            'driverKycStatus': 'pending',
            'isAvailable': false,
            'updatedAt':
                FieldValue.serverTimestamp(),
          });
        }
      }

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Driver Added',
            ),
            content: Text(
              _selectedVehicleId == null
                  ? 'Driver has been registered successfully. Vehicle can be assigned later.'
                  : 'Driver has been registered and assigned to the selected vehicle. KYC verification is pending.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Done'),
              ),
            ],
          );
        },
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        _showMessage(
          error.message ??
              'Unable to register driver.',
          isError: true,
        );
      }
    } catch (error) {
      if (mounted) {
        _showMessage(
          'Unable to register driver: $error',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red : null,
      ),
    );
  }

  Widget _sectionTitle(
    String title,
    String subtitle,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 8,
        bottom: 10,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Driver',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: user == null
          ? const Center(
              child: Text(
                'Please login again.',
              ),
            )
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding:
                      const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppConfig.appName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    FontWeight.bold,
                                color:
                                    Theme.of(
                                      context,
                                    )
                                        .colorScheme
                                        .primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Driver Registration',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Add and manage your driver without creating a separate driver login.',
                              style: TextStyle(
                                color:
                                    Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    _sectionTitle(
                      'Driver Details',
                      'Enter the driver personal information.',
                    ),

                    TextFormField(
                      controller:
                          _nameController,
                      textCapitalization:
                          TextCapitalization.words,
                      decoration:
                          const InputDecoration(
                        labelText: 'Driver Name',
                        prefixIcon:
                            Icon(Icons.person),
                      ),
                      validator: (value) {
                        final name =
                            value?.trim() ?? '';

                        if (name.isEmpty) {
                          return 'Enter driver name';
                        }

                        if (name.length < 2) {
                          return 'Enter a valid name';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    TextFormField(
                      controller:
                          _phoneController,
                      keyboardType:
                          TextInputType.phone,
                      decoration:
                          const InputDecoration(
                        labelText: 'Mobile Number',
                        hintText:
                            '10 digit mobile number',
                        prefixIcon:
                            Icon(Icons.phone),
                      ),
                      validator: (value) {
                        final phone =
                            value?.trim() ?? '';

                        if (phone.isEmpty) {
                          return 'Enter mobile number';
                        }

                        if (!RegExp(
                          r'^[0-9]{10}$',
                        ).hasMatch(phone)) {
                          return 'Enter a valid 10 digit mobile number';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    TextFormField(
                      controller:
                          _emailController,
                      keyboardType:
                          TextInputType.emailAddress,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Email Address',
                        hintText:
                            'driver@example.com',
                        prefixIcon:
                            Icon(Icons.email),
                      ),
                      validator: (value) {
                        final email =
                            value?.trim() ?? '';

                        if (email.isEmpty) {
                          return null;
                        }

                        if (!RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(email)) {
                          return 'Enter a valid email address';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    _sectionTitle(
                      'Driving Licence',
                      'Enter the driver licence number.',
                    ),

                    TextFormField(
                      controller:
                          _licenseController,
                      textCapitalization:
                          TextCapitalization.characters,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Driving License Number',
                        hintText:
                            'Enter license number',
                        prefixIcon:
                            Icon(Icons.badge),
                      ),
                      validator: (value) {
                        final license =
                            value?.trim() ?? '';

                        if (license.isEmpty) {
                          return 'Enter driving license number';
                        }

                        if (license.length < 5) {
                          return 'Enter a valid license number';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    _sectionTitle(
                      'Vehicle Assignment',
                      'Vehicle assignment is optional. You can assign it later.',
                    ),

                    StreamBuilder<
                        QuerySnapshot<
                            Map<String, dynamic>>>(
                      stream: _firestore
                          .collection('vehicles')
                          .where(
                            'ownerId',
                            isEqualTo: user.uid,
                          )
                          .snapshots(),
                      builder:
                          (context, snapshot) {
                        if (snapshot
                                .connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding:
                                EdgeInsets.all(16),
                            child: Center(
                              child:
                                  CircularProgressIndicator(),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return Card(
                            child: Padding(
                              padding:
                                  const EdgeInsets.all(
                                      16),
                              child: Text(
                                'Unable to load vehicles.\n${snapshot.error}',
                                style: TextStyle(
                                  color: Colors
                                      .red.shade700,
                                ),
                              ),
                            ),
                          );
                        }

                        final vehicles =
                            snapshot.data?.docs ??
                                [];

                        if (vehicles.isEmpty) {
                          return Card(
                            child: Padding(
                              padding:
                                  const EdgeInsets.all(
                                      16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons
                                        .directions_car_outlined,
                                    color: Colors
                                        .grey.shade600,
                                  ),
                                  const SizedBox(
                                      width: 10),
                                  Expanded(
                                    child: Text(
                                      'No vehicles found. You can add a vehicle first or register the driver and assign a vehicle later.',
                                      style: TextStyle(
                                        color: Colors
                                            .grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: [
                            DropdownButtonFormField<
                                String>(
                              initialValue:
                                  _selectedVehicleId,
                              decoration:
                                  const InputDecoration(
                                labelText:
                                    'Select Vehicle',
                                prefixIcon:
                                    Icon(
                                  Icons
                                      .directions_car,
                                ),
                              ),
                              items:
                                  vehicles.map(
                                (document) {
                                  final data =
                                      document
                                          .data();

                                  final number =
                                      (data[
                                                  'vehicleNumber'] ??
                                              '-')
                                          .toString();

                                  final type =
                                      (data[
                                                  'vehicleType'] ??
                                              'Vehicle')
                                          .toString();

                                  final brand =
                                      (data[
                                                  'brand'] ??
                                              '')
                                          .toString();

                                  final model =
                                      (data[
                                                  'model'] ??
                                              '')
                                          .toString();

                                  final details =
                                      '$number • $type • $brand $model'
                                          .trim();

                                  return DropdownMenuItem<
                                      String>(
                                    value:
                                        document.id,
                                    child: SizedBox(
                                      width:
                                          MediaQuery.of(
                                            context,
                                          ).size.width -
                                              100,
                                      child: Text(
                                        details,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                      ),
                                    ),
                                  );
                                },
                              ).toList(),
                              onChanged:
                                  (value) {
                                if (value ==
                                    null) {
                                  return;
                                }

                                final selected =
                                    vehicles.firstWhere(
                                  (document) =>
                                      document.id ==
                                      value,
                                );

                                final data =
                                    selected.data();

                                setState(() {
                                  _selectedVehicleId =
                                      value;
                                  _selectedVehicleNumber =
                                      (data[
                                                  'vehicleNumber'] ??
                                              '-')
                                          .toString();
                                });
                              },
                            ),

                            if (_selectedVehicleId !=
                                null) ...[
                              const SizedBox(
                                  height: 8),
                              Align(
                                alignment:
                                    Alignment
                                        .centerRight,
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _selectedVehicleId =
                                          null;
                                      _selectedVehicleNumber =
                                          null;
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.close,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Clear Vehicle',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    Card(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.35),
                      child: const Padding(
                        padding:
                            EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Driver will not get a separate login. The partner/owner manages the driver, vehicle assignment, availability and KYC from this app.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _isSaving
                            ? null
                            : _saveDriver,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.person_add,
                              ),
                        label: Text(
                          _isSaving
                              ? 'Saving...'
                              : 'Register Driver',
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'KYC verification will be completed separately.',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}