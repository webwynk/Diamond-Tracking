import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/ds_colors.dart';
import '../../core/design/ds_icons.dart';
import '../../core/design/ds_layout.dart';
import '../../core/design/ds_text.dart';

/// A text field of the new design (design v2, section 05): label above,
/// 56 tall, radius 16. Empty and filled sit on the surface colour; focus
/// turns white with a 2 px primary ring; an [error] turns it light red with
/// a red ring and the message under it; [locked] shows it greyed (a user ID
/// after creation).
class DsTextField extends StatefulWidget {
  const DsTextField({
    required this.label,
    this.controller,
    this.hint,
    this.error,
    this.helper,
    this.locked = false,
    this.password = false,
    this.optional = false,
    this.prefixText,
    this.icon,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.autofillHints,
    this.maxLines = 1,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;

  /// Shown in red under the field, with the field in its error look.
  final String? error;

  /// A grey line under the field when there is no error.
  final String? helper;

  /// Read only, greyed.
  final bool locked;

  /// Hidden text with a show/hide eye.
  final bool password;

  /// Adds "(optional)" after the label.
  final bool optional;

  /// Fixed text in front, for example "+91".
  final String? prefixText;

  /// An icon at the start of the field.
  final IconData? icon;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final int maxLines;

  /// Shows a "12 / 300" counter at the end of the label row.
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  @override
  State<DsTextField> createState() => _DsTextFieldState();
}

class _DsTextFieldState extends State<DsTextField> {
  bool _hidden = true;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_redraw);
  }

  @override
  void didUpdateWidget(DsTextField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.removeListener(_redraw);
      widget.controller?.addListener(_redraw);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_redraw);
    super.dispose();
  }

  void _redraw() {
    if (widget.maxLength != null) setState(() {});
  }

  OutlineInputBorder _border(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: DsRadius.medium,
      borderSide: width == 0
          ? BorderSide.none
          : BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError = widget.error != null;
    final Color fill = widget.locked
        ? DsColors.disabled
        : (hasError ? DsColors.dangerTint : DsColors.surface);
    final int length = widget.controller?.text.length ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: DsSpace.xs, bottom: 6),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: widget.label,
                    children: <InlineSpan>[
                      if (widget.optional)
                        TextSpan(
                          text: ' (optional)',
                          style: DsText.label.copyWith(color: DsColors.text3),
                        ),
                    ],
                  ),
                  style: DsText.label,
                ),
              ),
              if (widget.maxLength != null)
                Text('$length / ${widget.maxLength}', style: DsText.caption),
            ],
          ),
        ),
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          readOnly: widget.locked,
          enabled: !widget.locked,
          obscureText: widget.password && _hidden,
          enableSuggestions: !widget.password,
          autocorrect: !widget.password,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          inputFormatters: <TextInputFormatter>[
            ...?widget.inputFormatters,
            if (widget.maxLength != null)
              LengthLimitingTextInputFormatter(widget.maxLength),
          ],
          autofillHints: widget.autofillHints,
          maxLines: widget.password ? 1 : widget.maxLines,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          style: DsText.body.copyWith(
            fontSize: 16,
            color: widget.locked ? DsColors.text3 : DsColors.ink,
          ),
          cursorColor: DsColors.primary,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: WidgetStateColor.resolveWith(
              (Set<WidgetState> states) =>
                  states.contains(WidgetState.focused) && !hasError
                  ? DsColors.white
                  : fill,
            ),
            hintText: widget.hint,
            hintStyle: DsText.body.copyWith(fontSize: 16, color: DsColors.text3),
            prefixText: widget.prefixText == null
                ? null
                : '${widget.prefixText}  ',
            prefixStyle: DsText.body.copyWith(
              fontSize: 16,
              color: DsColors.text2,
            ),
            prefixIcon: widget.icon == null
                ? null
                : Icon(widget.icon, size: 20, color: DsColors.text2),
            suffixIcon: widget.password
                ? IconButton(
                    tooltip: _hidden ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Icon(
                      _hidden ? DsIcons.show : DsIcons.hide,
                      size: 20,
                      color: DsColors.text2,
                    ),
                  )
                : null,
            contentPadding: EdgeInsets.symmetric(
              horizontal: DsSpace.lg,
              vertical: widget.maxLines > 1 ? DsSpace.lg : 18,
            ),
            border: _border(DsColors.line, 0),
            enabledBorder: hasError
                ? _border(DsColors.dangerText, 2)
                : _border(DsColors.line, 0),
            disabledBorder: _border(DsColors.line, 0),
            focusedBorder: _border(
              hasError ? DsColors.dangerText : DsColors.primary,
              2,
            ),
          ),
        ),
        if (hasError)
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
                    widget.error!,
                    style: DsText.caption.copyWith(color: DsColors.dangerText),
                  ),
                ),
              ],
            ),
          )
        else if (widget.helper != null)
          Padding(
            padding: const EdgeInsets.only(left: DsSpace.xs, top: 6),
            child: Text(widget.helper!, style: DsText.caption),
          ),
      ],
    );
  }
}

/// The 6-box code entry (password reset). One hidden field takes the
/// typing, so pasting the code from the email fills all 6 boxes at once and
/// backspace steps back. Filled boxes are primary tint; the next one has a
/// ring.
class DsCodeBoxes extends StatefulWidget {
  const DsCodeBoxes({
    required this.controller,
    this.length = 6,
    this.onCompleted,
    this.error = false,
    super.key,
  });

  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onCompleted;
  final bool error;

  @override
  State<DsCodeBoxes> createState() => _DsCodeBoxesState();
}

class _DsCodeBoxesState extends State<DsCodeBoxes> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focus.addListener(_redraw);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  void _redraw() => setState(() {});

  void _changed() {
    setState(() {});
    final String text = widget.controller.text;
    if (text.length == widget.length) widget.onCompleted?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    final String text = widget.controller.text;
    return Semantics(
      label: 'Code, ${widget.length} digits',
      textField: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _focus.requestFocus,
        child: Stack(
          children: <Widget>[
            Row(
              children: <Widget>[
                for (int i = 0; i < widget.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: DsSpace.sm),
                  Expanded(child: _box(i, text)),
                ],
              ],
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  keyboardType: TextInputType.number,
                  autofillHints: const <String>[AutofillHints.oneTimeCode],
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(widget.length),
                  ],
                  showCursor: false,
                  enableInteractiveSelection: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _box(int i, String text) {
    final bool filled = i < text.length;
    final bool active = _focus.hasFocus && i == text.length;
    final Color ring = widget.error
        ? DsColors.dangerText
        : (active ? DsColors.primary : Colors.transparent);
    return Container(
      height: DsSize.control,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: widget.error
            ? DsColors.dangerTint
            : (filled ? DsColors.primaryTint : DsColors.surface),
        borderRadius: DsRadius.medium,
        border: Border.all(color: ring, width: 2),
      ),
      child: Text(filled ? text[i] : '', style: DsText.value),
    );
  }
}

/// One password rule with a tick that turns green when it is met
/// ("8+ characters", "Letter and digit", "Not your user ID").
class DsRuleTick extends StatelessWidget {
  const DsRuleTick({required this.label, required this.met, super.key});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label, ${met ? 'done' : 'not yet'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(DsSpace.sm, 6, DsSpace.md, 6),
        decoration: BoxDecoration(
          color: met ? DsColors.successTint : DsColors.surface,
          borderRadius: DsRadius.pill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              DsIcons.check,
              size: 14,
              color: met ? DsColors.successText : DsColors.text3,
            ),
            const SizedBox(width: DsSpace.xs),
            Flexible(
              child: Text(
                label,
                style: DsText.caption.copyWith(
                  color: met ? DsColors.successText : DsColors.text2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
