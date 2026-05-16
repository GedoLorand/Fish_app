import 'dart:async';

class FilterBus {
  FilterBus._private();
  static final FilterBus instance = FilterBus._private();

  final StreamController<Map<String, dynamic>?> _ctrl =
      StreamController.broadcast();

  Stream<Map<String, dynamic>?> get stream => _ctrl.stream;

  void publish(Map<String, dynamic>? filter) => _ctrl.add(filter);

  void dispose() {
    _ctrl.close();
  }
}
