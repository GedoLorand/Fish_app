import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClusterStatisticsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> entries;

  const ClusterStatisticsScreen({Key? key, required this.entries})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    // compute simple stats: species count, time/weight points, coords, weights
    final Map<String, int> speciesCount = {};
    final List<MapEntry<DateTime, double>> timeWeight = [];
    final List<double> weights = [];
    // keep species per weight so histogram can show example species per bin
    final List<MapEntry<double, String>> weightSpecies = [];
    final List<MapEntry<double, double>> coordPoints = [];

    for (final e in entries) {
      final doc = e['doc'] as Map<String, dynamic>? ?? {};
      final sp = (doc['species'] ?? 'Ismeretlen').toString();
      speciesCount[sp] = (speciesCount[sp] ?? 0) + 1;

      // weight
      try {
        final val = doc['weight'];
        double? w;
        if (val is num)
          w = val.toDouble();
        else if (val is String)
          w = double.tryParse(val.replaceAll(',', '.'));
        if (w != null) weights.add(w);
        // time
        DateTime? dt;
        final created = doc['createdAt'];
        if (created is Timestamp)
          dt = created.toDate();
        else if (created is DateTime)
          dt = created;
        else if (created is String)
          dt = DateTime.tryParse(created);
        if (dt != null && w != null) timeWeight.add(MapEntry(dt, w));
        if (w != null) weightSpecies.add(MapEntry(w, sp));
      } catch (_) {}

      // coords
      try {
        final p = e['point'];
        if (p != null) {
          double? lat;
          double? lng;
          if (p is Map) {
            lat = (p['latitude'] ?? p['lat']) as double?;
            lng = (p['longitude'] ?? p['lng'] ?? p['lon']) as double?;
          } else {
            // attempt common fields
            lat = p.latitude as double?;
            lng = p.longitude as double?;
          }
          if (lat != null && lng != null) coordPoints.add(MapEntry(lat, lng));
        }
      } catch (_) {}
    }

    final sortedSpecies = speciesCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // compute first and last upload times from timeWeight
    DateTime? firstUpload;
    DateTime? lastUpload;
    if (timeWeight.isNotEmpty) {
      timeWeight.sort((a, b) => a.key.compareTo(b.key));
      firstUpload = timeWeight.first.key;
      lastUpload = timeWeight.last.key;
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('cluster_statistics'.tr),
          backgroundColor: AppTheme.primaryColor,
          bottom: TabBar(
            isScrollable: true,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.black54,
            indicatorColor: AppTheme.primaryColor,
            tabs: [
              Tab(text: 'species_tab'.tr),
              Tab(text: 'time_weight_tab'.tr),
              Tab(text: 'distribution_tab'.tr),
              Tab(text: 'coordinates_tab'.tr),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Species pie chart + legend
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${'total_results'.tr}: ${entries.length}',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: speciesCount.isEmpty
                        ? Center(
                            child: Text(
                              'no_data'.tr,
                              style: const TextStyle(color: Colors.white),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 300,
                                width: double.infinity,
                                child: CustomPaint(
                                  painter: _PieChartPainter(sortedSpecies),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Legenda:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: sortedSpecies.map((e) {
                                      final idx = sortedSpecies.indexOf(e);
                                      final color = _colorForIndex(idx);
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4.0,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 18,
                                              height: 18,
                                              color: color,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '${e.key} — ${e.value}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),

            // Time vs weight
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: timeWeight.isEmpty
                  ? Center(
                      child: Text(
                        'no_data'.tr,
                        style: const TextStyle(color: Colors.white),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${'first_upload'.tr}: ${firstUpload != null ? firstUpload.toLocal().toString().split('.').first : '-'}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        Text(
                          '${'last_upload'.tr}: ${lastUpload != null ? lastUpload.toLocal().toString().split('.').first : '-'}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SizedBox(
                            height: 240,
                            width: double.infinity,
                            child: TimeWeightChart(points: timeWeight),
                          ),
                        ),
                      ],
                    ),
            ),

            // Histogram (shows counts and sample species per weight bin)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: weightSpecies.isEmpty
                  ? Center(
                      child: Text(
                        'no_data'.tr,
                        style: const TextStyle(color: Colors.black),
                      ),
                    )
                  : SizedBox(
                      height: 360,
                      child: CustomPaint(
                        painter: _HistogramPainter(weightSpecies, Colors.white),
                        size: Size.infinite,
                      ),
                    ),
            ),

            // Coordinates scatter
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: coordPoints.isEmpty
                  ? Center(
                      child: Text(
                        'no_data'.tr,
                        style: const TextStyle(color: Colors.black),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        height: 360,
                        width: 600,
                        child: CustomPaint(
                          painter: _ScatterPainter(coordPoints, Colors.white),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _colorForIndex(int i) {
  const palette = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.cyan,
    Colors.brown,
    Colors.pink,
    Colors.teal,
    Colors.indigo,
  ];
  return palette[i % palette.length];
}

class _PieChartPainter extends CustomPainter {
  final List<MapEntry<String, int>> entries;
  _PieChartPainter(this.entries);

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;
    final total = entries.map((e) => e.value).fold<int>(0, (a, b) => a + b);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.4;
    double startAngle = -math.pi / 2;
    int idx = 0;
    final paint = Paint()..style = PaintingStyle.fill;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final e in entries) {
      final sweep = (e.value / total) * math.pi * 2;
      paint.color = _colorForIndex(idx);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        paint,
      );

      final sepPaint = Paint()
        ..color = Colors.black
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      final sx = center.dx + math.cos(startAngle) * radius;
      final sy = center.dy + math.sin(startAngle) * radius;
      canvas.drawLine(center, Offset(sx, sy), sepPaint);

      final mid = startAngle + sweep / 2;
      final lx = center.dx + math.cos(mid) * (radius * 0.58);
      final ly = center.dy + math.sin(mid) * (radius * 0.58);
      final percent = ((e.value / total) * 100).round();
      tp.text = TextSpan(
        text: '$percent%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));

      startAngle += sweep;
      idx++;
    }

    final outline = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, outline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TimeSeriesPainter extends CustomPainter {
  final List<MapEntry<DateTime, double>> points;
  final Color color;
  _TimeSeriesPainter(this.points, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final sorted = List.of(points)..sort((a, b) => a.key.compareTo(b.key));
    final minT = sorted.first.key.millisecondsSinceEpoch.toDouble();
    final maxT = sorted.last.key.millisecondsSinceEpoch.toDouble();
    final minW = sorted.map((e) => e.value).reduce(math.min);
    final maxW = sorted.map((e) => e.value).reduce(math.max);

    final paint = Paint()
      ..color = color.withOpacity(0.98)
      ..strokeWidth = 2.4;
    final dotPaint = Paint()..color = color;
    final axisPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.6;
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..strokeWidth = 1.0;
    final tp = TextPainter(textDirection: TextDirection.ltr);

    // adaptive margins
    final leftMargin = math.max(42.0, size.width * 0.08);
    final rightMargin = math.max(10.0, size.width * 0.03);
    final topMargin = math.max(8.0, size.height * 0.04);
    final bottomMargin = math.max(36.0, size.height * 0.12);
    final plotWidth = size.width - leftMargin - rightMargin;
    final plotHeight = size.height - topMargin - bottomMargin;

    // derived
    final rangeHours = (maxT - minT) / (1000 * 60 * 60);
    String fmtLabel(DateTime dt) {
      final local = dt.toLocal();
      String two(int v) => v.toString().padLeft(2, '0');
      if (rangeHours >= 48) return '${two(local.month)}-${two(local.day)}';
      if (rangeHours >= 1)
        return '${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
      return '${two(local.hour)}:${two(local.minute)}';
    }

    // axes
    final origin = Offset(leftMargin, topMargin + plotHeight);
    final xAxisEnd = Offset(leftMargin + plotWidth, topMargin + plotHeight);
    final yAxisTop = Offset(leftMargin, topMargin);
    canvas.drawLine(origin, xAxisEnd, axisPaint);
    canvas.drawLine(origin, yAxisTop, axisPaint);

    // y ticks and grid
    final yTicks = [minW, (minW + maxW) / 2, maxW];
    for (int i = 0; i < yTicks.length; i++) {
      final yVal = yTicks[i];
      final y =
          topMargin +
          plotHeight -
          ((yVal - minW) / (maxW - minW + 0.0001)) * plotHeight;
      canvas.drawLine(
        Offset(leftMargin, y),
        Offset(leftMargin + plotWidth, y),
        gridPaint,
      );
      tp.text = TextSpan(
        text: yVal.toStringAsFixed(1),
        style: TextStyle(color: Colors.white, fontSize: 12),
      );
      tp.layout();
      tp.paint(canvas, Offset(6, y - tp.height / 2));
    }

    // x ticks and labels (first, mid, last)
    final midMillis = ((minT + maxT) / 2).toInt();
    final timeTicks = [
      sorted.first.key,
      DateTime.fromMillisecondsSinceEpoch(midMillis),
      sorted.last.key,
    ];
    for (int i = 0; i < timeTicks.length; i++) {
      final tDt = timeTicks[i];
      final t = tDt.millisecondsSinceEpoch.toDouble();
      final x = leftMargin + ((t - minT) / (maxT - minT + 1)) * plotWidth;
      canvas.drawLine(
        Offset(x, topMargin),
        Offset(x, topMargin + plotHeight),
        gridPaint,
      );
      final label = fmtLabel(tDt);
      tp.text = TextSpan(
        text: label,
        style: TextStyle(color: Colors.white, fontSize: 12),
      );
      tp.layout(maxWidth: plotWidth * 0.6);
      double tx = x - tp.width / 2;
      tx = tx.clamp(leftMargin + 2.0, leftMargin + plotWidth - tp.width - 2.0);
      final ty = topMargin + plotHeight + 6;
      tp.paint(canvas, Offset(tx, ty));
    }

    // plot line and mark all points
    Offset? last;
    for (int i = 0; i < sorted.length; i++) {
      final t = sorted[i].key.millisecondsSinceEpoch.toDouble();
      final w = sorted[i].value;
      final x = leftMargin + ((t - minT) / (maxT - minT + 1)) * plotWidth;
      final y =
          topMargin +
          plotHeight -
          ((w - minW) / (maxW - minW + 0.0001)) * plotHeight;
      final p = Offset(x, y);
      if (last != null) canvas.drawLine(last, p, paint);
      // halo then center
      canvas.drawCircle(p, 5.0, Paint()..color = Colors.white);
      canvas.drawCircle(p, 3.6, dotPaint);
      last = p;
    }

    // highlight first/last
    final first = sorted.first;
    final lastPt = sorted.last;
    final fx =
        leftMargin +
        ((first.key.millisecondsSinceEpoch.toDouble() - minT) /
                (maxT - minT + 1)) *
            plotWidth;
    final fy =
        topMargin +
        plotHeight -
        ((first.value - minW) / (maxW - minW + 0.0001)) * plotHeight;
    final lx =
        leftMargin +
        ((lastPt.key.millisecondsSinceEpoch.toDouble() - minT) /
                (maxT - minT + 1)) *
            plotWidth;
    final ly =
        topMargin +
        plotHeight -
        ((lastPt.value - minW) / (maxW - minW + 0.0001)) * plotHeight;
    final highlightPaint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(fx, fy), 6, highlightPaint);
    canvas.drawCircle(Offset(lx, ly), 6, highlightPaint);

    String labelFor(DateTime dt, double value) {
      final local = dt.toLocal();
      String two(int v) => v.toString().padLeft(2, '0');
      final time = (rangeHours >= 24)
          ? '${two(local.month)}-${two(local.day)}'
          : '${two(local.hour)}:${two(local.minute)}';
      return '$time\n${value.toStringAsFixed(1)}';
    }

    tp.text = TextSpan(
      text: labelFor(first.key, first.value),
      style: TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
    tp.layout(maxWidth: plotWidth * 0.45);
    double ftx = fx - tp.width / 2;
    ftx = ftx.clamp(leftMargin + 2.0, leftMargin + plotWidth - tp.width - 2.0);
    double fty = fy - tp.height - 8;
    fty = math.max(fty, topMargin + 2.0);
    tp.paint(canvas, Offset(ftx, fty));

    tp.text = TextSpan(
      text: labelFor(lastPt.key, lastPt.value),
      style: TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
    tp.layout(maxWidth: plotWidth * 0.45);
    double ltx = lx - tp.width / 2;
    ltx = ltx.clamp(leftMargin + 2.0, leftMargin + plotWidth - tp.width - 2.0);
    double lty = ly - tp.height - 8;
    lty = math.max(lty, topMargin + 2.0);
    tp.paint(canvas, Offset(ltx, lty));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HistogramPainter extends CustomPainter {
  final List<MapEntry<double, String>> entries; // weight -> species
  final Color color;
  _HistogramPainter(this.entries, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;
    final bins = 8;
    final values = entries.map((e) => e.key).toList();
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final width = size.width / bins;

    final counts = List.filled(bins, 0);
    final Map<int, Map<String, int>> binSpecies = {};
    for (final e in entries) {
      final v = e.key;
      int idx = ((v - minV) / (maxV - minV + 0.0001) * (bins - 1)).round();
      idx = idx.clamp(0, bins - 1);
      counts[idx]++;
      binSpecies.putIfAbsent(idx, () => {});
      final famap = binSpecies[idx]!;
      famap[e.value] = (famap[e.value] ?? 0) + 1;
    }
    final maxCount = counts.reduce(math.max).toDouble();
    final paint = Paint()..color = color.withOpacity(0.95);
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < bins; i++) {
      final h = (size.height - 60) * (counts[i] / (maxCount + 0.0001));
      final r = Rect.fromLTWH(
        i * width + 6,
        size.height - h - 34,
        width - 12,
        h,
      );
      canvas.drawRect(r, paint);
      // label above bar (count)
      tp.text = TextSpan(
        text: '${counts[i]}',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(r.left + (r.width - tp.width) / 2, r.top - 18));

      // draw up to two top species under each bar as examples
      final speciesMap = binSpecies[i] ?? {};
      if (speciesMap.isNotEmpty) {
        final speciesList = speciesMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final examples = speciesList.take(2).map((e) => e.key).toList();
        final exText = examples.join(', ');
        tp.text = TextSpan(
          text: exText,
          style: TextStyle(color: Colors.white70, fontSize: 11),
        );
        tp.layout(maxWidth: r.width);
        tp.paint(
          canvas,
          Offset(r.left + (r.width - tp.width) / 2, r.bottom + 4),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TimeWeightChart extends StatefulWidget {
  final List<MapEntry<DateTime, double>> points;
  final Color color;
  const TimeWeightChart({
    Key? key,
    required this.points,
    this.color = Colors.white,
  }) : super(key: key);

  @override
  _TimeWeightChartState createState() => _TimeWeightChartState();
}

class _TimeWeightChartState extends State<TimeWeightChart> {
  MapEntry<DateTime, double>? _selectedEntry;
  Offset? _selectedOffset;

  void _updateSelection(Offset localPos, Size size) {
    final pts = widget.points;
    if (pts.isEmpty) return;
    final sorted = List.of(pts)..sort((a, b) => a.key.compareTo(b.key));
    final minT = sorted.first.key.millisecondsSinceEpoch.toDouble();
    final maxT = sorted.last.key.millisecondsSinceEpoch.toDouble();
    final minW = sorted.map((e) => e.value).reduce(math.min);
    final maxW = sorted.map((e) => e.value).reduce(math.max);

    final leftMargin = math.max(42.0, size.width * 0.08);
    final rightMargin = math.max(10.0, size.width * 0.03);
    final topMargin = math.max(8.0, size.height * 0.04);
    final bottomMargin = math.max(36.0, size.height * 0.12);
    final plotWidth = size.width - leftMargin - rightMargin;
    final plotHeight = size.height - topMargin - bottomMargin;

    int nearest = -1;
    double bestDist = double.infinity;
    for (int i = 0; i < sorted.length; i++) {
      final t = sorted[i].key.millisecondsSinceEpoch.toDouble();
      final w = sorted[i].value;
      final x = leftMargin + ((t - minT) / (maxT - minT + 1)) * plotWidth;
      final y =
          topMargin +
          plotHeight -
          ((w - minW) / (maxW - minW + 0.0001)) * plotHeight;
      final d = (localPos - Offset(x, y)).distance;
      if (d < bestDist) {
        bestDist = d;
        nearest = i;
      }
    }

    // require a reasonable proximity (30 px)
    if (bestDist <= 30) {
      final selEntry = sorted[nearest];
      final selT = selEntry.key.millisecondsSinceEpoch.toDouble();
      final selW = selEntry.value;
      final sx = leftMargin + ((selT - minT) / (maxT - minT + 1)) * plotWidth;
      final sy =
          topMargin +
          plotHeight -
          ((selW - minW) / (maxW - minW + 0.0001)) * plotHeight;
      setState(() {
        _selectedEntry = selEntry;
        _selectedOffset = Offset(sx, sy);
      });
    } else {
      setState(() {
        _selectedEntry = null;
        _selectedOffset = null;
      });
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedEntry = null;
      _selectedOffset = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onTapDown: (d) => _updateSelection(d.localPosition, size),
          onPanStart: (d) => _updateSelection(d.localPosition, size),
          onPanUpdate: (d) => _updateSelection(d.localPosition, size),
          onPanEnd: (_) => _clearSelection(),
          onTapUp: (_) =>
              Future.delayed(const Duration(seconds: 3), _clearSelection),
          child: Stack(
            children: [
              CustomPaint(
                size: size,
                painter: _TimeSeriesPainter(widget.points, widget.color),
              ),
              if (_selectedEntry != null && _selectedOffset != null)
                Positioned(
                  left: (_selectedOffset!.dx + 8).clamp(
                    8.0,
                    size.width - 160.0,
                  ),
                  top: (_selectedOffset!.dy - 40).clamp(
                    8.0,
                    size.height - 40.0,
                  ),
                  child: _buildTooltip(_selectedEntry!),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTooltip(MapEntry<DateTime, double> e) {
    final dt = e.key.toLocal();
    final time = dt.toString().split('.').first;
    final weight = e.value.toStringAsFixed(2);
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              time,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '${weight} g',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScatterPainter extends CustomPainter {
  final List<MapEntry<double, double>> pts;
  final Color color;
  _ScatterPainter(this.pts, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.isEmpty) return;
    double minX = pts.first.key, maxX = pts.first.key;
    double minY = pts.first.value, maxY = pts.first.value;
    for (final p in pts) {
      if (p.key < minX) minX = p.key;
      if (p.key > maxX) maxX = p.key;
      if (p.value < minY) minY = p.value;
      if (p.value > maxY) maxY = p.value;
    }
    for (final p in pts) {
      final x =
          20 + ((p.key - minX) / (maxX - minX + 0.0001)) * (size.width - 40);
      final y =
          size.height -
          20 -
          ((p.value - minY) / (maxY - minY + 0.0001)) * (size.height - 40);
      // draw white halo then colored center for contrast
      canvas.drawCircle(Offset(x, y), 5.0, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(x, y), 3.6, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
