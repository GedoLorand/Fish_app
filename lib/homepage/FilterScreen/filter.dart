import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:math' as math;
import 'package:login_fish_app/homepage/Header/global_header.dart';
import 'package:login_fish_app/homepage/Header/custom_drawer.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';
import 'package:login_fish_app/widgets/app_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:login_fish_app/services/filter_bus.dart';

class Filter extends StatefulWidget {
  const Filter({Key? key}) : super(key: key);

  @override
  State<Filter> createState() => _FilterState();
}

class _FilterState extends State<Filter> {
  String? selectedFishType;
  final TextEditingController weightController = TextEditingController();

  TimeOfDay? startTime;
  TimeOfDay? endTime;
  bool _showStartPicker = false;
  bool _showEndPicker = false;
  DateTime? _tempStartDateTime;
  DateTime? _tempEndDateTime;

  bool _hasChanged = false;
  DateTime? selectedDate;

  final List<String> fishTypes = ['Ponty', 'Csuka', 'Süllő', 'Harcsa', 'Amur'];
  List<String> dynamicFishSuggestions = [];

  // Weight
  final double maxWeight = 50.0;
  RangeValues _weightRange = const RangeValues(0, 10);
  bool _showWeightMinPicker = true;
  bool _showWeightMaxPicker = true;
  int _minKg = 0;
  int _minFrac = 0;
  int _maxKg = 10;
  int _maxFrac = 0;

  // Month / Year
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  final int _yearStart = 2020;
  // selected indices for pickers to compute shading
  late int _selectedMonthIndex;
  late int _selectedYearIndex;
  late int _minKgIndex;
  late int _minFracIndex;
  late int _maxKgIndex;
  late int _maxFracIndex;
  late int _startHourIndex;
  late int _startMinuteIndex;
  late int _endHourIndex;
  late int _endMinuteIndex;
  late int _startTimeIndex;
  late int _endTimeIndex;
  late int _minWeightIndex;
  late int _maxWeightIndex;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _showStartPicker = true;
    _showEndPicker = true;
    _tempStartDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );
    _tempEndDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );
    _minKg = _weightRange.start.toInt();
    _minFrac = ((_weightRange.start - _minKg) * 1000).round();
    _maxKg = _weightRange.end.toInt();
    _maxFrac = ((_weightRange.end - _maxKg) * 1000).round();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _selectedMonthIndex = _selectedMonth - 1;
    _selectedYearIndex = _selectedYear - _yearStart;
    _minKgIndex = _minKg;
    _minFracIndex = _minFrac;
    _maxKgIndex = _maxKg;
    _maxFracIndex = _maxFrac;
    _startHourIndex = startTime?.hour ?? now.hour;
    _startMinuteIndex = startTime?.minute ?? now.minute;
    _endHourIndex = endTime?.hour ?? now.hour;
    _endMinuteIndex = endTime?.minute ?? now.minute;
    _startTimeIndex =
        (startTime?.hour ?? now.hour) * 60 + (startTime?.minute ?? now.minute);
    _endTimeIndex =
        (endTime?.hour ?? now.hour) * 60 + (endTime?.minute ?? now.minute);
    _minWeightIndex = (_weightRange.start * 100).round();
    _maxWeightIndex = (_weightRange.end * 100).round();
  }

  double _opacityFor(
    int diff, {
    required double falloff,
    required double minOpacity,
  }) {
    final v = math.exp(-diff / falloff);
    final mapped = v * (1.0 - minOpacity) + minOpacity;
    return mapped.clamp(minOpacity, 1.0);
  }

  double _scaleFor(int diff) {
    if (diff == 0) return 1.08;
    final s = 1.0 - math.pow(diff, 1.15) * 0.02;
    return s.clamp(0.88, 1.08) as double;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null)
      setState(() {
        selectedDate = picked;
        _hasChanged = true;
      });
  }

  Future<void> _loadDynamicSpecies() async {
    try {
      final q = await FirebaseFirestore.instance
          .collectionGroup('images')
          .get();
      final set = <String>{};
      for (final doc in q.docs) {
        final data = doc.data();
        final s = data['species'];
        if (s is String && s.trim().isNotEmpty) set.add(s.trim());
      }
      setState(() => dynamicFishSuggestions = set.toList()..sort());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (dynamicFishSuggestions.isEmpty) _loadDynamicSpecies();

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: GlobalHeader(),
      drawer: CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              'Hal fajtája',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                final q = textEditingValue.text.toLowerCase();
                final source = dynamicFishSuggestions.isNotEmpty
                    ? dynamicFishSuggestions
                    : fishTypes;
                if (q.isEmpty) return const Iterable<String>.empty();
                return source.where((s) => s.toLowerCase().contains(q));
              },
              onSelected: (s) => setState(() => selectedFishType = s),
              fieldViewBuilder:
                  (context, controller, focusNode, onEditingComplete) {
                    controller.text = selectedFishType ?? controller.text;
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: 'Írd be vagy válassz',
                        border: OutlineInputBorder(),
                      ),
                    );
                  },
            ),
            const SizedBox(height: 12),
            // Top action buttons: Apply + optional Clear
            Builder(
              builder: (context) {
                final bool hasAny =
                    (selectedFishType != null &&
                        selectedFishType!.trim().isNotEmpty) ||
                    _weightRange.start > 0 ||
                    _weightRange.end < maxWeight ||
                    startTime != null ||
                    endTime != null ||
                    selectedDate != null;
                return Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        backgroundColor: AppTheme.primaryColor,
                        onPressed: hasAny
                            ? () {
                                final filter = {
                                  'species': selectedFishType,
                                  'weightMin': _weightRange.start,
                                  'weightMax': _weightRange.end,
                                  'month': _selectedMonth,
                                  'year': _selectedYear,
                                  'startTime': startTime != null
                                      ? {
                                          'hour': startTime!.hour,
                                          'minute': startTime!.minute,
                                        }
                                      : null,
                                  'endTime': endTime != null
                                      ? {
                                          'hour': endTime!.hour,
                                          'minute': endTime!.minute,
                                        }
                                      : null,
                                  'date': selectedDate?.toIso8601String(),
                                };
                                Future.microtask(
                                  () => FilterBus.instance.publish(filter),
                                );
                                Navigator.of(
                                  context,
                                ).pop({'appliedFilter': true});
                              }
                            : null,
                        child: const Text('Szűrés alkalmazása'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _hasChanged
                          ? AppButton(
                              backgroundColor: Colors.red.shade600,
                              onPressed: () {
                                Future.microtask(
                                  () => FilterBus.instance.publish(null),
                                );
                                setState(() {
                                  selectedFishType = null;
                                  _weightRange = const RangeValues(0, 10);
                                  startTime = null;
                                  endTime = null;
                                  selectedDate = null;
                                  _hasChanged = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Szűrők törölve'),
                                  ),
                                );
                              },
                              child: const Text('Szűrő kikapcsolása'),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Weight pickers
            Text(
              'Súly (kg)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Center(
                        child: Text(
                          'Min súly',
                          style: TextStyle(color: AppTheme.textColor),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _showWeightMinPicker
                          ? Container(
                              height: 90,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.transparent),
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: 140,
                                  child: CupertinoPicker(
                                    itemExtent: 30,
                                    selectionOverlay: Container(
                                      color: Colors.transparent,
                                    ),
                                    scrollController:
                                        FixedExtentScrollController(
                                          initialItem: math.min(
                                            math.max(_minWeightIndex, 0),
                                            (maxWeight * 100).toInt(),
                                          ),
                                        ),
                                    onSelectedItemChanged: (i) => setState(() {
                                      _minWeightIndex = i;
                                      final val = i / 100.0;
                                      _weightRange = RangeValues(
                                        val,
                                        _weightRange.end,
                                      );
                                      _hasChanged = true;
                                    }),
                                    children: List<Widget>.generate(
                                      (maxWeight * 100).toInt() + 1,
                                      (i) {
                                        final diff = (i - _minWeightIndex)
                                            .abs();
                                        final opacity = _opacityFor(
                                          diff,
                                          falloff: 6.0,
                                          minOpacity: 0.12,
                                        );
                                        final borderOpacity = _opacityFor(
                                          diff,
                                          falloff: 6.0,
                                          minOpacity: 0.06,
                                        );
                                        final scale = _scaleFor(diff);
                                        final kg = (i / 100.0).toStringAsFixed(
                                          2,
                                        );
                                        return Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4,
                                              horizontal: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: diff == 0
                                                  ? AppTheme.surfaceColor
                                                        .withOpacity(0.06)
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: AppTheme.textColor
                                                    .withOpacity(borderOpacity),
                                                width: diff == 0 ? 1.6 : 0.9,
                                              ),
                                            ),
                                            child: Transform.scale(
                                              scale: scale,
                                              child: Text(
                                                '$kg kg',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: diff == 0
                                                      ? Colors.white
                                                      : AppTheme.textColor
                                                            .withOpacity(
                                                              opacity,
                                                            ),
                                                  fontWeight: diff == 0
                                                      ? FontWeight.w700
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : AppButton(
                              backgroundColor: Colors.grey.shade900,
                              onPressed: () =>
                                  setState(() => _showWeightMinPicker = true),
                              child: Text(
                                'Min: ${_weightRange.start.toStringAsFixed(2)} kg',
                              ),
                            ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Center(
                        child: Text(
                          'Max súly',
                          style: TextStyle(color: AppTheme.textColor),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _showWeightMaxPicker
                          ? Container(
                              height: 90,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.transparent),
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: 140,
                                  child: CupertinoPicker(
                                    itemExtent: 30,
                                    selectionOverlay: Container(
                                      color: Colors.transparent,
                                    ),
                                    scrollController:
                                        FixedExtentScrollController(
                                          initialItem: math.min(
                                            math.max(_maxWeightIndex, 0),
                                            (maxWeight * 100).toInt(),
                                          ),
                                        ),
                                    onSelectedItemChanged: (i) => setState(() {
                                      _maxWeightIndex = i;
                                      final val = i / 100.0;
                                      _weightRange = RangeValues(
                                        _weightRange.start,
                                        val,
                                      );
                                      _hasChanged = true;
                                    }),
                                    children: List<Widget>.generate(
                                      (maxWeight * 100).toInt() + 1,
                                      (i) {
                                        final diff = (i - _maxWeightIndex)
                                            .abs();
                                        final opacity = _opacityFor(
                                          diff,
                                          falloff: 6.0,
                                          minOpacity: 0.12,
                                        );
                                        final borderOpacity = _opacityFor(
                                          diff,
                                          falloff: 6.0,
                                          minOpacity: 0.06,
                                        );
                                        final scale = _scaleFor(diff);
                                        final kg = (i / 100.0).toStringAsFixed(
                                          2,
                                        );
                                        return Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4,
                                              horizontal: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: diff == 0
                                                  ? AppTheme.surfaceColor
                                                        .withOpacity(0.06)
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: AppTheme.textColor
                                                    .withOpacity(borderOpacity),
                                                width: diff == 0 ? 1.6 : 0.9,
                                              ),
                                            ),
                                            child: Transform.scale(
                                              scale: scale,
                                              child: Text(
                                                '$kg kg',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: diff == 0
                                                      ? Colors.white
                                                      : AppTheme.textColor
                                                            .withOpacity(
                                                              opacity,
                                                            ),
                                                  fontWeight: diff == 0
                                                      ? FontWeight.w700
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : AppButton(
                              backgroundColor: Colors.grey.shade900,
                              onPressed: () =>
                                  setState(() => _showWeightMaxPicker = true),
                              child: Text(
                                'Max: ${_weightRange.end.toStringAsFixed(2)} kg',
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Time interval / granularity
            Text(
              'Időintervallum',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Center(
                        child: Text(
                          'Hónap',
                          style: TextStyle(color: AppTheme.textColor),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.transparent),
                        ),
                        child: CupertinoPicker(
                          itemExtent: 30,
                          selectionOverlay: Container(
                            color: Colors.transparent,
                          ),
                          scrollController: FixedExtentScrollController(
                            initialItem: _selectedMonthIndex,
                          ),
                          onSelectedItemChanged: (i) => setState(() {
                            _selectedMonth = i + 1;
                            _selectedMonthIndex = i;
                            _hasChanged = true;
                          }),
                          children: List<Widget>.generate(12, (i) {
                            final names = [
                              'Január',
                              'Február',
                              'Március',
                              'Április',
                              'Május',
                              'Június',
                              'Július',
                              'Augusztus',
                              'Szeptember',
                              'Október',
                              'November',
                              'December',
                            ];
                            final diff = (i - _selectedMonthIndex).abs();
                            final opacity = _opacityFor(
                              diff,
                              falloff: 3.0,
                              minOpacity: 0.12,
                            );
                            final bgOpacity = _opacityFor(
                              diff,
                              falloff: 3.0,
                              minOpacity: 0.02,
                            );
                            final borderOpacity = _opacityFor(
                              diff,
                              falloff: 3.0,
                              minOpacity: 0.06,
                            );
                            final scale = _scaleFor(diff);
                            final style = TextStyle(
                              fontSize: 15,
                              color: AppTheme.textColor.withOpacity(opacity),
                              fontWeight: diff == 0
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            );
                            return Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor.withOpacity(
                                    bgOpacity,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.textColor.withOpacity(
                                      borderOpacity,
                                    ),
                                    width: diff == 0 ? 1.4 : 0.9,
                                  ),
                                ),
                                child: Transform.scale(
                                  scale: scale,
                                  child: Text(names[i], style: style),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Center(
                        child: Text(
                          'Év',
                          style: TextStyle(color: AppTheme.textColor),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.transparent),
                        ),
                        child: CupertinoPicker(
                          itemExtent: 36,
                          selectionOverlay: Container(
                            color: Colors.transparent,
                          ),
                          scrollController: FixedExtentScrollController(
                            initialItem: _selectedYearIndex,
                          ),
                          onSelectedItemChanged: (i) => setState(() {
                            _selectedYear = _yearStart + i;
                            _selectedYearIndex = i;
                            _hasChanged = true;
                          }),
                          children: List<Widget>.generate(
                            DateTime.now().year - _yearStart + 1,
                            (i) {
                              final diff = (i - _selectedYearIndex).abs();
                              final opacity = _opacityFor(
                                diff,
                                falloff: 4.0,
                                minOpacity: 0.12,
                              );
                              final bgOpacity = _opacityFor(
                                diff,
                                falloff: 4.0,
                                minOpacity: 0.02,
                              );
                              final borderOpacity = _opacityFor(
                                diff,
                                falloff: 4.0,
                                minOpacity: 0.06,
                              );
                              final scale = _scaleFor(diff);
                              return Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                    horizontal: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceColor.withOpacity(
                                      bgOpacity,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTheme.textColor.withOpacity(
                                        borderOpacity,
                                      ),
                                      width: diff == 0 ? 1.6 : 0.9,
                                    ),
                                  ),
                                  child: Transform.scale(
                                    scale: scale,
                                    child: Text(
                                      '${_yearStart + i}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: AppTheme.textColor.withOpacity(
                                          opacity,
                                        ),
                                        fontWeight: diff == 0
                                            ? FontWeight.w700
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Center(
                        child: Text(
                          'Kezdő időpont',
                          style: TextStyle(color: AppTheme.textColor),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _showStartPicker
                          ? Container(
                              height: 96,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.transparent),
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: 140,
                                  child: CupertinoPicker(
                                    itemExtent: 30,
                                    selectionOverlay: Container(
                                      color: Colors.transparent,
                                    ),
                                    scrollController:
                                        FixedExtentScrollController(
                                          initialItem: math.min(
                                            math.max(_startTimeIndex, 0),
                                            24 * 60 - 1,
                                          ),
                                        ),
                                    onSelectedItemChanged: (i) => setState(() {
                                      _startTimeIndex = i;
                                      startTime = TimeOfDay(
                                        hour: i ~/ 60,
                                        minute: i % 60,
                                      );
                                      _hasChanged = true;
                                    }),
                                    children: List<Widget>.generate(24 * 60, (
                                      i,
                                    ) {
                                      final diff = (i - _startTimeIndex).abs();
                                      final opacity = _opacityFor(
                                        diff,
                                        falloff: 6.0,
                                        minOpacity: 0.12,
                                      );
                                      final borderOpacity = _opacityFor(
                                        diff,
                                        falloff: 6.0,
                                        minOpacity: 0.06,
                                      );
                                      final scale = _scaleFor(diff);
                                      final hh = (i ~/ 60).toString().padLeft(
                                        2,
                                        '0',
                                      );
                                      final mm = (i % 60).toString().padLeft(
                                        2,
                                        '0',
                                      );
                                      return Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                            horizontal: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: diff == 0
                                                ? AppTheme.surfaceColor
                                                      .withOpacity(0.06)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: AppTheme.textColor
                                                  .withOpacity(borderOpacity),
                                              width: diff == 0 ? 1.6 : 0.9,
                                            ),
                                          ),
                                          child: Transform.scale(
                                            scale: scale,
                                            child: Text(
                                              '$hh:$mm',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: diff == 0
                                                    ? Colors.white
                                                    : AppTheme.textColor
                                                          .withOpacity(opacity),
                                                fontWeight: diff == 0
                                                    ? FontWeight.w700
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ),
                            )
                          : AppButton(
                              backgroundColor: Colors.grey.shade900,
                              onPressed: () => setState(() {
                                _showStartPicker = true;
                                _showEndPicker = false;
                                final now = DateTime.now();
                                _tempStartDateTime = DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                  startTime?.hour ?? now.hour,
                                  startTime?.minute ?? now.minute,
                                );
                              }),
                              child: Text(
                                startTime == null
                                    ? 'Kezdő időpont'
                                    : startTime!.format(context),
                              ),
                            ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Center(
                        child: Text(
                          'Záró időpont',
                          style: TextStyle(color: AppTheme.textColor),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _showEndPicker
                          ? Container(
                              height: 96,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.transparent),
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: 140,
                                  child: CupertinoPicker(
                                    itemExtent: 30,
                                    selectionOverlay: Container(
                                      color: Colors.transparent,
                                    ),
                                    scrollController:
                                        FixedExtentScrollController(
                                          initialItem: math.min(
                                            math.max(_endTimeIndex, 0),
                                            24 * 60 - 1,
                                          ),
                                        ),
                                    onSelectedItemChanged: (i) => setState(() {
                                      _endTimeIndex = i;
                                      endTime = TimeOfDay(
                                        hour: i ~/ 60,
                                        minute: i % 60,
                                      );
                                      _hasChanged = true;
                                    }),
                                    children: List<Widget>.generate(24 * 60, (
                                      i,
                                    ) {
                                      final diff = (i - _endTimeIndex).abs();
                                      final opacity = _opacityFor(
                                        diff,
                                        falloff: 6.0,
                                        minOpacity: 0.12,
                                      );
                                      final borderOpacity = _opacityFor(
                                        diff,
                                        falloff: 6.0,
                                        minOpacity: 0.06,
                                      );
                                      final scale = _scaleFor(diff);
                                      final hh = (i ~/ 60).toString().padLeft(
                                        2,
                                        '0',
                                      );
                                      final mm = (i % 60).toString().padLeft(
                                        2,
                                        '0',
                                      );
                                      return Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                            horizontal: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: diff == 0
                                                ? AppTheme.surfaceColor
                                                      .withOpacity(0.06)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: AppTheme.textColor
                                                  .withOpacity(borderOpacity),
                                              width: diff == 0 ? 1.6 : 0.9,
                                            ),
                                          ),
                                          child: Transform.scale(
                                            scale: scale,
                                            child: Text(
                                              '$hh:$mm',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: diff == 0
                                                    ? Colors.white
                                                    : AppTheme.textColor
                                                          .withOpacity(opacity),
                                                fontWeight: diff == 0
                                                    ? FontWeight.w700
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ),
                            )
                          : AppButton(
                              backgroundColor: Colors.grey.shade900,
                              onPressed: () => setState(() {
                                _showEndPicker = true;
                                _showStartPicker = false;
                                final now = DateTime.now();
                                _tempEndDateTime = DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                  endTime?.hour ?? now.hour,
                                  endTime?.minute ?? now.minute,
                                );
                              }),
                              child: Text(
                                endTime == null
                                    ? 'Záró időpont'
                                    : endTime!.format(context),
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              'Dátum',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            AppButton(
              backgroundColor: Colors.grey.shade900,
              onPressed: () => _selectDate(context),
              child: Text(
                selectedDate == null
                    ? 'Válassz dátumot'
                    : '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}',
              ),
            ),

            const SizedBox(height: 32),

            Builder(
              builder: (context) {
                final bool hasAny =
                    (selectedFishType != null &&
                        selectedFishType!.trim().isNotEmpty) ||
                    _weightRange.start > 0 ||
                    _weightRange.end < maxWeight ||
                    startTime != null ||
                    endTime != null ||
                    selectedDate != null;
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}
