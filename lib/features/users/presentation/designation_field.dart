import 'package:flutter/material.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_text.dart';
import '../../../shared/ds/ds_field.dart';
import '../../../shared/ds/ds_frame.dart';

/// What the admin chose in the list: one of the choices, or "Custom".
typedef DesignationPick = ({String? choice, bool custom});

/// The Designation field of the user form: it looks like a text field and
/// opens a list (Field Assistant, Sales Officer, Digital Marketer, the
/// designations already in use, and "Custom"). Choosing Custom shows a text
/// box under it for the admin to write their own.
class DesignationField extends StatelessWidget {
  const DesignationField({
    required this.choices,
    required this.choice,
    required this.custom,
    required this.customController,
    required this.onPicked,
    this.optional = false,
    this.enabled = true,
    this.error,
    this.onCustomChanged,
    super.key,
  });

  /// Every designation in the list, in order.
  final List<String> choices;

  /// The one picked from [choices], or null.
  final String? choice;

  /// "Custom" is picked: the text box is shown.
  final bool custom;
  final TextEditingController customController;
  final ValueChanged<DesignationPick> onPicked;
  final bool optional;
  final bool enabled;
  final String? error;
  final ValueChanged<String>? onCustomChanged;

  Future<void> _open(BuildContext context) async {
    final DesignationPick? pick = await showDsSheet<DesignationPick>(
      context: context,
      builder: (BuildContext sheet) => _ChoiceList(
        choices: choices,
        choice: custom ? null : choice,
        custom: custom,
      ),
    );
    if (pick != null) onPicked(pick);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError = error != null;
    final String? shown = custom ? 'Custom' : choice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: DsSpace.xs, bottom: 6),
          child: Text.rich(
            TextSpan(
              text: 'Designation',
              children: <InlineSpan>[
                if (optional)
                  TextSpan(
                    text: ' (optional)',
                    style: DsText.label.copyWith(color: DsColors.text3),
                  ),
              ],
            ),
            style: DsText.label,
          ),
        ),
        Semantics(
          button: true,
          enabled: enabled,
          label: 'Designation, ${shown ?? 'not chosen'}',
          excludeSemantics: true,
          child: Material(
            color: hasError && !custom ? DsColors.dangerTint : DsColors.surface,
            borderRadius: DsRadius.medium,
            child: InkWell(
              borderRadius: DsRadius.medium,
              onTap: enabled ? () => _open(context) : null,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
                decoration: BoxDecoration(
                  borderRadius: DsRadius.medium,
                  border: hasError && !custom
                      ? Border.all(color: DsColors.dangerText, width: 2)
                      : null,
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      DsIcons.designation,
                      size: 20,
                      color: DsColors.text2,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        shown ?? 'Choose a designation',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DsText.body.copyWith(
                          fontSize: 16,
                          color: shown == null ? DsColors.text3 : DsColors.ink,
                        ),
                      ),
                    ),
                    const Icon(
                      DsIcons.expandMore,
                      size: 20,
                      color: DsColors.text2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasError && !custom)
          Padding(
            padding: const EdgeInsets.only(left: DsSpace.xs, top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    DsIcons.error,
                    size: 14,
                    color: DsColors.dangerText,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    error!,
                    style: DsText.caption.copyWith(color: DsColors.dangerText),
                  ),
                ),
              ],
            ),
          ),
        if (custom) ...<Widget>[
          const SizedBox(height: 14),
          DsTextField(
            label: 'Custom designation',
            controller: customController,
            icon: DsIcons.edit,
            hint: 'For example Territory Manager',
            maxLength: 40,
            error: error,
            textInputAction: TextInputAction.next,
            onChanged: onCustomChanged,
          ),
        ],
      ],
    );
  }
}

class _ChoiceList extends StatelessWidget {
  const _ChoiceList({
    required this.choices,
    required this.choice,
    required this.custom,
  });

  final List<String> choices;
  final String? choice;
  final bool custom;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: const Text('Designation', style: DsText.title),
        ),
        const SizedBox(height: DsSpace.sm),
        for (final String c in choices)
          _ChoiceRow(
            label: c,
            selected: c == choice,
            onTap: () =>
                Navigator.of(context)
                    .pop<DesignationPick>((choice: c, custom: false)),
          ),
        const Divider(height: 16, color: DsColors.disabled),
        _ChoiceRow(
          label: 'Custom',
          icon: DsIcons.edit,
          hint: 'Write a designation that is not in the list',
          selected: custom,
          onTap: () =>
              Navigator.of(context)
                  .pop<DesignationPick>((choice: null, custom: true)),
        ),
      ],
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.hint,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: DsRadius.medium,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(
            horizontal: DsSpace.sm,
            vertical: 8,
          ),
          child: Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 20, color: DsColors.text2),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: DsText.body.copyWith(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    if (hint != null) Text(hint!, style: DsText.caption),
                  ],
                ),
              ),
              if (selected)
                const Icon(DsIcons.check, size: 20, color: DsColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
