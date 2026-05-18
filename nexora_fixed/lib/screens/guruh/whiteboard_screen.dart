import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../models/room_model.dart';

// -----------------------------------------------------------------
// Model: bitta chiziq
// -----------------------------------------------------------------
class _Stroke {
  final String id;
  final List<Offset> points;
  final Color color;
  final double width;

  _Stroke({required this.id, required this.points, required this.color, required this.width});

  Map<String, dynamic> toMap() => {
    'id': id,
    'color': color.value,
    'width': width,
    'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
  };

  static _Stroke fromMap(Map<String, dynamic> m) => _Stroke(
    id: m['id'] as String,
    color: Color(m['color'] as int),
    width: (m['width'] as num).toDouble(),
    points: (m['points'] as List)
        .map((p) => Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()))
        .toList(),
  );
}

// -----------------------------------------------------------------
// Screen
// -----------------------------------------------------------------
class WhiteboardScreen extends StatefulWidget {
  final RoomModel room;
  final UserModel user;
  const WhiteboardScreen({super.key, required this.room, required this.user});

  @override
  State<WhiteboardScreen> createState() => _WhiteboardScreenState();
}

class _WhiteboardScreenState extends State<WhiteboardScreen> {
  final Map<String, _Stroke> _strokes = {};
  _Stroke? _joriyStroke;

  Color _rang = Colors.black;
  double _qalinlik = 4.0;
  bool _saqlanmoqda = false;
  final GlobalKey _repaintKey = GlobalKey();

  late final CollectionReference _strokesRef;
  Size _canvasSize = Size.zero;

  bool get _menUstoz => widget.room.domlaId == widget.user.uid;

  final List<Color> _ranglar = [
    Colors.black, Colors.red, Colors.blue,
    Colors.green, Colors.orange, Colors.purple,
  ];

  @override
  void initState() {
    super.initState();
    _strokesRef = FirebaseFirestore.instance
        .collection('guruhlar')
        .doc(widget.room.id)
        .collection('whiteboard');

    _strokesRef.snapshots().listen(_firestoreYangilash);
  }

  void _firestoreYangilash(QuerySnapshot snap) {
    if (!mounted) return;
    final updated = <String, _Stroke>{};
    for (final doc in snap.docs) {
      try {
        final stroke = _Stroke.fromMap(doc.data() as Map<String, dynamic>);
        updated[stroke.id] = stroke;
      } catch (_) {}
    }
    setState(() {
      _strokes.clear();
      _strokes.addAll(updated);
    });
  }

  // Normalize 0..1 oraligiga
  Offset _normalize(Offset p) {
    if (_canvasSize == Size.zero) return p;
    return Offset(p.dx / _canvasSize.width, p.dy / _canvasSize.height);
  }

  Offset _denormalize(Offset p) =>
      Offset(p.dx * _canvasSize.width, p.dy * _canvasSize.height);

  List<_Stroke> _denormalizedStrokes() {
    if (_canvasSize == Size.zero) return _strokes.values.toList();
    return _strokes.values.map((s) => _Stroke(
      id: s.id,
      points: s.points.map(_denormalize).toList(),
      color: s.color,
      width: s.width,
    )).toList();
  }

  void _chizishBoshlash(Offset localPoint) {
    if (!_menUstoz) return;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final stroke = _Stroke(id: id, points: [_normalize(localPoint)], color: _rang, width: _qalinlik);
    setState(() {
      _joriyStroke = stroke;
      _strokes[id] = stroke;
    });
  }

  void _chizishDavom(Offset localPoint) {
    if (!_menUstoz || _joriyStroke == null) return;
    setState(() => _joriyStroke!.points.add(_normalize(localPoint)));
  }

  Future<void> _chizishTugat() async {
    if (!_menUstoz || _joriyStroke == null) return;
    final stroke = _joriyStroke!;
    setState(() => _joriyStroke = null);
    try {
      await _strokesRef.doc(stroke.id).set(stroke.toMap());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saqlashda xato: $e'), backgroundColor: AppColors.red));
    }
  }

  Future<void> _orqagaQaytish() async {
    if (!_menUstoz || _strokes.isEmpty) return;
    final lastId = _strokes.keys.last;
    setState(() => _strokes.remove(lastId));
    try { await _strokesRef.doc(lastId).delete(); } catch (_) {}
  }

  Future<void> _tozalash() async {
    if (!_menUstoz) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Taxtani tozalash'),
        content: const Text("Barcha chiziqlar o'chadi. Davom etasizmi?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Yo'q")),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Ha', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    final ids = List<String>.from(_strokes.keys);
    setState(() { _strokes.clear(); _joriyStroke = null; });
    for (final id in ids) {
      try { await _strokesRef.doc(id).delete(); } catch (_) {}
    }
  }

  Future<void> _saqlash() async {
    setState(() => _saqlanmoqda = true);
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/whiteboard_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rasm saqlandi!'), backgroundColor: AppColors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xato: $e'), backgroundColor: AppColors.red));
    } finally {
      if (mounted) setState(() => _saqlanmoqda = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: Row(children: [
          const Text('Whiteboard', style: TextStyle(color: Colors.black, fontSize: 16)),
          const SizedBox(width: 8),
          if (!_menUstoz)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text("Ko'rish rejimi",
                  style: TextStyle(color: Colors.blue.shade700, fontSize: 11)),
            ),
        ]),
        actions: [
          if (_menUstoz) ...[
            IconButton(icon: const Icon(Icons.undo), onPressed: _orqagaQaytish, tooltip: 'Orqaga'),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _tozalash, tooltip: 'Tozalash'),
          ],
          IconButton(
            icon: _saqlanmoqda
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_alt),
            onPressed: _saqlanmoqda ? null : _saqlash,
            tooltip: 'Rasm saqlash',
          ),
        ],
      ),
      body: Column(children: [
        if (_menUstoz) _buildToolbox(),
        Expanded(
          child: RepaintBoundary(
            key: _repaintKey,
            child: LayoutBuilder(builder: (ctx, constraints) {
              _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
              return Listener(
                // Listener ishlatiladi — GestureDetector scroll bilan conflikt qiladi
                onPointerDown: _menUstoz ? (e) => _chizishBoshlash(e.localPosition) : null,
                onPointerMove: _menUstoz ? (e) => _chizishDavom(e.localPosition) : null,
                onPointerUp:   _menUstoz ? (_) => _chizishTugat() : null,
                onPointerCancel: _menUstoz ? (_) => _chizishTugat() : null,
                child: CustomPaint(
                  painter: _WhiteboardPainter(_denormalizedStrokes()),
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                ),
              );
            }),
          ),
        ),
      ]),
    );
  }

  Widget _buildToolbox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(children: [
        ..._ranglar.map((r) => GestureDetector(
          onTap: () => setState(() => _rang = r),
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: r, shape: BoxShape.circle,
              border: Border.all(
                color: _rang == r ? Colors.grey.shade800 : Colors.grey.shade300,
                width: _rang == r ? 3 : 1,
              ),
            ),
          ),
        )),
        const SizedBox(width: 4),
        // Rezinka (oq rang)
        GestureDetector(
          onTap: () => setState(() { _rang = Colors.white; _qalinlik = 16; }),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: Colors.white, shape: BoxShape.circle,
              border: Border.all(
                color: _rang == Colors.white ? Colors.grey.shade800 : Colors.grey.shade300,
                width: _rang == Colors.white ? 3 : 1,
              ),
            ),
            child: Icon(Icons.auto_fix_normal, size: 14,
                color: _rang == Colors.white ? Colors.grey.shade700 : Colors.grey.shade400),
          ),
        ),
        Expanded(
          child: Slider(
            value: _qalinlik, min: 1, max: 20,
            activeColor: _rang == Colors.white ? Colors.grey : _rang,
            onChanged: (v) => setState(() => _qalinlik = v),
          ),
        ),
        SizedBox(width: 32, height: 32,
          child: Center(
            child: Container(
              width: _qalinlik.clamp(4.0, 20.0),
              height: _qalinlik.clamp(4.0, 20.0),
              decoration: BoxDecoration(
                color: _rang == Colors.white ? Colors.grey.shade400 : _rang,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// -----------------------------------------------------------------
// Painter — silliq bezier chiziq
// -----------------------------------------------------------------
class _WhiteboardPainter extends CustomPainter {
  final List<_Stroke> strokes;
  _WhiteboardPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      final paint = Paint()
        ..color = stroke.color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke.width
        ..style = PaintingStyle.stroke;

      if (stroke.points.length == 1) {
        canvas.drawCircle(stroke.points[0], stroke.width / 2,
            Paint()..color = stroke.color);
        continue;
      }

      final path = Path();
      path.moveTo(stroke.points[0].dx, stroke.points[0].dy);

      for (int i = 1; i < stroke.points.length - 1; i++) {
        final mid = Offset(
          (stroke.points[i].dx + stroke.points[i + 1].dx) / 2,
          (stroke.points[i].dy + stroke.points[i + 1].dy) / 2,
        );
        path.quadraticBezierTo(
          stroke.points[i].dx, stroke.points[i].dy,
          mid.dx, mid.dy,
        );
      }
      path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_WhiteboardPainter old) => true;
}
