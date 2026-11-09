class ServiceError implements Exception {
  final int status;
  final String message;
  const ServiceError(this.status, this.message);
  @override
  String toString() => message;
}
