import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../models/room_model.dart';

class WhiteboardScreen extends StatefulWidget {
  final RoomModel room;
  final UserModel user;
  const WhiteboardScreen({super.key, required this.room, required this.user});

  @override
  State<WhiteboardScreen> createState() => _WhiteboardScreenState();
}

class _WhiteboardScreenState extends State<WhiteboardScreen> {
  final List<_Stroke> _strokes = [];
  _Stroke? _joriyStroke;
  Color _rang = Colors.black;
  double _qalinlik = 3.0;
  bool _saqlanmoqda = false;
  final GlobalKey _repaintKey = GlobalKey();

  final List<Color> _ranglar = [
    Colors.black, Colors.red, Colors.blue,
    Colors.green, Colors.orange, Colors.purple,
  ];

  void _chizishBoshlash(Offset point) {
    final stroke = _Stroke([], _rang, _qalinlik);
    stroke.points.add(point);
    setState(() {
      _joriyStroke = stroke;
      _strokes.add(stroke);
    });
  }

  void _chizishDavom(Offset point) {
    if (_joriyStroke == null) return;
    setState(() => _joriyStroke!.points.add(point));
  }

  void _chizishTugat() {
    setState(() => _joriyStroke = null);
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
      final bytes = byteData.buffer.asUint8List();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/whiteboard_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saqlandi!'), backgroundColor: AppColors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xato: $e'), backgroundColor: AppColors.red));
    } finally {
      if (mounted) setState(() => _saqlanmoqda = false);
    }
  }

  void _tozalash() {
    setState(() {
      _strokes.clear();
      _joriyStroke = null;
    });
  }

  void _orqagaQaytish() {
    if (_strokes.isNotEmpty) {
      setState(() => _strokes.removeLast());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('Whiteboard', style: TextStyle(color: Colors.black, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.black),
            onPressed: _orqagaQaytish,
            tooltip: 'Orqaga',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.black),
            onPressed: _tozalash,
            tooltip: 'Tozalash',
          ),
          IconButton(
            icon: _saqlanmoqda
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_alt, color: Colors.black),
            onPressed: _saqlanmoqda ? null : _saqlash,
            tooltip: 'Saqlash',
          ),
        ],
      ),
      body: Column(children: [
        // Toolbox
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(children: [
            // Ranglar
            ..._ranglar.map((r) => GestureDetector(
              onTap: () => setState(() => _rang = r),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: r,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _rang == r ? Colors.grey.shade700 : Colors.grey.shade300,
                    width: _rang == r ? 2.5 : 1,
                  ),
                ),
              ),
            )),
            const SizedBox(width: 6),
            // O'chirish (oq rang)
            GestureDetector(
              onTap: () => setState(() => _rang = Colors.white),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _rang == Colors.white ? Colors.grey.shade700 : Colors.grey.shade300,
                    width: _rang == Colors.white ? 2.5 : 1,
                  ),
                ),
                child: Icon(Icons.auto_fix_normal, size: 14,
                    color: _rang == Colors.white ? Colors.grey.shade700 : Colors.grey.shade400),
              ),
            ),
            // Qalinlik
            Expanded(
              child: Slider(
                value: _qalinlik,
                min: 1, max: 20,
                activeColor: _rang == Colors.white ? Colors.grey : _rang,
                onChanged: (v) => setState(() => _qalinlik = v),
              ),
            ),
            // Qalinlik ko'rsatgich
            Container(
              width: 32, height: 32,
              alignment: Alignment.center,
              child: Container(
                width: _qalinlik.clamp(4, 20),
                height: _qalinlik.clamp(4, 20),
                decoration: BoxDecoration(
                  color: _rang == Colors.white ? Colors.grey.shade400 : _rang,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ]),
        ),

        // Canvas
        Expanded(
          child: RepaintBoundary(
            key: _repaintKey,
            child: GestureDetector(
              onPanStart: (d) => _chizishBoshlash(d.localPosition),
              onPanUpdate: (d) => _chizishDavom(d.localPosition),
              onPanEnd: (_) => _chizishTugat(),
              child: CustomPaint(
                painter: _WhiteboardPainter(_strokes),
                child: Container(
                  color: Colors.white,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  _Stroke(this.points, this.color, this.width);
}

class _WhiteboardPainter extends CustomPainter {
  final List<_Stroke> strokes;
  _WhiteboardPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white);

    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke.width
        ..style = PaintingStyle.stroke;

      if (stroke.points.length == 1) {
        // Bitta nuqta — doira chiz
        canvas.drawCircle(stroke.points[0], stroke.width / 2,
            Paint()..color = stroke.color);
        continue;
      }

      final path = Path();
      path.moveTo(stroke.points[0].dx, stroke.points[0].dy);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_WhiteboardPainter old) => true;
}
