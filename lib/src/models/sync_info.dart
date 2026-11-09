class SyncInfo {
  const SyncInfo({
    required this.pending,
    required this.conflicts,
    this.provider,
    this.lastSuccess,
  });
  final int pending, conflicts;
  final String? provider;
  final DateTime? lastSuccess;
  bool get configured => provider != null;
}
