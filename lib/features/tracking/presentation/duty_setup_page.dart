import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_status.dart';
import '../../../core/design/ds_text.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_chips.dart';
import '../../../shared/ds/ds_frame.dart';
import '../application/tracker_control.dart';
import '../application/tracker_providers.dart';
import '../data/phone_setup.dart';
import '../domain/phone_maker.dart';
import 'phone_setup_sheet.dart';

/// Opens "Get ready for duty" (design v2) when the phone is missing
/// something. True when the employee tapped Start duty.
Future<bool> showTrackingSetup(BuildContext context) async =>
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => const DutySetupPage(),
      ),
    ) ??
    false;

/// The phone settings duty needs, one row each, with Allow buttons. Done
/// rows fold into one line; the next one to allow is highlighted. On phones
/// whose maker closes apps to save battery, one more optional row opens the
/// maker's steps.
class DutySetupPage extends ConsumerStatefulWidget {
  const DutySetupPage({super.key});

  @override
  ConsumerState<DutySetupPage> createState() => _DutySetupPageState();
}

class _DutySetupPageState extends ConsumerState<DutySetupPage> {
  late final AppLifecycleListener _lifecycle;
  List<TrackerRequirement>? _missing;
  PhoneMaker? _maker;
  bool _makerDone = false;
  bool _asking = false;

  TrackerControl get _tracker => ref.read(trackerControlProvider);
  PhoneSetup get _phone => ref.read(phoneSetupProvider);

  @override
  void initState() {
    super.initState();
    // Coming back from a settings page: check again.
    _lifecycle = AppLifecycleListener(onResume: _check);
    _check();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final List<TrackerRequirement> missing = await _tracker
        .missingRequirements();
    final PhoneMaker? maker = await _phone.maker();
    final bool makerDone = maker != null && await _phone.isDone();
    if (!mounted) return;
    setState(() {
      _missing = missing;
      _maker = maker;
      _makerDone = makerDone;
    });
  }

  Future<void> _openMaker(PhoneMaker maker) async {
    final bool done = await showPhoneSetupSheet(
      context,
      maker: maker,
      setup: _phone,
    );
    if (done && mounted) setState(() => _makerDone = true);
  }

  Future<void> _ask(TrackerRequirement r) async {
    setState(() => _asking = true);
    try {
      await _tracker.request(r);
    } finally {
      if (mounted) setState(() => _asking = false);
    }
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    final List<TrackerRequirement>? missing = _missing;
    const List<TrackerRequirement> all = TrackerRequirement.values;
    final List<TrackerRequirement> done = missing == null
        ? const <TrackerRequirement>[]
        : all.where((TrackerRequirement r) => !missing.contains(r)).toList();
    final List<TrackerRequirement> todo = missing == null
        ? const <TrackerRequirement>[]
        : all.where(missing.contains).toList();
    final int requiredLeft = todo
        .where((TrackerRequirement r) => r.required)
        .length;
    final bool ready = missing != null && requiredLeft == 0;
    final PhoneMaker? maker = _maker;
    final List<String> doneNames = <String>[
      ...done.map(requirementShortName),
      if (maker != null && _makerDone) '${maker.name} settings',
    ];
    final int total = all.length + (maker == null ? 0 : 1);
    return Scaffold(
      backgroundColor: DsColors.surface,
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            DsScreenHeader(
              title: 'Before duty on',
              onBack: () => Navigator.pop(context, false),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  DsSpace.gutter,
                  DsSpace.sm,
                  DsSpace.gutter,
                  DsSpace.lg,
                ),
                children: <Widget>[
                  const Text('Get ready for duty', style: DsText.title),
                  const SizedBox(height: DsSpace.xs),
                  Text(
                    'Allow these once. Your route is recorded only while '
                    "you're on duty.",
                    style: DsText.body.copyWith(color: DsColors.text2),
                  ),
                  const SizedBox(height: DsSpace.lg),
                  if (missing == null)
                    const Padding(
                      padding: EdgeInsets.all(DsSpace.xxl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...<Widget>[
                    _Progress(done: doneNames, total: total),
                    const SizedBox(height: DsSpace.lg),
                    for (int i = 0; i < todo.length; i++) ...<Widget>[
                      _RequirementCard(
                        requirement: todo[i],
                        next: i == 0,
                        onAllow: _asking ? null : () => _ask(todo[i]),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (maker != null && !_makerDone)
                      _SetupCard(
                        icon: DsIcons.smartphone,
                        title: maker.title,
                        why:
                            '${maker.name} phones close apps to save battery. '
                            '${_steps(maker.steps.length)}.',
                        optional: true,
                        next: todo.isEmpty,
                        button: 'Open',
                        onPressed: _asking ? null : () => _openMaker(maker),
                      ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DsSpace.gutter,
                DsSpace.sm,
                DsSpace.gutter,
                DsSpace.lg,
              ),
              child: DsButton(
                label: ready || missing == null
                    ? 'Start duty'
                    : 'Allow $requiredLeft more to start',
                icon: ready ? DsIcons.dutyOn : null,
                onPressed: ready ? () => Navigator.pop(context, true) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _steps(int n) => n == 1 ? '1 quick step' : '$n quick steps';

/// "3 of 5 done", a bar of one part per setting, and the done ones.
class _Progress extends StatelessWidget {
  const _Progress({required this.done, required this.total});

  /// Short names of the settings done.
  final List<String> done;
  final int total;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(DsSpace.lg),
    decoration: const BoxDecoration(
      color: DsColors.white,
      borderRadius: DsRadius.large,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('${done.length} of $total done', style: DsText.section),
        const SizedBox(height: DsSpace.sm),
        Row(
          children: <Widget>[
            for (int i = 0; i < total; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: i < done.length
                        ? DsColors.successDot
                        : DsColors.line,
                    borderRadius: DsRadius.pill,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (done.isNotEmpty) ...<Widget>[
          const SizedBox(height: DsSpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(DsIcons.check, size: 16, color: DsColors.successText),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  done.join(' · '),
                  style: DsText.caption.copyWith(color: DsColors.successText),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _RequirementCard extends StatelessWidget {
  const _RequirementCard({
    required this.requirement,
    required this.next,
    required this.onAllow,
  });

  final TrackerRequirement requirement;
  final bool next;
  final VoidCallback? onAllow;

  @override
  Widget build(BuildContext context) {
    final (String title, String why) = requirementText(requirement);
    return _SetupCard(
      icon: requirementIcon(requirement),
      title: title,
      why: why,
      optional: !requirement.required,
      next: next,
      button: 'Allow',
      onPressed: onAllow,
    );
  }
}

/// One row of the setup list: icon, title (Optional tag), reason, button.
class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.icon,
    required this.title,
    required this.why,
    required this.optional,
    required this.next,
    required this.button,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String why;
  final bool optional;

  /// The next one to do: white with a blue ring, and a solid button.
  final bool next;
  final String button;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: next ? DsColors.white : DsColors.disabled,
        borderRadius: DsRadius.large,
        border: Border.all(
          color: next ? DsColors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: next ? DsColors.primaryTint : DsColors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: next ? DsColors.primary : DsColors.text2,
            ),
          ),
          const SizedBox(width: DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      title,
                      style: DsText.body.copyWith(
                        fontWeight: FontWeight.w700,
                        fontVariations: const <FontVariation>[
                          FontVariation('wght', 700),
                        ],
                      ),
                    ),
                    if (optional)
                      const DsTag(label: 'Optional', status: DsStatus.off),
                  ],
                ),
                const SizedBox(height: 2),
                Text(why, style: DsText.caption),
              ],
            ),
          ),
          const SizedBox(width: DsSpace.sm),
          DsSmallButton(label: button, onPressed: onPressed, filled: next),
        ],
      ),
    );
  }
}

/// Title and reason shown for a requirement.
(String, String) requirementText(TrackerRequirement r) => switch (r) {
  TrackerRequirement.locationService => (
    'Turn on location',
    'GPS must be on to record your route.',
  ),
  TrackerRequirement.locationPermission => (
    'Allow location',
    'Needed while you are on duty.',
  ),
  TrackerRequirement.backgroundLocation => (
    'Location all the time',
    'Choose "Allow all the time". Recording restarts by itself after a '
        'phone restart.',
  ),
  TrackerRequirement.notifications => (
    'Notifications',
    'Shows you are on duty and warns on low battery.',
  ),
  TrackerRequirement.batteryOptimization => (
    'Battery saver',
    'Stops the phone closing the app to save battery.',
  ),
};

/// The short name in the "done" line.
String requirementShortName(TrackerRequirement r) => switch (r) {
  TrackerRequirement.locationService => 'Location on',
  TrackerRequirement.locationPermission => 'Location allowed',
  TrackerRequirement.backgroundLocation => 'All the time',
  TrackerRequirement.notifications => 'Notifications',
  TrackerRequirement.batteryOptimization => 'Battery saver off',
};

IconData requirementIcon(TrackerRequirement r) => switch (r) {
  TrackerRequirement.locationService => DsIcons.pin,
  TrackerRequirement.locationPermission => DsIcons.pin,
  TrackerRequirement.backgroundLocation => DsIcons.clock,
  TrackerRequirement.notifications => DsIcons.bell,
  TrackerRequirement.batteryOptimization => DsIcons.battery,
};
