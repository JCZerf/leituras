import 'package:flutter/foundation.dart';

class EstimadorViewModel extends ChangeNotifier {
  final List<int> _readings = [];

  List<int> get readings => List.unmodifiable(_readings);

  /// Validates and adds a reading value.
  /// Returns an error message if invalid, or null if successfully added.
  String? validateAndAddReading(String textValue) {
    final cleanText = textValue.trim();
    if (cleanText.isEmpty) {
      return 'Digite um valor.';
    }

    final value = int.tryParse(cleanText);
    if (value == null) {
      return 'Digite um número válido.';
    }

    if (cleanText.length != 4 && cleanText.length != 5) {
      return 'A leitura deve ter 4 ou 5 dígitos.';
    }

    if (_readings.length >= 6) {
      return 'O limite é de no máximo 6 leituras.';
    }

    if (_readings.isNotEmpty && value < _readings.last) {
      return 'A nova leitura deve ser maior ou igual à anterior (${_readings.last}).';
    }

    _readings.add(value);
    notifyListeners();
    return null;
  }

  /// Pre-populates the estimator with existing values (max 6).
  void loadReadings(List<int> initialValues) {
    _readings.clear();
    _readings.addAll(initialValues.take(6));
    notifyListeners();
  }

  /// Removes a reading at a specific index.
  void removeReadingAt(int index) {
    if (index >= 0 && index < _readings.length) {
      _readings.removeAt(index);
      notifyListeners();
    }
  }

  /// Clears all readings.
  void clear() {
    _readings.clear();
    notifyListeners();
  }

  /// Calculates individual consumption differences between consecutive periods.
  List<int> get individualConsumptions {
    final list = <int>[];
    for (int i = 0; i < _readings.length - 1; i++) {
      list.add(_readings[i + 1] - _readings[i]);
    }
    return list;
  }

  /// Returns the average consumption per period.
  double? get averageConsumption {
    if (_readings.length < 2) return null;
    final consumptions = individualConsumptions;
    if (consumptions.isEmpty) return 0.0;
    final sum = consumptions.fold<int>(0, (prev, element) => prev + element);
    return sum / consumptions.length;
  }

  /// Estimates the next reading.
  int? get estimatedNextReading {
    final avg = averageConsumption;
    if (avg == null || _readings.isEmpty) return null;
    return (_readings.last + avg).round();
  }

  /// Returns true if the most recent period exhibits an abnormal consumption spike
  /// compared to historical readings, accounting for historical variance.
  bool get hasConsumptionAnomaly {
    final consumptions = individualConsumptions;
    if (consumptions.length < 2) return false;

    final hist = consumptions.sublist(0, consumptions.length - 1);
    final newest = consumptions.last;

    final sumHist = hist.fold<int>(0, (prev, e) => prev + e);
    final meanHist = sumHist / hist.length;

    int maxHist = hist.first;
    for (final val in hist) {
      if (val > maxHist) maxHist = val;
    }

    double sumDev = 0;
    for (final val in hist) {
      sumDev += (val - meanHist).abs();
    }
    final meanAbsoluteDeviation = sumDev / hist.length;

    // Use a minimum deviation floor to avoid false alerts on tiny fluctuations (e.g. going from 10 to 12)
    final thresholdDev = meanAbsoluteDeviation > 10.0 ? meanAbsoluteDeviation : 10.0;

    final isLargerThanMax = newest > maxHist;
    final exceedsExpectedRange = newest > meanHist + 3 * thresholdDev;
    final hasSignificantAbsoluteDiff = (newest - meanHist) > 30;

    return isLargerThanMax && exceedsExpectedRange && hasSignificantAbsoluteDiff;
  }
}
