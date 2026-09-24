import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';

class DriverKycPage extends StatefulWidget {
  final String driverId;

  const DriverKycPage({
    super.key,
    required this.driverId,
  });

  @override
  State<DriverKycPage> createState() => _DriverKycPageState();
}

class _DriverKycPageState extends State<DriverKycPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _licenseController =
      TextEditingController();

  final TextEditingController _aadhaarController =
      TextEditingController();

  final TextEditingController _rcController =
      TextEditingController();

  final TextEditingController _insuranceController =
      TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  String _kycStatus = 'pending';
  String _driverName = 'Driver';

  @override
  void initState() {
    super.initState();
    _loadKycData();
  }

  @override
  void dispose() {
    _licenseController.dispose();
    _aadhaarController.dispose();
    _rcController.dispose();
    _insuranceController.dispose();
    super.dispose();
  }

  Future<void> _loadKycData() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> driverDocument =
          await _firestore
              .collection('drivers')
              .doc(widget.driverId)
              .get();

      if (!mounted) {
        return;
      }

      if (!driverDocument.exists) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final Map<String, dynamic> data =
          driverDocument.data() ?? <String, dynamic>{};

      final Map<String, dynamic> kycDocuments =
          data['kycDocuments'] is Map
              ? Map<String, dynamic>.from(
                  data['kycDocuments'] as Map,
                )
              : <String, dynamic>{};

      _licenseController.text =
          kycDocuments['drivingLicense']?.toString() ?? '';

      _aadhaarController.text =
          kycDocuments['aadhaar']?.toString() ?? '';

      _rcController.text =
          kycDocuments['rc']?.toString() ?? '';

      _insuranceController.text =
          kycDocuments['insurance']?.toString() ?? '';

      setState(() {
        _driverName =
            data['name']?.toString() ?? 'Driver';

        _kycStatus =
            data['kycStatus']?.toString() ?? 'pending';

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to load KYC data: $error',
          ),
        ),
      );
    }
  }

  Future<void> _saveKyc() async {
    final String license =
        _licenseController.text.trim().toUpperCase();

    final String aadhaar =
        _aadhaarController.text.trim();

    final String rc =
        _rcController.text.trim().toUpperCase();

    final String insurance =
        _insuranceController.text.trim().toUpperCase();

    if (license.isEmpty ||
        aadhaar.isEmpty ||
        rc.isEmpty ||
        insurance.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter all KYC document details.',
          ),
        ),
      );
      return;
    }

    if (aadhaar.length != 12 ||
        int.tryParse(aadhaar) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid 12-digit Aadhaar number.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _firestore
          .collection('drivers')
          .doc(widget.driverId)
          .update({
        'kycDocuments': {
          'drivingLicense': license,
          'aadhaar': aadhaar,
          'rc': rc,
          'insurance': insurance,
        },
        'kycStatus': 'submitted',
        'kycRejectionReason': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _kycStatus = 'submitted';
        _isSaving = false;
      });

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('KYC Submitted'),
            content: const Text(
              'Driver KYC details have been submitted successfully.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to save KYC: $error',
          ),
        ),
      );
    }
  }

  Future<void> _verifyKyc() async {
    try {
      await _firestore
          .collection('drivers')
          .doc(widget.driverId)
          .update({
        'kycStatus': 'verified',
        'kycRejectionReason': '',
        'accountStatus': 'active',
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _kycStatus = 'verified';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Driver KYC verified successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to verify KYC: $error',
          ),
        ),
      );
    }
  }

  Future<void> _rejectKyc() async {
    final TextEditingController reasonController =
        TextEditingController();

    final String? reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reject KYC'),
          content: TextField(
            controller: reasonController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Rejection Reason',
              hintText: 'Enter reason for rejection',
              alignLabelWithHint: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final String value =
                    reasonController.text.trim();

                if (value.isEmpty) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  value,
                );
              },
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    reasonController.dispose();

    if (reason == null || reason.isEmpty) {
      return;
    }

    try {
      await _firestore
          .collection('drivers')
          .doc(widget.driverId)
          .update({
        'kycStatus': 'rejected',
        'kycRejectionReason': reason,
        'accountStatus': 'inactive',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _kycStatus = 'rejected';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Driver KYC rejected.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to reject KYC: $error',
          ),
        ),
      );
    }
  }

  Color _statusColor() {
    switch (_kycStatus.toLowerCase()) {
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

  String _statusText() {
    switch (_kycStatus.toLowerCase()) {
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

  Widget _statusChip() {
    final Color color = _statusColor();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusText(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _documentField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Driver KYC'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver KYC'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      child: Icon(
                        Icons.person,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            _driverName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Driver KYC Verification',
                            style: TextStyle(
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _statusChip(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'KYC Documents',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Enter the driver document details below.',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 18),

            _documentField(
              controller: _licenseController,
              label: 'Driving License Number',
              hint: 'Enter driving license number',
              icon: Icons.credit_card_outlined,
            ),

            _documentField(
              controller: _aadhaarController,
              label: 'Aadhaar Number',
              hint: 'Enter 12-digit Aadhaar number',
              icon: Icons.badge_outlined,
              keyboardType: TextInputType.number,
            ),

            _documentField(
              controller: _rcController,
              label: 'Vehicle RC Number',
              hint: 'Enter RC number',
              icon: Icons.directions_car_outlined,
            ),

            _documentField(
              controller: _insuranceController,
              label: 'Vehicle Insurance Number',
              hint: 'Enter insurance number',
              icon: Icons.security_outlined,
            ),

            const SizedBox(height: 4),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveKyc,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.send_outlined,
                      ),
                label: Text(
                  _isSaving
                      ? 'Submitting...'
                      : 'Submit KYC',
                ),
              ),
            ),

            const SizedBox(height: 12),

            if (_kycStatus == 'submitted')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _verifyKyc,
                      icon: const Icon(
                        Icons.verified_outlined,
                      ),
                      label: const Text(
                        'Verify',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _rejectKyc,
                      icon: const Icon(
                        Icons.cancel_outlined,
                      ),
                      label: const Text(
                        'Reject',
                      ),
                    ),
                  ),
                ],
              ),

            if (_kycStatus == 'rejected') ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(
                    alpha: 0.06,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.withValues(
                      alpha: 0.2,
                    ),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.red,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'KYC was rejected. Correct the document details and submit again.',
                        style: TextStyle(
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(
                  alpha: 0.05,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue.withValues(
                    alpha: 0.15,
                  ),
                ),
              ),
              child: const Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'KYC document files are not uploaded in the current Firebase plan. Only document details and verification status are stored.',
                      style: TextStyle(
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            Center(
              child: Text(
                '${AppConfig.appName} • ${AppConfig.companyName}',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}