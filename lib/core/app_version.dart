import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'logging/app_log.dart';

/// "2.0.0 (46)": the version as the new design shows it on Splash, Profile
/// and My account.
String formatAppVersion(String version, String build) =>
    build.isEmpty ? version : '$version ($build)';

/// The app's real version, read from the installed app. Null when the phone
/// cannot say, so screens just leave the line out.
final FutureProvider<String?> appVersionProvider = FutureProvider<String?>((
  Ref ref,
) async {
  try {
    final PackageInfo info = await PackageInfo.fromPlatform();
    return formatAppVersion(info.version, info.buildNumber);
  } on Object catch (e, st) {
    AppLog.failure('PackageInfo', e, st);
    return null;
  }
});
