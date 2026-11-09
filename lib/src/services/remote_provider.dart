import '../models/local_change.dart';
import '../models/remote_receipt.dart';

/// Implement this adapter only when a provider is selected. It must authenticate
/// each actor, enforce ownership/roles and deduplicate by LocalChange.id.
abstract interface class RemoteProvider {
  String get name;
  bool canSyncActor(String actor);
  Future<RemoteReceipt> push(LocalChange change);
}
