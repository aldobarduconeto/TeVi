import '../../models/json.dart';
import '../../models/service_error.dart';
import '../../models/user_settings.dart';

import 'dart:convert';
import 'dart:math';

import 'security.dart';

String field(Json data, String key, {int max = 1000, bool required = true}) {
  final value = data[key] ?? '';
  if (value is! String ||
      value.trim().length > max ||
      (required && value.trim().isEmpty)) {
    throw ServiceError(400, 'Campo inválido: $key');
  }
  return value.trim();
}

/// Passwords are never trimmed: spaces are part of the user's credential.
String passwordField(Json data, String key) {
  final value = data[key];
  if (value is! String || value.isEmpty || value.length > 128) {
    throw const ServiceError(400, 'Senha inválida. Use até 128 caracteres.');
  }
  return value;
}

DateTime birthDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) {
    throw const ServiceError(400, 'Data de nascimento inválida.');
  }
  final y = int.parse(match[1]!),
      m = int.parse(match[2]!),
      d = int.parse(match[3]!);
  final date = DateTime.utc(y, m, d);
  if (date.year != y || date.month != m || date.day != d) {
    throw const ServiceError(400, 'Data de nascimento inválida.');
  }
  return date;
}

int age(String value, DateTime now) {
  final d = birthDate(value);
  return now.year -
      d.year -
      (now.month < d.month || (now.month == d.month && now.day < d.day)
          ? 1
          : 0);
}

Json publicProfile(Json user, DateTime now) => {
  'id': user['id'],
  'name': user['name'],
  'age': age(user['birthdate'], now),
  'bio': user['bio'] ?? '',
  'interests': List<String>.from(user['interests'] ?? []),
  'goal': user['goal'] ?? '',
  'relationship_status': user['relationship_status'] ?? '',
  'workout_goal': user['workout_goal'] ?? '',
  'workout_active': user['workout_active'] == 1,
  'photo': user['photo'] ?? '',
  'photos': (user['photos'] as List? ?? []).isNotEmpty
      ? List<String>.from(user['photos'])
      : [if (user['photo'] != null && user['photo'] != '') user['photo']],
  'verified': user['verified'] == 1,
  'socials': user['socials'] is Map
      ? Map<String, dynamic>.from(user['socials'])
      : <String, dynamic>{},
};

bool isProfileCompleted(Json user) {
  final photo = (user['photo'] as String?)?.trim() ?? '';
  final name = (user['name'] as String?)?.trim() ?? '';
  final bio = (user['bio'] as String?)?.trim() ?? '';
  final relationship = (user['relationship_status'] as String?)?.trim() ?? '';
  final goal = (user['goal'] as String?)?.trim() ?? '';
  return photo.isNotEmpty &&
      name.isNotEmpty &&
      bio.length >= 10 &&
      relationship.isNotEmpty &&
      goal.isNotEmpty;
}
(double, double) coordinates(Json data) {
  final lat = data['lat'], lon = data['lon'];
  if (lat is! num ||
      lon is! num ||
      !lat.isFinite ||
      !lon.isFinite ||
      lat < -90 ||
      lat > 90 ||
      lon < -180 ||
      lon > 180) {
    throw const ServiceError(400, 'Coordenadas inválidas.');
  }
  return (lat.toDouble(), lon.toDouble());
}

double distance(num a, num b, num c, num d) {
  const r = pi / 180;
  final sinLat = sin((c - a) * r * 0.5);
  final sinLon = sin((d - b) * r * 0.5);
  final x = (sinLat * sinLat) + cos(a * r) * cos(c * r) * (sinLon * sinLon);
  return 6371000 * 2 * asin(min(1.0, sqrt(x)));
}

String validateMedia(dynamic value, {bool audio = false}) {
  if (value is! String || !value.contains(',')) {
    throw const ServiceError(400, 'Arquivo inválido.');
  }
  final split = value.indexOf(',');
  final header = value.substring(0, split);
  final types = audio
      ? ['audio/mp4', 'audio/wav', 'audio/webm', 'audio/mpeg']
      : ['image/jpeg', 'image/png', 'image/webp'];
  if (!types.any((t) => header == 'data:$t;base64')) {
    throw const ServiceError(400, 'Formato não aceito.');
  }
  try {
    final bytes = base64.decode(value.substring(split + 1));
    if (bytes.isEmpty || bytes.length > 3 * 1024 * 1024) {
      throw const ServiceError(400, 'Arquivo deve ter até 3 MB.');
    }
    bool starts(List<int> prefix, [int offset = 0]) =>
        bytes.length >= offset + prefix.length &&
        List.generate(
          prefix.length,
          (i) => bytes[offset + i] == prefix[i],
        ).every((v) => v);
    if (!audio &&
        !starts([255, 216, 255]) &&
        !starts([137, 80, 78, 71, 13, 10, 26, 10]) &&
        !(starts(ascii.encode('RIFF')) && starts(ascii.encode('WEBP'), 8))) {
      throw const ServiceError(400, 'Imagem inválida.');
    }
  } on FormatException {
    throw const ServiceError(400, 'Arquivo inválido.');
  }
  return value;
}

/// In-memory domain collections. The gateway persists one versioned JSON
/// document through SharedPreferencesAsync after each successful operation.
class ServiceStore {
  ServiceStore({DateTime Function()? clock}) : clock = clock ?? DateTime.now;
  final DateTime Function() clock;
  double get now => clock().millisecondsSinceEpoch / 1000;
  Map<String, List<Json>> _tables = {};
  String? _deviceSession;
  String? get deviceSession => _deviceSession;
  set deviceSession(String? value) {
    if (_deviceSession != value) {
      _deviceSession = value;
      isDirty = true;
    }
  }
  bool isDirty = false;
  void clearDirty() => isDirty = false;
  void markDirty() => isDirty = true;
  String? _transaction;

  // Fast O(1) indexed lookups for high-throughput queries
  final Map<String, Map<String, Json>> _primaryIndex = {};
  final Set<String> _blocksSet = {};
  final Set<String> _hiddenSet = {};
  final Map<String, String> _likesMap = {};

  void _rebuildIndexes() {
    _primaryIndex.clear();
    _blocksSet.clear();
    _hiddenSet.clear();
    _likesMap.clear();

    for (final table in ['users', 'sessions', 'matches']) {
      final key = keys[table]!.first;
      final map = <String, Json>{};
      for (final row in _tables[table] ?? const []) {
        final k = row[key];
        if (k is String) map[k] = row;
      }
      _primaryIndex[table] = map;
    }

    for (final b in _tables['blocks'] ?? const []) {
      final a = b['a'], other = b['b'];
      if (a is String && other is String) {
        _blocksSet.add('$a:$other');
        _blocksSet.add('$other:$a');
      }
    }

    for (final h in _tables['hidden'] ?? const []) {
      final a = h['a'], other = h['b'];
      if (a is String && other is String) {
        _hiddenSet.add('$a:$other');
      }
    }

    for (final l in _tables['likes'] ?? const []) {
      final a = l['a'], b = l['b'], kind = l['kind'];
      if (a is String && b is String) {
        _likesMap['$a:$b'] = (kind ?? '').toString();
      }
    }
  }
  static const keys = <String, List<String>>{
    'users': ['id'],
    'sessions': ['token'],
    'encounters': ['id'],
    'presence': ['user_id'],
    'ble_tokens': ['token'],
    'likes': ['a', 'b'],
    'hidden': ['a', 'b'],
    'blocks': ['a', 'b'],
    'matches': ['id'],
    'messages': ['id'],
    'calls': ['id'],
    'signals': ['id'],
    'reports': ['id'],
    'events': ['id'],
    'attendance': ['user_id', 'event_id'],
    'notifications': ['id'],
    'zones': ['id'],
    'verification': ['id'],
    'tickets': ['id'],
    'invites': ['code'],
    'audit': ['id'],
    'rate_limits': ['key'],
    'sync_queue': ['id'],
    'app_preferences': ['key'],
  };
  String snapshot() => jsonEncode({
    'version': 1,
    'device_session': deviceSession,
    'collections': _tables,
  });
  void restore(String document) {
    final data = jsonDecode(document);
    if (data is! Map ||
        data['version'] != 1 ||
        data['collections'] is! Map ||
        (data['device_session'] != null && data['device_session'] is! String)) {
      throw const FormatException('Formato de armazenamento incompatível.');
    }
    final collections = <String, List<Json>>{};
    for (final entry in (data['collections'] as Map).entries) {
      if (!keys.containsKey(entry.key) || entry.value is! List) {
        throw const FormatException('Coleção inválida.');
      }
      collections[entry.key as String] = (entry.value as List).map((value) {
        if (value is! Map ||
            keys[entry.key]!.any((key) => value[key] == null)) {
          throw const FormatException('Registro inválido.');
        }
        return Json.from(value);
      }).toList();
    }
    _tables = collections;
    _deviceSession = data['device_session'];
    _rebuildIndexes();
  }

  void begin() {
    if (_transaction != null) throw StateError('Operação já iniciada.');
    _transaction = snapshot();
  }

  void commit() => _transaction = null;
  void rollback() {
    final previous = _transaction;
    _transaction = null;
    if (previous != null) {
      restore(previous);
    } else {
      _rebuildIndexes();
    }
  }

  List<Json> _rows(String table) {
    if (!keys.containsKey(table))
      throw ArgumentError.value(table, 'collection');
    return _tables[table] ?? const [];
  }

  List<Json> select(
    String table, {
    bool Function(Json)? where,
    String? orderBy,
    bool descending = false,
    int? limit,
    List<String>? fields,
  }) {
    var rows = _rows(table).where(where ?? (_) => true).toList();
    if (orderBy != null) {
      // Retain insertion order for equal timestamps (e.g. consecutive messages).
      final positions = {for (var i = 0; i < rows.length; i++) rows[i]: i};
      rows.sort((a, b) {
        final dynamic left = a[orderBy], right = b[orderBy];
        final result = (left as Comparable).compareTo(right);
        return result == 0
            ? positions[a]!.compareTo(positions[b]!)
            : descending
            ? -result
            : result;
      });
    }
    if (limit != null) rows = rows.take(limit).toList();
    return rows
        .map(
          (r) => fields == null
              ? Json.from(r)
              : {for (final field in fields) field: r[field]},
        )
        .toList();
  }

  int count(String table, {bool Function(Json)? where}) =>
      _rows(table).where(where ?? (_) => true).length;

  Json? find(
    String table, {
    bool Function(Json)? where,
    String? orderBy,
    bool descending = false,
    int? limit,
    List<String>? fields,
  }) {
    if (orderBy != null) {
      return select(
        table,
        where: where,
        orderBy: orderBy,
        descending: descending,
        limit: 1,
        fields: fields,
      ).firstOrNull;
    }
    for (final row in _rows(table)) {
      if (where == null || where(row)) {
        return fields == null
            ? Json.from(row)
            : {for (final field in fields) field: row[field]};
      }
    }
    return null;
  }

  void insert(
    String table,
    Json value, {
    bool replace = false,
    bool ignore = false,
  }) {
    final primary = keys[table];
    if (primary == null || primary.any((key) => value[key] == null)) {
      throw ArgumentError('Identificador inválido para $table.');
    }
    final rows = _tables.putIfAbsent(table, () => []);
    final existing = rows.indexWhere(
      (r) => primary.every((k) => r[k] == value[k]),
    );
    if (existing >= 0 && ignore) return;
    if (existing >= 0 && !replace) throw StateError('Registro duplicado.');
    if (table == 'users' &&
        rows.any((r) => r['email'] == value['email'] && r['id'] != value['id']))
      throw StateError('E-mail duplicado.');
    if (table == 'matches' &&
        rows.any(
          (r) =>
              r['a'] == value['a'] &&
              r['b'] == value['b'] &&
              r['id'] != value['id'],
        )) {
      throw StateError('Conversa duplicada.');
    }
    final row = <String, dynamic>{
      if (table == 'users') ...{
        'photo': '',
        'photos': <String>[],
        'socials': <String, dynamic>{},
        'role': 'user',
        'suspended': 0,
        'verified': 0,
      },
      ...value,
    };
    if (existing >= 0) {
      rows[existing] = row;
    } else {
      rows.add(row);
    }
    isDirty = true;
    _rebuildIndexes();
  }

  void update(
    String table,
    bool Function(Json) where,
    Json Function(Json) changes,
  ) {
    for (final row in _rows(table)) {
      if (where(row)) {
        row.addAll(changes(Json.from(row)));
        isDirty = true;
      }
    }
    _rebuildIndexes();
  }

  void delete(String table, bool Function(Json) where) {
    final removed = ['users', 'matches', 'events'].contains(table)
        ? _rows(table).where(where).toList()
        : const <Json>[];
    _tables[table]?.removeWhere(where);
    isDirty = true;
    if (table == 'users') {
      for (final user in removed) {
        final id = user['id'];
        for (final child in [
          'sessions',
          'presence',
          'attendance',
          'notifications',
          'zones',
          'verification',
          'tickets',
          'invites',
        ]) {
          delete(child, (r) => r['user_id'] == id);
        }
        for (final child in [
          'encounters',
          'likes',
          'hidden',
          'blocks',
          'matches',
        ]) {
          delete(child, (r) => r['a'] == id || r['b'] == id);
        }
        for (final child in ['messages', 'calls']) {
          delete(child, (r) => r['sender'] == id);
        }
        delete('reports', (r) => r['reporter'] == id || r['target'] == id);
        delete('sync_queue', (r) => r['actor'] == id);
      }
    }
    if (table == 'matches') {
      final ids = removed.map((r) => r['id']).toSet();
      for (final child in ['messages', 'calls']) {
        delete(child, (r) => ids.contains(r['match_id']));
      }
    }
    if (table == 'events') {
      final ids = removed.map((r) => r['id']).toSet();
      delete('attendance', (r) => ids.contains(r['event_id']));
    }
    _rebuildIndexes();
  }

  bool blocked(String a, String b) =>
      _blocksSet.contains('$a:$b') || _blocksSet.contains('$b:$a');

  bool hidden(String a, String b) => _hiddenSet.contains('$a:$b');

  String liked(String a, String b) => _likesMap['$a:$b'] ?? '';

  Json? user(String id) =>
      _primaryIndex['users']?[id] ?? find('users', where: (r) => r['id'] == id);
  bool discoverable(Json user) {
    final s = preferences(user);
    final local = clock().toUtc().add(Duration(minutes: s['timezone_offset']));
    return s['discovery'] == true &&
        s['invisible'] != true &&
        user['suspended'] == 0 &&
        timeWindowContains(
          local.hour * 60 + local.minute,
          s['start_hour'] * 60 + s['start_minute'],
          s['end_hour'] * 60 + s['end_minute'],
        );
  }

  void limit(String key, int maximum, int seconds) {
    final row = find('rate_limits', where: (r) => r['key'] == key);
    if (row != null && row['until'] > now && row['count'] >= maximum) {
      throw const ServiceError(
        429,
        'Muitas tentativas. Aguarde para tentar novamente.',
      );
    }
    final active = row != null && row['until'] > now;
    insert('rate_limits', {
      'key': key,
      'count': active ? row['count'] + 1 : 1,
      'until': active ? row['until'] : now + seconds,
    }, replace: true);
  }

  void notify(String id, String title, String body, String kind) {
    final recipient = user(id);
    if (recipient != null && preferences(recipient)['notify_$kind'] != false) {
      insert('notifications', {
        'id': randomToken(16),
        'user_id': id,
        'title': title,
        'body': body,
        'kind': kind,
        'created': now,
        'seen': 0,
      });
    }
  }

  Json match(String me, String id) {
    final m = find(
      'matches',
      where: (r) =>
          r['id'] == id && r['active'] == 1 && (r['a'] == me || r['b'] == me),
    );
    if (m == null || blocked(m['a'], m['b'])) {
      throw const ServiceError(403, 'É necessário um match ativo.');
    }
    final other = user(m['a'] == me ? m['b'] : m['a']);
    if (other == null || other['suspended'] == 1) {
      throw const ServiceError(403, 'Conversa indisponível.');
    }
    return m;
  }

  void clean() {
    for (final (table, column, cutoff) in [
      ('encounters', 'created', now - 7 * 86400),
      ('presence', 'created', now - 300),
      ('sessions', 'expires', now),
      ('invites', 'expires', now),
      ('notifications', 'created', now - 30 * 86400),
      ('rate_limits', 'until', now),
      ('attendance', 'expires', now),
    ]) {
      delete(table, (r) => r[column] < cutoff);
    }
    update(
      'calls',
      (r) => r['state'] == 'pending' && r['created'] < now - 120,
      (_) => {'state': 'expired'},
    );
    if (deviceSession != null &&
        find(
              'sessions',
              where: (r) => r['token'] == digestToken(deviceSession!),
            ) ==
            null)
      deviceSession = null;
  }

  bool addEncounter(
    String first,
    String second,
    String region, {
    int delay = 900,
    bool bleCertified = false,
  }) {
    final pair = [first, second]..sort();
    final existing = find(
      'encounters',
      where: (r) =>
          r['a'] == pair[0] &&
          r['b'] == pair[1] &&
          r['created'] > now - 21600,
    );
    if (existing != null) {
      if (bleCertified && existing['ble_certified'] != 1) {
        update(
          'encounters',
          (r) => r['id'] == existing['id'],
          (r) => {'ble_certified': 1},
        );
      }
      return false;
    }
    insert('encounters', {
      'id': randomToken(16),
      'a': pair[0],
      'b': pair[1],
      'region': region,
      'created': now,
      'visible': now + delay,
      'ble_certified': bleCertified ? 1 : 0,
    });
    return true;
  }
}
