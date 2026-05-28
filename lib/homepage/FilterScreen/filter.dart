import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:math' as math;
import 'package:login_fish_app/homepage/Header/global_header.dart';
import 'package:login_fish_app/homepage/Header/custom_drawer.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';
import 'package:login_fish_app/widgets/app_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:login_fish_app/services/filter_bus.dart';

class Filter extends StatefulWidget {
  final bool restrictToCurrentUser;

  const Filter({Key? key, this.restrictToCurrentUser = false})
    : super(key: key);

  @override
  State<Filter> createState() => _FilterState();
}

class _FilterState extends State<Filter> {
  String? selectedFishType;
  final TextEditingController weightController = TextEditingController();
  TextEditingController speciesController = TextEditingController();

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
    // Default indices 0 mean "not set"; actual values start from 1
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _selectedMonthIndex = 0;
    _selectedYearIndex = 0;
    _minKgIndex = _minKg;
    _minFracIndex = _minFrac;
    _maxKgIndex = _maxKg;
    _maxFracIndex = _maxFrac;
    _startHourIndex = startTime?.hour ?? now.hour;
    _startMinuteIndex = startTime?.minute ?? now.minute;
    _endHourIndex = endTime?.hour ?? now.hour;
    _endMinuteIndex = endTime?.minute ?? now.minute;
    // Use 0 as placeholder index meaning "not set"; actual minutes and weights start at index 1
    _startTimeIndex = 0;
    _endTimeIndex = 0;
    _minWeightIndex = 0;
    _maxWeightIndex = 0;
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
              'fish_type'.tr,
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
              onSelected: (s) => setState(() {
                selectedFishType = s;
                try {
                  speciesController.text = s;
                } catch (_) {}
              }),
              fieldViewBuilder:
                  (context, controller, focusNode, onEditingComplete) {
                    // capture the Autocomplete-provided controller so we can
                    // read the typed value when Apply is pressed
                    speciesController = controller;
                    if (selectedFishType != null &&
                        selectedFishType!.isNotEmpty) {
                      controller.text = selectedFishType!;
                    }
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: 'enter_or_choose'.tr,
                        border: OutlineInputBorder(),
                      ),
                    );
                  },
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 8),
            const SizedBox(height: 12),
            // Top action buttons: Apply + optional Clear
            Builder(
              builder: (context) {
                // Show Apply & Clear only after the user has changed something (_hasChanged)
                return Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    if (_hasChanged) ...[
                      SizedBox(
                        width: 140,
                        height: 40,
                        child: AppButton(
                          backgroundColor: AppTheme.primaryColor,
                          onPressed: () {
                            // resolve species from typed input if needed
                            final filter = <String, dynamic>{};
                            final typed = speciesController.text.trim();
                            String? resolvedSpecies = selectedFishType;
                            if ((resolvedSpecies == null ||
                                    resolvedSpecies.trim().isEmpty) &&
                                typed.isNotEmpty) {
                              // try to pick nearest from suggestions
                              final source = dynamicFishSuggestions.isNotEmpty
                                  ? dynamicFishSuggestions
                                  : fishTypes;
                              final low = typed.toLowerCase();
                              // prefer startsWith, then contains
                              String? found = source.firstWhere(
                                (s) => s.toLowerCase().startsWith(low),
                                orElse: () => '',
                              );
                              if (found.isEmpty) {
                                found = source.firstWhere(
                                  (s) => s.toLowerCase().contains(low),
                                  orElse: () => '',
                                );
                              }
                              if (found.isNotEmpty) resolvedSpecies = found;
                            }
                            if (resolvedSpecies != null &&
                                resolvedSpecies.trim().isNotEmpty)
                              filter['species'] = resolvedSpecies;
                            if (_minWeightIndex != 0)
                              filter['weightMin'] =
                                  (_minWeightIndex - 1) / 10.0;
                            if (_maxWeightIndex != 0)
                              filter['weightMax'] =
                                  (_maxWeightIndex - 1) / 10.0;
                            if (_selectedMonthIndex != 0)
                              filter['month'] = _selectedMonth;
                            if (_selectedYearIndex != 0)
                              filter['year'] = _selectedYear;
                            if (startTime != null)
                              filter['startTime'] = {
                                'hour': startTime!.hour,
                                'minute': startTime!.minute,
                              };
                            if (endTime != null)
                              filter['endTime'] = {
                                'hour': endTime!.hour,
                                'minute': endTime!.minute,
                              };
                            if (selectedDate != null)
                              filter['date'] = selectedDate!.toIso8601String();
                            if (widget.restrictToCurrentUser) {
                              filter['ownerOnly'] = true;
                            }
                            // publish synchronously so listeners update immediately
                            FilterBus.instance.publish(
                              filter.isEmpty ? null : filter,
                            );
                            // pop back to the app root so the existing MapScreen (inside Wrapper/Homepage)
                            // becomes visible and reacts to the published filter
                            Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst);
                          },
                          child: const Center(
                            child: Text(
                              'Szűrés alkalmazása',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 140,
                        height: 40,
                        child: AppButton(
                          backgroundColor: Colors.red.shade600,
                          onPressed: () {
                            FilterBus.instance.publish(null);
                            setState(() {
                              selectedFishType = null;
                              _weightRange = const RangeValues(0, 10);
                              startTime = null;
                              endTime = null;
                              selectedDate = null;
                              _hasChanged = false;
                              _minWeightIndex = 0;
                              _maxWeightIndex = 0;
                              _selectedMonthIndex = 0;
                              _selectedYearIndex = 0;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Szűrők törölve')),
                            );
                          },
                          child: const Center(
                            child: Text(
                              'Szűrő törlése',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ),
                    ] else
                      const SizedBox.shrink(),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Weight pickers
            Text(
              'weight_kg'.tr,
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
                          'min_weight'.tr,
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
                                            (maxWeight * 10).toInt() + 1,
                                          ),
                                        ),
                                    onSelectedItemChanged: (i) => setState(() {
                                      _minWeightIndex = i;
                                      if (i == 0) {
                                        _weightRange = RangeValues(
                                          0,
                                          _weightRange.end,
                                        );
                                      } else {
                                        final val = (i - 1) / 10.0;
                                        _weightRange = RangeValues(
                                          val,
                                          _weightRange.end,
                                        );
                                      }
                                      _hasChanged = true;
                                    }),
                                    children: List<Widget>.generate(
                                      (maxWeight * 10).toInt() + 1 + 1,
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
                                        if (i == 0) {
                                          return Center(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 6,
                                                    horizontal: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.surfaceColor
                                                    .withOpacity(
                                                      _opacityFor(
                                                        diff,
                                                        falloff: 6.0,
                                                        minOpacity: 0.02,
                                                      ),
                                                    ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: AppTheme.textColor
                                                      .withOpacity(
                                                        borderOpacity,
                                                      ),
                                                  width: diff == 0 ? 1.6 : 0.9,
                                                ),
                                              ),
                                              child: Transform.scale(
                                                scale: scale,
                                                child: Text(
                                                  'not_set'.tr,
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
                                        }
                                        final kg = ((i - 1) / 10.0)
                                            .toStringAsFixed(1);
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
                                _minWeightIndex == 0
                                    ? 'Min: -'
                                    : 'Min: ${((_minWeightIndex - 1) / 10.0).toStringAsFixed(1)} kg',
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
                          'max_weight'.tr,
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
                                            (maxWeight * 10).toInt() + 1,
                                          ),
                                        ),
                                    onSelectedItemChanged: (i) => setState(() {
                                      _maxWeightIndex = i;
                                      if (i == 0) {
                                        _weightRange = RangeValues(
                                          _weightRange.start,
                                          maxWeight,
                                        );
                                      } else {
                                        final val = (i - 1) / 10.0;
                                        _weightRange = RangeValues(
                                          _weightRange.start,
                                          val,
                                        );
                                      }
                                      _hasChanged = true;
                                    }),
                                    children: List<Widget>.generate(
                                      (maxWeight * 10).toInt() + 1 + 1,
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
                                        if (i == 0) {
                                          return Center(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 6,
                                                    horizontal: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.surfaceColor
                                                    .withOpacity(
                                                      _opacityFor(
                                                        diff,
                                                        falloff: 6.0,
                                                        minOpacity: 0.02,
                                                      ),
                                                    ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: AppTheme.textColor
                                                      .withOpacity(
                                                        borderOpacity,
                                                      ),
                                                  width: diff == 0 ? 1.6 : 0.9,
                                                ),
                                              ),
                                              child: Transform.scale(
                                                scale: scale,
                                                child: Text(
                                                  'not_set'.tr,
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
                                        }
                                        final kg = ((i - 1) / 10.0)
                                            .toStringAsFixed(1);
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
                                _maxWeightIndex == 0
                                    ? 'Max: -'
                                    : 'Max: ${((_maxWeightIndex - 1) / 10.0).toStringAsFixed(1)} kg',
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
              'time_interval'.tr,
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
                          'month'.tr,
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
                            _selectedMonthIndex = i + 1;
                            _hasChanged = true;
                          }),
                          // index 0 = placeholder, months 1..12
                          children: List<Widget>.generate(12 + 1, (i) {
                            final names = List<String>.generate(12, (idx) {
                              return 'month_${idx + 1}'.tr;
                            });
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
                            if (i == 0) {
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
                                    child: Text('not_set'.tr, style: style),
                                  ),
                                ),
                              );
                            }
                            final idx = i - 1;
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
                                  child: Text(names[idx], style: style),
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
                          'year'.tr,
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
                            _selectedYear = _yearStart + (i - 1);
                            _selectedYearIndex = i;
                            _hasChanged = true;
                          }),
                          // index 0 = placeholder, years start at index 1
                          children: List<Widget>.generate(
                            (DateTime.now().year - _yearStart + 1) + 1,
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
                              if (i == 0) {
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
                                        'not_set'.tr,
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
                              }
                              final yearVal = _yearStart + (i - 1);
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
                                      '$yearVal',
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
                          'start_time'.tr,
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
                                            24 * 60,
                                          ),
                                        ),
                                    onSelectedItemChanged: (i) => setState(() {
                                      _startTimeIndex = i;
                                      if (i == 0) {
                                        startTime = null;
                                      } else {
                                        final minutes = i - 1;
                                        startTime = TimeOfDay(
                                          hour: minutes ~/ 60,
                                          minute: minutes % 60,
                                        );
                                      }
                                      _hasChanged = true;
                                    }),
                                    children: List<Widget>.generate(
                                      24 * 60 + 1,
                                      (i) {
                                        final diff = (i - _startTimeIndex)
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
                                        if (i == 0) {
                                          return Center(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 6,
                                                    horizontal: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.surfaceColor
                                                    .withOpacity(
                                                      _opacityFor(
                                                        diff,
                                                        falloff: 6.0,
                                                        minOpacity: 0.02,
                                                      ),
                                                    ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: AppTheme.textColor
                                                      .withOpacity(
                                                        borderOpacity,
                                                      ),
                                                  width: diff == 0 ? 1.6 : 0.9,
                                                ),
                                              ),
                                              child: Transform.scale(
                                                scale: scale,
                                                child: Text(
                                                  'not_set'.tr,
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
                                        }
                                        final minutes = i - 1;
                                        final hh = (minutes ~/ 60)
                                            .toString()
                                            .padLeft(2, '0');
                                        final mm = (minutes % 60)
                                            .toString()
                                            .padLeft(2, '0');
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
                                                '$hh:$mm',
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
                                    ? 'start_time'.tr
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
                          'end_time'.tr,
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
                                            24 * 60,
                                          ),
                                        ),
                                    onSelectedItemChanged: (i) => setState(() {
                                      _endTimeIndex = i;
                                      if (i == 0) {
                                        endTime = null;
                                      } else {
                                        final minutes = i - 1;
                                        endTime = TimeOfDay(
                                          hour: minutes ~/ 60,
                                          minute: minutes % 60,
                                        );
                                      }
                                      _hasChanged = true;
                                    }),
                                    children: List<Widget>.generate(
                                      24 * 60 + 1,
                                      (i) {
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
                                        if (i == 0) {
                                          return Center(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 6,
                                                    horizontal: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.surfaceColor
                                                    .withOpacity(
                                                      _opacityFor(
                                                        diff,
                                                        falloff: 6.0,
                                                        minOpacity: 0.02,
                                                      ),
                                                    ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: AppTheme.textColor
                                                      .withOpacity(
                                                        borderOpacity,
                                                      ),
                                                  width: diff == 0 ? 1.6 : 0.9,
                                                ),
                                              ),
                                              child: Transform.scale(
                                                scale: scale,
                                                child: Text(
                                                  'not_set'.tr,
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
                                        }
                                        final minutes = i - 1;
                                        final hh = (minutes ~/ 60)
                                            .toString()
                                            .padLeft(2, '0');
                                        final mm = (minutes % 60)
                                            .toString()
                                            .padLeft(2, '0');
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
                                                '$hh:$mm',
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
                                    ? 'end_time'.tr
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
              'date'.tr,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            AppButton(
              backgroundColor: Colors.grey.shade900,
              onPressed: () => _selectDate(context),
              child: Text(
                selectedDate == null
                    ? 'choose_date'.tr
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
