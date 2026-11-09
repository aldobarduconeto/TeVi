import 'json.dart';

const defaults = <String, dynamic>{
  'timezone_offset': -180,
  'discovery': false,
  'invisible': false,
  'workout_mode': false,
  'workout_activity': 'Musculação',
  'sound_effects': true,
  'haptic_feedback': true,
  'start_hour': 0,
  'end_hour': 24,
  'start_minute': 0,
  'end_minute': 0,
  'min_age': 18,
  'max_age': 80,
  'interest': '',
  'period_days': 7,
  'notify_matches': true,
  'notify_messages': true,
  'notify_encounters': false,
  'notify_workout': true,
  'ble_proximity': true,
  'quiet_start': 22,
  'quiet_end': 8,
  'quiet_start_minute': 0,
  'quiet_end_minute': 0,
  'read_receipts': false,
  'text_scale': 100,
  'reduce_motion': false,
  'liquid_glass_blur': true,
  'theme_mode': 'system',
};

Json preferences(Json user) => {...defaults, ...Json.from(user['settings'])};

/// Device appearance is shared by startup, account settings and logout.
Json appearancePreferences(Map<dynamic, dynamic> settings) => {
  for (final key in const [
    'theme_mode',
    'text_scale',
    'reduce_motion',
    'liquid_glass_blur',
    'sound_effects',
    'haptic_feedback',
  ])
    if (settings.containsKey(key)) key: settings[key],
};

/// Minute-accurate windows, including ranges crossing midnight.
bool timeWindowContains(
  int minute,
  int start,
  int end, {
  bool fullDayWhenEqual = true,
}) {
  if (start == end) return fullDayWhenEqual;
  return start < end
      ? minute >= start && minute < end
      : minute >= start || minute < end;
}
