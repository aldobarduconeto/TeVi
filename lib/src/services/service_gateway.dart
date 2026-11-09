import '../models/sync_info.dart';

abstract interface class ServiceGateway {
  Future<dynamic> execute(
    String method,
    String resource, {
    Map<String, dynamic> data = const {},
    String token = '',
  });
  Future<SyncInfo> syncInfo();
  Future<void> synchronize();
  Future<void> close();
}
