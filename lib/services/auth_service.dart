import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserCredential> registerUser({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    final String cleanEmail = email.trim().toLowerCase();
    final String cleanName = name.trim();
    final String cleanPhone = phone.trim();

    final UserCredential credential =
        await _auth.createUserWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );

    final User? user = credential.user;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'registration-failed',
        message: 'User registration failed.',
      );
    }

    await user.updateDisplayName(cleanName);

    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': cleanName,
      'email': cleanEmail,
      'phone': cleanPhone,
      'role': role,
      'accountStatus': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (role == 'driver') {
      await _linkDriverProfile(
        uid: user.uid,
        email: cleanEmail,
      );
    }

    return credential;
  }

  Future<UserCredential> loginUser({
    required String email,
    required String password,
  }) async {
    final String cleanEmail = email.trim().toLowerCase();

    final UserCredential credential =
        await _auth.signInWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );

    final User? user = credential.user;

    if (user != null) {
      await _linkDriverProfile(
        uid: user.uid,
        email: cleanEmail,
      );
    }

    return credential;
  }

  Future<void> _linkDriverProfile({
    required String uid,
    required String email,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> driverQuery =
        await _firestore
            .collection('drivers')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

    if (driverQuery.docs.isEmpty) {
      return;
    }

    final DocumentSnapshot<Map<String, dynamic>> driverDoc =
        driverQuery.docs.first;

    final Map<String, dynamic> driverData =
        driverDoc.data() ?? <String, dynamic>{};

    final String? existingUid =
        driverData['uid'] as String?;

    if (existingUid == null || existingUid.isEmpty) {
      await driverDoc.reference.update({
        'uid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    if (existingUid == uid) {
      return;
    }
  }

  Future<void> resetPassword({
    required String email,
  }) async {
    await _auth.sendPasswordResetEmail(
      email: email.trim().toLowerCase(),
    );
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserProfile(
    String uid,
  ) async {
    return await _firestore.collection('users').doc(uid).get();
  }

  Future<void> updateUserProfile({
    required String uid,
    required String name,
    required String phone,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'name': name.trim(),
      'phone': phone.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  User? get currentUser => _auth.currentUser;
}