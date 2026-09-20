import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum Plan { free, pro }

class AuthRepository {
  AuthRepository(this.auth, this.firestore);
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  Stream<User?> get changes => auth.authStateChanges();
  Future<User?> login(String email, String password) async {
    final credential = await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user;
  }

  Future<User?> register(String email, String password) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user;
  }

  Future<void> ensureProfile(String uid) async {
    final ref = firestore.doc('users/$uid');
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) transaction.set(ref, {'plan': 'free'});
    });
  }

  Stream<Plan> plan(String uid) => firestore
      .doc('users/$uid')
      .snapshots()
      .map((doc) => doc.data()?['plan'] == 'pro' ? Plan.pro : Plan.free);
  Future<void> logout() => auth.signOut();
}
