import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_text.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_field.dart';
import '../../../shared/ds/ds_frame.dart';
import '../../auth/domain/auth_failure.dart';
import '../application/users_providers.dart';
import '../data/users_repository.dart';
import '../domain/profile.dart';

/// What the admin chose in the delete sheet.
enum DeleteChoice { deleted, turnOff }

/// The red "Delete user" card at the bottom of an employee's page.
class DeleteUserCard extends StatelessWidget {
  const DeleteUserCard({
    required this.firstName,
    required this.onTap,
    super.key,
  });

  final String firstName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Delete user, removes $firstName and all their data',
    excludeSemantics: true,
    child: Material(
      color: DsColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: DsRadius.large,
        side: BorderSide(color: DsColors.dangerTint, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DsSpace.lg,
            vertical: 14,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: DsColors.dangerTint,
                  borderRadius: DsRadius.medium,
                ),
                child: const Icon(
                  DsIcons.delete,
                  size: 18,
                  color: DsColors.dangerText,
                ),
              ),
              const SizedBox(width: DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Delete user',
                      style: DsText.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: DsColors.dangerText,
                      ),
                    ),
                    Text(
                      'Removes $firstName and all their data',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DsText.caption,
                    ),
                  ],
                ),
              ),
              const Icon(DsIcons.forward, size: 16, color: DsColors.dangerText),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Asks to type the user ID, then deletes the person. Returns
/// [DeleteChoice.deleted] once done, [DeleteChoice.turnOff] when the admin
/// picks "Turn off instead", or null when closed.
Future<DeleteChoice?> showDeleteUserSheet(
  BuildContext context,
  Profile profile,
) => showDsSheet<DeleteChoice>(
  context: context,
  builder: (_) => _DeleteUserSheet(profile: profile),
);

class _DeleteUserSheet extends ConsumerStatefulWidget {
  const _DeleteUserSheet({required this.profile});

  final Profile profile;

  @override
  ConsumerState<_DeleteUserSheet> createState() => _DeleteUserSheetState();
}

class _DeleteUserSheetState extends ConsumerState<_DeleteUserSheet> {
  final TextEditingController _typed = TextEditingController();
  bool _busy = false;
  String? _error;

  Profile get _p => widget.profile;

  bool get _matches =>
      _typed.text.trim().toLowerCase() == _p.userCode.toLowerCase();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_busy || !_matches) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(usersRepositoryProvider)
          .delete(_p.id, userCode: _typed.text);
      if (mounted) Navigator.pop(context, DeleteChoice.deleted);
      return;
    } on FieldErrors catch (e) {
      _error = e.fields.values.firstOrNull ?? AuthFailure.unknown.message;
    } on AuthFailure catch (f) {
      _error = f.message;
    } on Object {
      _error = AuthFailure.unknown.message;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final Profile p = _p;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: DsColors.dangerTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              DsIcons.delete,
              size: 26,
              color: DsColors.dangerText,
            ),
          ),
        ),
        const SizedBox(height: DsSpace.md),
        Semantics(
          header: true,
          child: Text(
            'Delete ${p.fullName}?',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: DsText.title,
          ),
        ),
        const SizedBox(height: DsSpace.xs),
        Text(
          '${p.userCode} and all their data are deleted for good. '
          "This can't be undone.",
          textAlign: TextAlign.center,
          style: DsText.body.copyWith(color: DsColors.text2),
        ),
        const SizedBox(height: DsSpace.lg),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DsSpace.md,
            vertical: 10,
          ),
          decoration: const BoxDecoration(
            color: DsColors.surface,
            borderRadius: DsRadius.medium,
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Gone('Sign-in and profile'),
              _Gone('Attendance, leave and requests'),
              _Gone('Routes, visits and photos'),
              _Gone('Notifications'),
            ],
          ),
        ),
        const SizedBox(height: DsSpace.lg),
        DsTextField(
          label: 'Type ${p.userCode} to confirm',
          controller: _typed,
          hint: p.userCode,
          error: _error,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _delete(),
        ),
        const SizedBox(height: DsSpace.lg),
        DsButton(
          label: 'Delete permanently',
          kind: DsButtonKind.danger,
          busy: _busy,
          busyLabel: 'Deleting',
          onPressed: _matches && !_busy ? _delete : null,
        ),
        const SizedBox(height: DsSpace.sm),
        DsButton(
          label: 'Cancel',
          kind: DsButtonKind.outline,
          onPressed: _busy ? null : () => Navigator.pop(context),
        ),
        if (p.isActive) ...<Widget>[
          const SizedBox(height: DsSpace.md),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              const Text('Only want to stop sign-in? ', style: DsText.caption),
              DsTextLink(
                label: 'Turn off instead',
                onPressed: _busy
                    ? null
                    : () => Navigator.pop(context, DeleteChoice.turnOff),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One line of the "what is deleted" list.
class _Gone extends StatelessWidget {
  const _Gone(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: <Widget>[
        const Icon(DsIcons.removed, size: 16, color: DsColors.dangerDot),
        const SizedBox(width: DsSpace.sm),
        Expanded(child: Text(text, style: DsText.body)),
      ],
    ),
  );
}
