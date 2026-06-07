import 'package:flutter_test/flutter_test.dart';
import 'package:leituras/viewmodels/estimador_view_model.dart';

void main() {
  group('EstimadorViewModel Validation tests', () {
    late EstimadorViewModel vm;

    setUp(() {
      vm = EstimadorViewModel();
    });

    test('rejects empty, invalid, and non 4/5 digit readings', () {
      expect(vm.validateAndAddReading(''), isNotNull);
      expect(vm.validateAndAddReading('   '), isNotNull);
      expect(vm.validateAndAddReading('12a4'), isNotNull);
      expect(vm.validateAndAddReading('123'), isNotNull);
      expect(vm.validateAndAddReading('123456'), isNotNull);
    });

    test('accepts valid 4 or 5 digit readings', () {
      expect(vm.validateAndAddReading('1234'), isNull);
      expect(vm.readings, equals([1234]));

      expect(vm.validateAndAddReading('12345'), isNull);
      expect(vm.readings, equals([1234, 12345]));
    });

    test('rejects values that are smaller than the previous reading', () {
      vm.validateAndAddReading('1000');
      expect(vm.validateAndAddReading('999'), isNotNull);
      expect(vm.readings, equals([1000]));

      expect(vm.validateAndAddReading('1000'), isNull);
      expect(vm.readings, equals([1000, 1000]));
    });

    test('respects the maximum limit of 6 readings', () {
      for (int i = 0; i < 6; i++) {
        expect(vm.validateAndAddReading((1000 + i).toString()), isNull);
      }
      expect(vm.validateAndAddReading('1006'), isNotNull);
      expect(vm.readings.length, equals(6));
    });

    test('removes readings correctly and updates calculations', () {
      vm.loadReadings([1500, 1800, 2200]);
      vm.removeReadingAt(1);
      expect(vm.readings, equals([1500, 2200]));
    });
  });

  group('EstimadorViewModel Calculation tests', () {
    late EstimadorViewModel vm;

    setUp(() {
      vm = EstimadorViewModel();
    });

    test('returns null for calculations when less than 2 readings exist', () {
      expect(vm.averageConsumption, isNull);
      expect(vm.estimatedNextReading, isNull);

      vm.validateAndAddReading('1000');
      expect(vm.averageConsumption, isNull);
      expect(vm.estimatedNextReading, isNull);
    });

    test('calculates correct average and estimated next reading', () {
      // Let's use the example: [150, 180, 220]
      // In Dart, readings must be 4 or 5 digits, so we add 1000 to all: [1150, 1180, 1220]
      // Intervals: (1180 - 1150 = 30) and (1220 - 1180 = 40)
      // Average: (30 + 40) / 2 = 35.0
      // Next reading: 1220 + 35 = 1255
      vm.validateAndAddReading('1150');
      vm.validateAndAddReading('1180');
      vm.validateAndAddReading('1220');

      expect(vm.averageConsumption, equals(35.0));
      expect(vm.estimatedNextReading, equals(1255));
    });

    test('handles equal readings gracefully', () {
      vm.validateAndAddReading('1000');
      vm.validateAndAddReading('1000');
      expect(vm.averageConsumption, equals(0.0));
      expect(vm.estimatedNextReading, equals(1000));
    });

    test('detects consumption anomaly/spike correctly', () {
      // Scenario A: History [1150, 1165, 1183, 1195] -> consumptions [15, 18, 12] (stable)
      // New reading [1285] -> consumption [90] (spike)
      vm.loadReadings([1150, 1165, 1183, 1195, 1285]);
      expect(vm.hasConsumptionAnomaly, isTrue);

      // Scenario B: History [1000, 1080, 1090, 1185, 1200] -> consumptions [80, 10, 95, 15] (high variance)
      // New reading [1290] -> consumption [90] (costume a variacao grande)
      vm.clear();
      vm.loadReadings([1000, 1080, 1090, 1185, 1200, 1290]);
      expect(vm.hasConsumptionAnomaly, isFalse);

      // Scenario C: History [1000, 1010, 1022] -> consumptions [10, 12] (stable)
      // New reading [1037] -> consumption [15] (small absolute difference)
      vm.clear();
      vm.loadReadings([1000, 1010, 1022, 1037]);
      expect(vm.hasConsumptionAnomaly, isFalse);

      // Scenario D: History [1000, 1010, 1030, 1060, 1110] -> consumptions [10, 20, 30, 50] (increasing, stable deviation)
      // New reading [1290] -> consumption [180] (spike)
      vm.clear();
      vm.loadReadings([1000, 1010, 1030, 1060, 1110, 1290]);
      expect(vm.hasConsumptionAnomaly, isTrue);
    });
  });
}
