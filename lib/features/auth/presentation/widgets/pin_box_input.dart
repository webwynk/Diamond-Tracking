import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';

/// A 6-box segmented PIN input component adhering strictly to the Diamond Agritech
/// design reference (Screen 04).
///
/// Features:
/// - 6 boxes: 48 dp width x 56 dp height, 12 dp border radius.
/// - Inactive box: 1 dp border `AppColors.neutral300`, `AppColors.surface` background.
/// - Active focus box: 2 dp border `AppColors.primary600`.
/// - Filled box: displays an obscured dot (10 dp diameter) or digit.
/// - Invisible underlying TextField for smooth native keyboard focus and paste support.
class PinBoxInput extends StatefulWidget {
  final int length;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onCompleted;
  final bool hasError;

  const PinBoxInput({
    super.key,
    this.length = 6,
    required this.controller,
    this.focusNode,
    this.obscureText = true,
    this.onChanged,
    this.onCompleted,
    this.hasError = false,
  });

  @override
  State<PinBoxInput> createState() => _PinBoxInputState();
}

class _PinBoxInputState extends State<PinBoxInput> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    widget.controller.addListener(_onTextChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onTextChange() {
    setState(() {});
    if (widget.onChanged != null) {
      widget.onChanged!(widget.controller.text);
    }
    if (widget.controller.text.length == widget.length &&
        widget.onCompleted != null) {
      widget.onCompleted!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final isFocused = _focusNode.hasFocus;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hidden off-screen TextField capturing keyboard input
          Opacity(
            opacity: 0.0,
            child: SizedBox(
              width: 1,
              height: 1,
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                autofocus: false,
                enableSuggestions: false,
                autocorrect: false,
              ),
            ),
          ),

          // Rendered 6 boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.length, (index) {
              final isFilled = index < text.length;
              final isCurrentFocus =
                  isFocused &&
                  (index == text.length ||
                      (index == widget.length - 1 &&
                          text.length == widget.length));

              Color borderColor = AppColors.neutral300;
              double borderWidth = 1.0;

              if (widget.hasError) {
                borderColor = AppColors.error;
              } else if (isCurrentFocus) {
                borderColor = AppColors.primary600;
                borderWidth = 2.0;
              }

              return Container(
                width: 48,
                height: 56,
                margin: EdgeInsets.symmetric(
                  horizontal: index == 0 || index == widget.length - 1 ? 2 : 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: borderColor, width: borderWidth),
                ),
                alignment: Alignment.center,
                child: isFilled
                    ? (widget.obscureText
                          ? Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppColors.textPrimary,
                                shape: BoxShape.circle,
                              ),
                            )
                          : Text(
                              text[index],
                              style: AppTypography.title.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ))
                    : (isCurrentFocus && text.length == index
                          ? Container(
                              width: 2,
                              height: 20,
                              color: AppColors.primary600,
                            )
                          : const SizedBox.shrink()),
              );
            }),
          ),
        ],
      ),
    );
  }
}
