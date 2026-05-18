import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return await getUser(cred.user!.uid);
  }

  Future<UserModel?> register({
    required String name,
    required String familya,
    required String email,
    required String password,
    String phone = '',
    String role = 'talaba',
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = cred.user!.uid;
    final user = UserModel(
      uid: uid,
      name: name,
      familya: familya,
      phone: phone,
      email: email,
      role: role,
      createdAt: DateTime.now(),
    );

    await _db.collection('foydalanuvchilar').doc(uid).set({
      ...user.toMap(),
      'yaratilgan': FieldValue.serverTimestamp(),
    });
    return user;
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('foydalanuvchilar').doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    data['uid'] = uid;
    return UserModel.fromMap(data);
  }

  Stream<UserModel?> userStream(String uid) {
    return _db.collection('foydalanuvchilar').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data()!;
      data['uid'] = uid;
      return UserModel.fromMap(data);
    });
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
