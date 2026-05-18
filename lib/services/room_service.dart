import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_model.dart';

class RoomService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return List.generate(4, (_) => chars[r.nextInt(chars.length)]).join();
  }

  String _generateRoomId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    final r = DateTime.now().millisecondsSinceEpoch;
    final prefix = chars[r % chars.length];
    return '$prefix${(r % 10000).toString().padLeft(4, '0')}';
  }

  Future<RoomModel> createRoom({
    required String name,
    required String domlaId,
    String domlaName = '',
  }) async {
    final code = _generateCode();
    final now = DateTime.now();
    final expires = now.add(const Duration(hours: 4));
    final roomId = _generateRoomId();

    final room = RoomModel(
      id: roomId,
      name: name,
      domlaId: domlaId,
      domlaName: domlaName,
      code: code,
      codeExpires: expires,
      azolar: [domlaId],
      createdAt: now,
    );

    await _db.collection('guruhlar').doc(roomId).set({
      ...room.toMap(),
      'kodlar': [code],
      'yaratilgan': FieldValue.serverTimestamp(),
      'streamFaol': false,
    });
    return room;
  }

  Future<void> regenerateCode(String roomId) async {
    final code = _generateCode();
    final expires = DateTime.now().add(const Duration(hours: 4));
    await _db.collection('guruhlar').doc(roomId).update({
      'joriyKod': code,
      'code': code,
      'kodTugashVaqt': expires.millisecondsSinceEpoch,
      'code_expires': expires.millisecondsSinceEpoch,
      'kodlar': FieldValue.arrayUnion([code]),
    });
  }

  Future<RoomModel?> findRoom(String roomId) async {
    final doc = await _db.collection('guruhlar').doc(roomId).get();
    if (!doc.exists) return null;
    return RoomModel.fromMap(doc.id, doc.data()!);
  }

  Future<String> joinRoomByCode({
    required String code,
    required String userId,
  }) async {
    final snap = await _db
        .collection('guruhlar')
        .where('kodlar', arrayContains: code)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return 'Noto\'g\'ri kod!';

    final doc = snap.docs.first;
    final room = RoomModel.fromMap(doc.id, doc.data());

    if (room.azolar.contains(userId)) {
      return 'Siz allaqachon bu guruh a\'zosisiz';
    }

    if (!room.isCodeValid) return 'Kod muddati tugagan';

    await _db.collection('guruhlar').doc(doc.id).update({
      'azolar': FieldValue.arrayUnion([userId]),
    });

    return 'ok';
  }

  Stream<List<RoomModel>> getDomlaRooms(String domlaId) {
    return _db
        .collection('guruhlar')
        .where('ustozId', isEqualTo: domlaId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => RoomModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Stream<List<RoomModel>> getUserRooms(String userId) {
    return _db
        .collection('guruhlar')
        .where('azolar', arrayContains: userId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => RoomModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> deleteRoom(String roomId) async {
    await _db.collection('guruhlar').doc(roomId).delete();
  }
}
