import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  String? get currentCustomerId {
    return _auth.currentUser?.uid;
  }

  Future<String> createCarBooking({
    required String customerId,
    required String pickup,
    required String destination,
    required String carType,
    required String bookingDate,
    required String bookingTime,
  }) async {
    final bookingReference =
        _firestore.collection('bookings').doc();

    await bookingReference.set({
      'bookingId': bookingReference.id,
      'customerId': customerId,
      'serviceType': 'car',
      'pickup': pickup,
      'destination': destination,
      'vehicleType': carType,
      'bookingDate': bookingDate,
      'bookingTime': bookingTime,
      'status': 'requested',
      'paymentStatus': 'pending',
      'driverId': null,
      'partnerId': null,
      'fare': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return bookingReference.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getCustomerBookings(
    String customerId,
  ) {
    return _firestore
        .collection('bookings')
        .where(
          'customerId',
          isEqualTo: customerId,
        )
        .snapshots();
  }
}