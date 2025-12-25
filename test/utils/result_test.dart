import 'package:flutter_test/flutter_test.dart';
import 'package:nv2/utils/result.dart';

void main() {
  group('Success', () {
    test('when calls success callback', () {
      final result = Success<int>(42);

      final value = result.when(
        success: (data) => 'Success: $data',
        failure: (error) => 'Failure: ${error.message}',
      );

      expect(value, 'Success: 42');
    });

    test('getOrNull returns data', () {
      final result = Success<int>(42);
      expect(result.getOrNull(), 42);
    });

    test('getOrElse returns data', () {
      final result = Success<int>(42);
      expect(result.getOrElse(0), 42);
    });

    test('getOrThrow returns data', () {
      final result = Success<int>(42);
      expect(result.getOrThrow(), 42);
    });

    test('isSuccess is true', () {
      final result = Success<int>(42);
      expect(result.isSuccess, true);
      expect(result.isFailure, false);
    });

    test('map transforms data', () {
      final result = Success<int>(42);
      final mapped = result.map((data) => data * 2);
      expect(mapped.getOrNull(), 84);
    });
  });

  group('Failure', () {
    test('when calls failure callback', () {
      final result = Failure<int>(AppException.general('Test error'));

      final value = result.when(
        success: (data) => 'Success: $data',
        failure: (error) => 'Failure: ${error.message}',
      );

      expect(value, 'Failure: Test error');
    });

    test('getOrNull returns null', () {
      final result = Failure<int>(AppException.general('Test error'));
      expect(result.getOrNull(), null);
    });

    test('getOrElse returns default value', () {
      final result = Failure<int>(AppException.general('Test error'));
      expect(result.getOrElse(0), 0);
    });

    test('getOrThrow throws exception', () {
      final result = Failure<int>(AppException.general('Test error'));
      expect(() => result.getOrThrow(), throwsA(isA<AppException>()));
    });

    test('isFailure is true', () {
      final result = Failure<int>(AppException.general('Test error'));
      expect(result.isSuccess, false);
      expect(result.isFailure, true);
    });

    test('map propagates failure', () {
      final result = Failure<int>(AppException.general('Test error'));
      final mapped = result.map((data) => data * 2);
      expect(mapped.isFailure, true);
    });
  });

  group('AppException', () {
    test('general creates exception with correct code', () {
      final exception = AppException.general('Test message');
      expect(exception.code, 'GENERAL_ERROR');
      expect(exception.message, 'Test message');
    });

    test('network creates exception with correct code', () {
      final exception = AppException.network('Network failed');
      expect(exception.code, 'NETWORK_ERROR');
    });

    test('parse creates exception with correct code', () {
      final exception = AppException.parse('Parse failed');
      expect(exception.code, 'PARSE_ERROR');
    });

    test('storage creates exception with correct code', () {
      final exception = AppException.storage('Storage failed');
      expect(exception.code, 'STORAGE_ERROR');
    });

    test('permission creates exception with correct code', () {
      final exception = AppException.permission('Permission denied');
      expect(exception.code, 'PERMISSION_ERROR');
    });

    test('location creates exception with correct code', () {
      final exception = AppException.location('Location unavailable');
      expect(exception.code, 'LOCATION_ERROR');
    });

    test('timeout creates exception with correct code', () {
      final exception = AppException.timeout('Request timed out');
      expect(exception.code, 'TIMEOUT_ERROR');
    });

    test('validation creates exception with correct code', () {
      final exception = AppException.validation('Invalid data');
      expect(exception.code, 'VALIDATION_ERROR');
    });

    test('equality works correctly', () {
      final e1 = AppException.general('Test');
      final e2 = AppException.general('Test');
      expect(e1, equals(e2));
    });
  });

  group('runCatching', () {
    test('returns Success when block succeeds', () async {
      final result = await runCatching(() async => 42);
      expect(result.isSuccess, true);
      expect(result.getOrNull(), 42);
    });

    test('returns Failure when block throws', () async {
      final result = await runCatching<int>(() async {
        throw Exception('Test error');
      });
      expect(result.isFailure, true);
    });
  });

  group('Future.toResult extension', () {
    test('converts successful Future to Success', () async {
      final result = await Future.value(42).toResult();
      expect(result.isSuccess, true);
      expect(result.getOrNull(), 42);
    });

    test('converts failed Future to Failure', () async {
      final result = await Future<int>.error(Exception('Test error')).toResult();
      expect(result.isFailure, true);
    });
  });
}
