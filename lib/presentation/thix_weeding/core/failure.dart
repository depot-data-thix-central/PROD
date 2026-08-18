// lib/presentation/thix_weeding/core/failure.dart
class Failure implements Exception {
  final String message;
  const Failure(this.message);
  @override
  String toString() => message;
}
