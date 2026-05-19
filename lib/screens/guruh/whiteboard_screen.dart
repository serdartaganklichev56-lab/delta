import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../models/room_model.dart';

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

  // FIX #1: Virtual canvas o'lchami + TransformationController (scroll/zoom)
  static const double _canvasW = 2000.0;
  static const double _canvasH = 2000.0;
  final TransformationController _transformCtrl = TransformationController();
  bool _chizilmoqda = false; // chizish paytida pan o'chiriladi

  late final CollectionReference _strokesRef;

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

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  void _firestoreYangilash(QuerySnapshot snap) {
    if (!mounted) return;
    final updated = <String, _Stroke>{};
    for (final doc in snap.docs) {
      try {
        final s = _Stroke.fromMap(doc.data() as Map<String, dynamic>);
        updated[s.id] = s;
      } catch (_) {}
    }
    setState(() { _strokes.clear(); _strokes.addAll(updated); });
  }

  Offset _normalize(Offset p) => Offset(p.dx / _canvasW, p.dy / _canvasH);
  Offset _denormalize(Offset p) => Offset(p.dx * _canvasW, p.dy * _canvasH);

  List<_Stroke> _denormStrokes() => _strokes.values.map((s) => _Stroke(
    id: s.id,
    points: s.points.map(_denormalize).toList(),
    color: s.color,
    width: s.width,
  )).toList();

  // Pointer koordinatini transform matrix ga mos ravishda hisoblash
  Offset _toCanvas(Offset local) {
    final inv = Matrix4.inverted(_transformCtrl.value);
    return MatrixUtils.transformPoint(inv, local);
  }

  void _onPointerDown(PointerDownEvent e) {
    if (!_menUstoz) return;
    setState(() => _chizilmoqda = true);
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final s = _Stroke(id: id, points: [_normalize(_toCanvas(e.localPosition))],
        color: _rang, width: _qalinlik);
    setState(() { _joriyStroke = s; _strokes[id] = s; });
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_menUstoz || _joriyStroke == null) return;
    setState(() => _joriyStroke!.points.add(_normalize(_toCanvas(e.localPosition))));
  }

  Future<void> _onPointerUp(PointerUpEvent e) async {
    if (!_menUstoz || _joriyStroke == null) return;
    final s = _joriyStroke!;
    setState(() { _joriyStroke = null; _chizilmoqda = false; });
    try { await _strokesRef.doc(s.id).set(s.toMap()); } catch (err) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xato: $err'), backgroundColor: AppColors.red));
    }
  }

  void _onPointerCancel(PointerCancelEvent e) {
    setState(() { _joriyStroke = null; _chizilmoqda = false; });
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
    for (final id in ids) { try { await _strokesRef.doc(id).delete(); } catch (_) {} }
  }

  Future<void> _saqlash() async {
    setState(() => _saqlanmoqda = true);
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
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
            child: InteractiveViewer(
              transformationController: _transformCtrl,
              // FIX #1: chizilayotganda pan bloklash, bo'sh paytda scroll
              panEnabled: !_chizilmoqda,
              scaleEnabled: !_chizilmoqda,
              minScale: 0.3,
              maxScale: 5.0,
              boundaryMargin: const EdgeInsets.all(200),
              child: Listener(
                onPointerDown: _menUstoz ? _onPointerDown : null,
                onPointerMove: _menUstoz ? _onPointerMove : null,
                onPointerUp:   _menUstoz ? _onPointerUp   : null,
                onPointerCancel: _menUstoz ? _onPointerCancel : null,
                behavior: HitTestBehavior.opaque,
                child: CustomPaint(
                  painter: _WhiteboardPainter(_denormStrokes()),
                  size: const Size(_canvasW, _canvasH),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // FIX #2: Toolbox — overflow yo'q, ranglar aniq ko'rinadi
  Widget _buildToolbox() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Rang tugmalari
            ..._ranglar.map((r) => _rangTugma(r)),

            // Divider
            Container(
              width: 1, height: 32,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: Colors.grey.shade300,
            ),

            // Rezinka
            _rezinkaTugma(),

            const SizedBox(width: 10),

            // Qalinlik slider
            SizedBox(
              width: 110,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                ),
                child: Slider(
                  value: _qalinlik,
                  min: 1,
                  max: 20,
                  activeColor: _rang == Colors.white ? Colors.grey.shade600 : _rang,
                  inactiveColor: Colors.grey.shade300,
                  onChanged: (v) => setState(() => _qalinlik = v),
                ),
              ),
            ),

            // Qalinlik preview
            SizedBox(
              width: 32, height: 32,
              child: Center(
                child: Container(
                  width: _qalinlik.clamp(4.0, 24.0),
                  height: _qalinlik.clamp(4.0, 24.0),
                  decoration: BoxDecoration(
                    color: _rang == Colors.white ? Colors.grey.shade400 : _rang,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade400, width: 0.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rangTugma(Color r) {
    final isSelected = _rang == r && _rang != Colors.white;
    return GestureDetector(
      onTap: () => setState(() {
        _rang = r;
        if (_qalinlik > 12) _qalinlik = 4.0;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 7),
        width: isSelected ? 32 : 28,
        height: isSelected ? 32 : 28,
        decoration: BoxDecoration(
          color: r,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.grey.shade700 : Colors.grey.shade400,
            width: isSelected ? 3 : 1.5,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: r.withValues(alpha: 0.45), blurRadius: 8, spreadRadius: 1)]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 2)],
        ),
      ),
    );
  }

  Widget _rezinkaTugma() {
    final isSelected = _rang == Colors.white;
    return GestureDetector(
      onTap: () => setState(() { _rang = Colors.white; _qalinlik = 16; }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey.shade200 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.grey.shade700 : Colors.grey.shade400,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
              : [const BoxShadow(color: Colors.black12, blurRadius: 2)],
        ),
        child: Icon(Icons.auto_fix_normal, size: 18,
            color: isSelected ? Colors.grey.shade800 : Colors.grey.shade500),
      ),
    );
  }
}

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
        canvas.drawCircle(stroke.points[0], stroke.width / 2, Paint()..color = stroke.color);
        continue;
      }
      final path = Path();
      path.moveTo(stroke.points[0].dx, stroke.points[0].dy);
      for (int i = 1; i < stroke.points.length - 1; i++) {
        final mid = Offset(
          (stroke.points[i].dx + stroke.points[i + 1].dx) / 2,
          (stroke.points[i].dy + stroke.points[i + 1].dy) / 2,
        );
        path.quadraticBezierTo(stroke.points[i].dx, stroke.points[i].dy, mid.dx, mid.dy);
      }
      path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_WhiteboardPainter old) => true;
}
