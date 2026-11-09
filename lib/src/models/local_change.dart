import 'json.dart';

class LocalChange {
  const LocalChange({
    required this.id,
    required this.actor,
    required this.method,
    required this.resource,
    required this.payload,
    required this.created,
  });
  final String id, actor, method, resource;
  final Map<String, dynamic> payload;
  final double created;
  factory LocalChange.fromRow(Json row) => LocalChange(
    id: row['id'],
    actor: row['actor'],
    method: row['method'],
    resource: row['resource'],
    payload: Map<String, dynamic>.from(row['payload']),
    created: (row['created'] as num).toDouble(),
  );
}
