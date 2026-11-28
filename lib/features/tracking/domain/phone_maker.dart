/// A settings page the app can open (MainActivity tries the phone maker's
/// own page, then falls back to the app's info page).
enum PhoneSettingsPage {
  /// The app's own info page (App info), where Battery is.
  appInfo('appInfo'),

  /// The phone's Battery page.
  battery('battery'),
  xiaomiAutostart('xiaomiAutostart'),
  vivoAutostart('vivoAutostart'),
  samsungSleeping('samsungSleeping'),
  tecnoAutostart('tecnoAutostart');

  const PhoneSettingsPage(this.wire);

  /// The name sent to MainActivity.
  final String wire;
}

/// One step of a phone maker's settings. [page] is null when no page can be
/// opened (lock the app in Recent apps).
class PhoneStep {
  const PhoneStep(this.title, this.how, [this.page]);

  final String title;
  final String how;
  final PhoneSettingsPage? page;
}

const PhoneStep _lockInRecents = PhoneStep(
  'Lock the app in Recent apps',
  'Open Recent apps, long-press Diamond Agritech, tap the lock.',
);

/// Phone makers whose own battery saving closes apps (dontkillmyapp.com and
/// the makers' help pages), with the steps that keep the tracker running.
enum PhoneMaker {
  xiaomi(
    'Xiaomi',
    'Xiaomi, Redmi and Poco phones close apps to save battery.',
    <PhoneStep>[
      PhoneStep(
        'Turn on Autostart',
        'Find Diamond Agritech and turn Autostart on.',
        PhoneSettingsPage.xiaomiAutostart,
      ),
      PhoneStep(
        'Battery saver: No restrictions',
        'In App info, tap Battery saver and choose No restrictions.',
        PhoneSettingsPage.appInfo,
      ),
      _lockInRecents,
    ],
  ),
  vivo('Vivo', 'Vivo and iQOO phones close apps to save battery.', <PhoneStep>[
    PhoneStep(
      'Turn on Autostart',
      'Find Diamond Agritech and turn it on.',
      PhoneSettingsPage.vivoAutostart,
    ),
    PhoneStep(
      'Allow high background power use',
      'Battery > Background power consumption management > Diamond '
          'Agritech > Allow.',
      PhoneSettingsPage.battery,
    ),
    _lockInRecents,
  ]),
  oppo(
    'Oppo',
    'Oppo and OnePlus phones close apps to save battery.',
    <PhoneStep>[
      PhoneStep(
        'Allow auto launch and background activity',
        'In App info > Battery, turn on Allow auto launch and Allow '
            'background activity.',
        PhoneSettingsPage.appInfo,
      ),
      _lockInRecents,
    ],
  ),
  realme('Realme', 'Realme phones close apps to save battery.', <PhoneStep>[
    PhoneStep(
      'Allow background activity',
      'Battery > Power saving settings > App battery management > Diamond '
          'Agritech. Turn on Allow auto launch and Allow background '
          'activity.',
      PhoneSettingsPage.battery,
    ),
    _lockInRecents,
  ]),
  samsung(
    'Samsung',
    'Samsung phones put apps to sleep to save battery.',
    <PhoneStep>[
      PhoneStep(
        'Battery: Unrestricted',
        'In App info, tap Battery and choose Unrestricted.',
        PhoneSettingsPage.appInfo,
      ),
      PhoneStep(
        'Keep it off Sleeping apps',
        'Battery > Background usage limits. Remove Diamond Agritech from '
            'Sleeping and Deep sleeping apps.',
        PhoneSettingsPage.samsungSleeping,
      ),
    ],
  ),
  motorola(
    'Motorola',
    'Motorola phones can limit apps to save battery.',
    <PhoneStep>[
      PhoneStep(
        'Battery: Unrestricted',
        'In App info > App battery usage, turn on Allow background usage, '
            'tap it and choose Unrestricted.',
        PhoneSettingsPage.appInfo,
      ),
    ],
  ),
  tecno('Tecno', 'Tecno phones close apps to save battery.', <PhoneStep>[
    PhoneStep(
      'Turn on Auto-start',
      'Phone Master > Auto-start management. Turn on Diamond Agritech.',
      PhoneSettingsPage.tecnoAutostart,
    ),
    PhoneStep(
      'Turn off power saving for the app',
      'Battery Lab > Battery saving settings. Turn off power saving for '
          'Diamond Agritech.',
      PhoneSettingsPage.battery,
    ),
    _lockInRecents,
  ]);

  const PhoneMaker(this.name, this.intro, this.steps);

  /// "Xiaomi", for "Xiaomi phone settings".
  final String name;
  final String intro;
  final List<PhoneStep> steps;

  String get title => '$name phone settings';

  /// Which maker's steps fit a phone, from Android's Build.MANUFACTURER and
  /// Build.BRAND. Null for any other phone (no extra steps shown).
  static PhoneMaker? fromBuild({String? manufacturer, String? brand}) {
    for (final String? raw in <String?>[manufacturer, brand]) {
      final String v = (raw ?? '').trim().toLowerCase();
      final PhoneMaker? maker = switch (v) {
        'xiaomi' || 'redmi' || 'poco' => xiaomi,
        'vivo' || 'iqoo' => vivo,
        'oppo' || 'oneplus' => oppo,
        'realme' => realme,
        'samsung' => samsung,
        'motorola' => motorola,
        'tecno' || 'tecno mobile' => tecno,
        _ => null,
      };
      if (maker != null) return maker;
    }
    return null;
  }
}
