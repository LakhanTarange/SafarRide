import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';

class AddVehiclePage extends StatefulWidget {
  const AddVehiclePage({super.key});

  @override
  State<AddVehiclePage> createState() =>
      _AddVehiclePageState();
}

class _AddVehiclePageState
    extends State<AddVehiclePage> {
  final _formKey = GlobalKey<FormState>();

  final _vehicleNumberController =
      TextEditingController();

  final _vehicleModelController =
      TextEditingController();

  final _vehicleBrandController =
      TextEditingController();

  final _vehicleYearController =
      TextEditingController();

  final _seatingController =
      TextEditingController();

  String _vehicleType = 'Car';
  String _fuelType = 'Petrol';
  bool _isSaving = false;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _vehicleModelController.dispose();
    _vehicleBrandController.dispose();
    _vehicleYearController.dispose();
    _seatingController.dispose();
    super.dispose();
  }

  Future<void> _saveVehicle() async {
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

    setState(() {
      _isSaving = true;
    });

    try {
      final vehicleReference =
          _firestore.collection('vehicles').doc();

      await vehicleReference.set({
        'vehicleId': vehicleReference.id,
        'ownerId': user.uid,
        'vehicleNumber':
            _vehicleNumberController.text
                .trim()
                .toUpperCase(),
        'vehicleType': _vehicleType,
        'brand':
            _vehicleBrandController.text.trim(),
        'model':
            _vehicleModelController.text.trim(),
        'year':
            int.parse(
              _vehicleYearController.text.trim(),
            ),
        'fuelType': _fuelType,
        'seatingCapacity':
            int.parse(
              _seatingController.text.trim(),
            ),
        'status': 'pending_verification',
        'driverId': null,
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
              'Vehicle Added',
            ),
            content: const Text(
              'Vehicle details have been submitted successfully. Verification is pending.',
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
              'Unable to save vehicle.',
          isError: true,
        );
      }
    } catch (error) {
      if (mounted) {
        _showMessage(
          'Unable to save vehicle: $error',
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add Vehicle',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConfig.appName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .colorScheme
                              .primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Vehicle Registration',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add your vehicle details to start offering services.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _vehicleType,
                decoration:
                    const InputDecoration(
                  labelText: 'Vehicle Type',
                  prefixIcon:
                      Icon(Icons.directions_car),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Car',
                    child: Text('Car'),
                  ),
                  DropdownMenuItem(
                    value: 'Bike',
                    child: Text('Bike'),
                  ),
                  DropdownMenuItem(
                    value: 'Auto',
                    child: Text('Auto'),
                  ),
                  DropdownMenuItem(
                    value: 'Tempo',
                    child: Text('Tempo'),
                  ),
                  DropdownMenuItem(
                    value: 'Travels',
                    child: Text('Travels'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _vehicleType = value;
                  });
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller:
                    _vehicleNumberController,
                textCapitalization:
                    TextCapitalization.characters,
                decoration:
                    const InputDecoration(
                  labelText: 'Vehicle Number',
                  hintText: 'MH12AB1234',
                  prefixIcon:
                      Icon(Icons.confirmation_number),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Enter vehicle number';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller:
                    _vehicleBrandController,
                decoration:
                    const InputDecoration(
                  labelText: 'Vehicle Brand',
                  hintText: 'Example: Tata',
                  prefixIcon:
                      Icon(Icons.business),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Enter vehicle brand';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller:
                    _vehicleModelController,
                decoration:
                    const InputDecoration(
                  labelText: 'Vehicle Model',
                  hintText: 'Example: Nexon',
                  prefixIcon:
                      Icon(Icons.directions_car),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Enter vehicle model';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller:
                    _vehicleYearController,
                keyboardType:
                    TextInputType.number,
                decoration:
                    const InputDecoration(
                  labelText: 'Manufacturing Year',
                  hintText: 'Example: 2024',
                  prefixIcon:
                      Icon(Icons.calendar_today),
                ),
                validator: (value) {
                  final year = int.tryParse(
                    value?.trim() ?? '',
                  );

                  if (year == null) {
                    return 'Enter a valid year';
                  }

                  if (year < 1980 ||
                      year > DateTime.now().year) {
                    return 'Enter a valid manufacturing year';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _fuelType,
                decoration:
                    const InputDecoration(
                  labelText: 'Fuel Type',
                  prefixIcon:
                      Icon(Icons.local_gas_station),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Petrol',
                    child: Text('Petrol'),
                  ),
                  DropdownMenuItem(
                    value: 'Diesel',
                    child: Text('Diesel'),
                  ),
                  DropdownMenuItem(
                    value: 'CNG',
                    child: Text('CNG'),
                  ),
                  DropdownMenuItem(
                    value: 'Electric',
                    child: Text('Electric'),
                  ),
                  DropdownMenuItem(
                    value: 'Hybrid',
                    child: Text('Hybrid'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _fuelType = value;
                  });
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _seatingController,
                keyboardType:
                    TextInputType.number,
                decoration:
                    const InputDecoration(
                  labelText: 'Seating Capacity',
                  hintText: 'Example: 5',
                  prefixIcon:
                      Icon(Icons.event_seat),
                ),
                validator: (value) {
                  final seats = int.tryParse(
                    value?.trim() ?? '',
                  );

                  if (seats == null ||
                      seats < 1 ||
                      seats > 100) {
                    return 'Enter valid seating capacity';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed:
                      _isSaving ? null : _saveVehicle,
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
                          Icons.save,
                        ),
                  label: Text(
                    _isSaving
                        ? 'Saving...'
                        : 'Register Vehicle',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Vehicle status will remain pending until verification is completed.',
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