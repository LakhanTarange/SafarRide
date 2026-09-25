import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';

class AddVehiclePage extends StatefulWidget {
  const AddVehiclePage({super.key});

  @override
  State<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends State<AddVehiclePage> {
  final _formKey = GlobalKey<FormState>();

  final _vehicleNumberController = TextEditingController();
  final _vehicleBrandController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _seatingController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _vehicleType = 'Car';
  String _fuelType = 'Petrol';

  bool _rideSharingEnabled = false;
  bool _carpoolEnabled = false;
  bool _rentalEnabled = false;
  bool _selfDriveRentalEnabled = false;

  bool _isSaving = false;

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _vehicleBrandController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _seatingController.dispose();
    super.dispose();
  }

  Future<void> _saveVehicle() async {
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

    if (_selfDriveRentalEnabled && !_rentalEnabled) {
      _showMessage(
        'Self-drive rental requires Rental to be enabled.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final DocumentReference<Map<String, dynamic>> vehicleReference =
          _firestore.collection('vehicles').doc();

      final int year =
          int.parse(_vehicleYearController.text.trim());

      final int seats =
          int.parse(_seatingController.text.trim());

      await vehicleReference.set({
        'vehicleId': vehicleReference.id,
        'ownerId': user.uid,

        'vehicleNumber':
            _vehicleNumberController.text.trim().toUpperCase(),

        'vehicleType': _vehicleType,

        'serviceType': _vehicleType.toLowerCase(),

        'brand':
            _vehicleBrandController.text.trim(),

        'model':
            _vehicleModelController.text.trim(),

        'year': year,

        'fuelType': _fuelType,

        'seatingCapacity': seats,

        // Driver will be assigned later by the owner.
        'driverId': null,
        'driverDocumentId': null,
        'driverName': null,

        // Vehicle verification.
        'status': 'pending_verification',
        'verificationStatus': 'pending',

        // Availability.
        'isAvailable': false,

        // Service configuration.
        'rideSharingEnabled': _rideSharingEnabled,
        'carpoolEnabled': _carpoolEnabled,
        'rentalEnabled': _rentalEnabled,
        'selfDriveRentalEnabled': _selfDriveRentalEnabled,

        // Location fields.
        'latitude': null,
        'longitude': null,
        'locationUpdatedAt': null,

        // Pricing will be configured separately.
        'pricingConfigured': false,

        // Route will be configured separately.
        'routeConfigured': false,

        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Vehicle Added'),
            content: const Text(
              'Vehicle details have been submitted successfully. '
              'The vehicle will remain unavailable until verification '
              'and driver assignment are completed.',
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
          error.message ?? 'Unable to save vehicle.',
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
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  Widget _serviceSwitch({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: SwitchListTile(
        secondary: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Vehicle',
          style: TextStyle(
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
                        'Register your vehicle and select the services '
                        'you want to provide.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              DropdownButtonFormField<String>(
                initialValue: _vehicleType,
                decoration: const InputDecoration(
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
                    child: Text('Tempo / Cargo'),
                  ),
                  DropdownMenuItem(
                    value: 'Travels',
                    child: Text('Travels / Bus'),
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
                controller: _vehicleNumberController,
                textCapitalization:
                    TextCapitalization.characters,
                decoration: const InputDecoration(
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
                controller: _vehicleBrandController,
                decoration: const InputDecoration(
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
                controller: _vehicleModelController,
                decoration: const InputDecoration(
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
                controller: _vehicleYearController,
                keyboardType:
                    TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Manufacturing Year',
                  hintText: 'Example: 2024',
                  prefixIcon:
                      Icon(Icons.calendar_today),
                ),
                validator: (value) {
                  final int? year =
                      int.tryParse(
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
                decoration: const InputDecoration(
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
                decoration: const InputDecoration(
                  labelText: 'Seating Capacity',
                  hintText: 'Example: 5',
                  prefixIcon:
                      Icon(Icons.event_seat),
                ),
                validator: (value) {
                  final int? seats =
                      int.tryParse(
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

              const Text(
                'Services',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Select the services this vehicle can provide.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 12),

              _serviceSwitch(
                title: 'Ride Sharing',
                subtitle:
                    'Allow passengers to book seats on your route.',
                icon: Icons.people_alt_outlined,
                value: _rideSharingEnabled,
                onChanged: (value) {
                  setState(() {
                    _rideSharingEnabled = value;
                  });
                },
              ),

              _serviceSwitch(
                title: 'Carpool',
                subtitle:
                    'Allow shared travel with passengers.',
                icon: Icons.groups_outlined,
                value: _carpoolEnabled,
                onChanged: (value) {
                  setState(() {
                    _carpoolEnabled = value;
                  });
                },
              ),

              _serviceSwitch(
                title: 'Rental',
                subtitle:
                    'Allow this vehicle to be offered for rental.',
                icon: Icons.car_rental_outlined,
                value: _rentalEnabled,
                onChanged: (value) {
                  setState(() {
                    _rentalEnabled = value;

                    if (!value) {
                      _selfDriveRentalEnabled = false;
                    }
                  });
                },
              ),

              if (_vehicleType == 'Bike' ||
                  _vehicleType == 'Car')
                _serviceSwitch(
                  title: 'Self-Drive Rental',
                  subtitle:
                      'Allow verified customers to rent this vehicle without a driver.',
                  icon: Icons.key_outlined,
                  value: _selfDriveRentalEnabled,
                  onChanged: _rentalEnabled
                      ? (value) {
                          setState(() {
                            _selfDriveRentalEnabled =
                                value;
                          });
                        }
                      : (_) {
                          _showMessage(
                            'Enable Rental first.',
                            isError: true,
                          );
                        },
                ),

              const SizedBox(height: 20),

              Container(
                padding:
                    const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(14),
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.06),
                ),
                child: const Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'After registration, the vehicle remains '
                        'unavailable until verification is completed. '
                        'A driver can be assigned later from Vehicle Management.',
                      ),
                    ),
                  ],
                ),
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
                      : const Icon(Icons.save),
                  label: Text(
                    _isSaving
                        ? 'Saving...'
                        : 'Register Vehicle',
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Vehicle verification and approval will be handled before customer visibility.',
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