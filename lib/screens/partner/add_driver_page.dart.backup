import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';

class AddDriverPage extends StatefulWidget {
  const AddDriverPage({super.key});

  @override
  State<AddDriverPage> createState() =>
      _AddDriverPageState();
}

class _AddDriverPageState
    extends State<AddDriverPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController =
      TextEditingController();

  final _phoneController =
      TextEditingController();

  final _emailController =
      TextEditingController();

  final _licenseController =
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

    final user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Please login again.',
        isError: true,
      );
      return;
    }

    if (_selectedVehicleId == null) {
      _showMessage(
        'Please select a vehicle.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final driverReference =
          _firestore.collection('drivers').doc();

      await driverReference.set({
        'driverId': driverReference.id,
        'ownerId': user.uid,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'licenseNumber':
            _licenseController.text
                .trim()
                .toUpperCase(),
        'vehicleId': _selectedVehicleId,
        'vehicleNumber': _selectedVehicleNumber,
        'status': 'pending_verification',
        'kycStatus': 'pending',
        'accountStatus': 'active',
        'rating': 0,
        'totalTrips': 0,
        'createdAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text(
              'Driver Added',
            ),
            content: const Text(
              'Driver registration was completed successfully. KYC verification is pending.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

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
                  padding: const EdgeInsets.all(16),
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
                                    Theme.of(context)
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
                              'Register a driver and assign a vehicle.',
                              style: TextStyle(
                                color:
                                    Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization:
                          TextCapitalization.words,
                      decoration:
                          const InputDecoration(
                        labelText: 'Driver Name',
                        prefixIcon:
                            Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Enter driver name';
                        }

                        if (value.trim().length < 2) {
                          return 'Enter a valid name';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType:
                          TextInputType.phone,
                      decoration:
                          const InputDecoration(
                        labelText: 'Mobile Number',
                        hintText: '10 digit mobile number',
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
                      controller: _emailController,
                      keyboardType:
                          TextInputType.emailAddress,
                      decoration:
                          const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon:
                            Icon(Icons.email),
                      ),
                      validator: (value) {
                        final email =
                            value?.trim() ?? '';

                        if (email.isEmpty) {
                          return 'Enter email address';
                        }

                        if (!RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(email)) {
                          return 'Enter a valid email address';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
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
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Enter driving license number';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Assign Vehicle',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                          return Text(
                            'Unable to load vehicles.',
                            style: TextStyle(
                              color: Colors.red.shade700,
                            ),
                          );
                        }

                        final vehicles =
                            snapshot.data?.docs ?? [];

                        if (vehicles.isEmpty) {
                          return Card(
                            child: Padding(
                              padding:
                                  const EdgeInsets.all(
                                      16),
                              child: Text(
                                'No vehicles found. Add a vehicle first.',
                                style: TextStyle(
                                  color: Colors
                                      .grey.shade700,
                                ),
                              ),
                            ),
                          );
                        }

                        return DropdownButtonFormField<
                            String>(
                          initialValue:
                              _selectedVehicleId,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Select Vehicle',
                            prefixIcon: Icon(
                              Icons.directions_car,
                            ),
                          ),
                          items: vehicles.map(
                            (document) {
                              final data =
                                  document.data();

                              final number =
                                  (data['vehicleNumber'] ??
                                          '-')
                                      .toString();

                              final type =
                                  (data['vehicleType'] ??
                                          'Vehicle')
                                      .toString();

                              final brand =
                                  (data['brand'] ?? '')
                                      .toString();

                              final model =
                                  (data['model'] ?? '')
                                      .toString();

                              return DropdownMenuItem<
                                  String>(
                                value: document.id,
                                child: Text(
                                  '$number • $type • $brand $model'
                                      .trim(),
                                  overflow:
                                      TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ).toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            final selected =
                                vehicles.firstWhere(
                              (document) =>
                                  document.id == value,
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
                          validator: (value) {
                            if (value == null ||
                                value.isEmpty) {
                              return 'Select a vehicle';
                            }

                            return null;
                          },
                        );
                      },
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
                      'Driver KYC verification will be completed separately.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}