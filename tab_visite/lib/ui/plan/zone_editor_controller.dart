import 'package:flutter/foundation.dart';

class ZoneEditorController extends ChangeNotifier {
  bool _editing = false;
  String? _selectedZoneId;

  bool get editing => _editing;
  String? get selectedZoneId => _selectedZoneId;

  void toggle() { _editing = !_editing; _selectedZoneId = null; notifyListeners(); }
  void select(String? id) { _selectedZoneId = id; notifyListeners(); }
}
