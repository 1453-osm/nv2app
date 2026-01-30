/// Operasyon sonuçlarını temsil eden sealed class.
/// Railway-oriented programming için Success/Failure pattern.
sealed class Result<T> {
  const Result();

  /// Başarılı veya başarısız duruma göre callback çalıştırır.
  R when<R>({
    required R Function(T data) success,
    required R Function(AppException error) failure,
  });

  /// Başarılı ise veriyi döndürür, değilse null.
  T? getOrNull();

  /// Başarılı ise veriyi döndürür, değilse default değer.
  T getOrElse(T defaultValue);

  /// Başarılı ise veriyi döndürür, değilse exception fırlatır.
  T getOrThrow();

  /// Başarılı mı?
  bool get isSuccess;

  /// Başarısız mı?
  bool get isFailure;

  /// Veriyi dönüştürür (map).
  Result<R> map<R>(R Function(T data) transform);

  /// Veriyi async dönüştürür (flatMap).
  Future<Result<R>> flatMap<R>(Future<Result<R>> Function(T data) transform);
}

/// Başarılı sonuç
class Success<T> extends Result<T> {
  final T data;

  const Success(this.data);

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(AppException error) failure,
  }) =>
      success(data);

  @override
  T? getOrNull() => data;

  @override
  T getOrElse(T defaultValue) => data;

  @override
  T getOrThrow() => data;

  @override
  bool get isSuccess => true;

  @override
  bool get isFailure => false;

  @override
  Result<R> map<R>(R Function(T data) transform) => Success(transform(data));

  @override
  Future<Result<R>> flatMap<R>(
    Future<Result<R>> Function(T data) transform,
  ) =>
      transform(data);

  @override
  String toString() => 'Success($data)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> && runtimeType == other.runtimeType && data == other.data;

  @override
  int get hashCode => data.hashCode;
}

/// Başarısız sonuç
class Failure<T> extends Result<T> {
  final AppException error;

  const Failure(this.error);

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(AppException error) failure,
  }) =>
      failure(error);

  @override
  T? getOrNull() => null;

  @override
  T getOrElse(T defaultValue) => defaultValue;

  @override
  T getOrThrow() => throw error;

  @override
  bool get isSuccess => false;

  @override
  bool get isFailure => true;

  @override
  Result<R> map<R>(R Function(T data) transform) => Failure<R>(error);

  @override
  Future<Result<R>> flatMap<R>(
    Future<Result<R>> Function(T data) transform,
  ) async =>
      Failure<R>(error);

  @override
  String toString() => 'Failure($error)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T> && runtimeType == other.runtimeType && error == other.error;

  @override
  int get hashCode => error.hashCode;
}

/// Uygulama genelinde kullanılan exception sınıfı
class AppException implements Exception {
  final String message;
  final String? code;
  final Object? originalError;
  final StackTrace? stackTrace;

  const AppException({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  /// Genel hata
  factory AppException.general(String message, [Object? error, StackTrace? stackTrace]) {
    return AppException(
      message: message,
      code: 'GENERAL_ERROR',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Network hatası
  factory AppException.network(String message, [Object? error, StackTrace? stackTrace]) {
    return AppException(
      message: message,
      code: 'NETWORK_ERROR',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Parse hatası
  factory AppException.parse(String message, [Object? error, StackTrace? stackTrace]) {
    return AppException(
      message: message,
      code: 'PARSE_ERROR',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Storage hatası
  factory AppException.storage(String message, [Object? error, StackTrace? stackTrace]) {
    return AppException(
      message: message,
      code: 'STORAGE_ERROR',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// İzin hatası
  factory AppException.permission(String message, [Object? error, StackTrace? stackTrace]) {
    return AppException(
      message: message,
      code: 'PERMISSION_ERROR',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Konum hatası
  factory AppException.location(String message, [Object? error, StackTrace? stackTrace]) {
    return AppException(
      message: message,
      code: 'LOCATION_ERROR',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Timeout hatası
  factory AppException.timeout(String message, [Object? error, StackTrace? stackTrace]) {
    return AppException(
      message: message,
      code: 'TIMEOUT_ERROR',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Validation hatası
  factory AppException.validation(String message, [Object? error, StackTrace? stackTrace]) {
    return AppException(
      message: message,
      code: 'VALIDATION_ERROR',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  @override
  String toString() => 'AppException[$code]: $message';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppException &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          code == other.code;

  @override
  int get hashCode => Object.hash(message, code);
}

/// Result helper extensions
extension ResultExtensions<T> on Future<T> {
  /// Future'ı Result'a çevirir
  Future<Result<T>> toResult() async {
    try {
      final data = await this;
      return Success(data);
    } catch (e, stackTrace) {
      return Failure(AppException.general(
        e.toString(),
        e,
        stackTrace,
      ));
    }
  }
}

/// Try-catch wrapper
Future<Result<T>> runCatching<T>(Future<T> Function() block) async {
  try {
    final data = await block();
    return Success(data);
  } catch (e, stackTrace) {
    return Failure(AppException.general(
      e.toString(),
      e,
      stackTrace,
    ));
  }
}
