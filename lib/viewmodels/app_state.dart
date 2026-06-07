import 'package:flutter/foundation.dart';

import '../models/grupo.dart';

class AppState extends ChangeNotifier {
  int currentTabIndex = 0;
  Grupo? selectedGroup;

  int? get selectedGroupId => selectedGroup?.id;

  void selectTab(int index) {
    if (currentTabIndex == index) {
      return;
    }
    currentTabIndex = index;
    notifyListeners();
  }

  void selectGroup(Grupo grupo) {
    selectedGroup = grupo;
    currentTabIndex = 1;
    notifyListeners();
  }
}
