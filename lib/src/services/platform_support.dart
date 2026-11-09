import 'package:flutter/foundation.dart';

import '../models/platform_capabilities.dart';

class PlatformSupport {
  static PlatformCapabilities get current => PlatformCapabilities(
    target: defaultTargetPlatform,
    web: kIsWeb,
  );
}
