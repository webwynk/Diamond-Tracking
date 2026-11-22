/// The designations the admin picks from in the user form. A custom one that
/// has been typed once is offered in the list from then on.
const List<String> presetDesignations = <String>[
  'Field Assistant',
  'Sales Officer',
  'Digital Marketer',
];

/// What the list shows: the presets, then every other designation already in
/// use (each spelling once, A to Z), and [current] when it is none of those.
List<String> designationChoices(Iterable<String?> inUse, {String? current}) {
  final Set<String> seen = presetDesignations
      .map((String s) => s.toLowerCase())
      .toSet();
  final List<String> custom = <String>[];
  for (final String? raw in <String?>[...inUse, current]) {
    final String s = (raw ?? '').trim();
    if (s.isNotEmpty && seen.add(s.toLowerCase())) custom.add(s);
  }
  custom.sort(
    (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
  );
  return <String>[...presetDesignations, ...custom];
}

/// [typed] with extra spaces removed, written the way the matching choice is
/// written ("sales officer" becomes "Sales Officer"), so one designation never
/// ends up with two spellings.
String designationSpelling(String typed, Iterable<String> choices) {
  final String t = typed.trim().replaceAll(RegExp(r'\s+'), ' ');
  final String key = t.toLowerCase();
  for (final String c in choices) {
    if (c.toLowerCase() == key) return c;
  }
  return t;
}
