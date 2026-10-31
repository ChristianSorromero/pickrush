import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';

/// Six boxes for an emailed code (sign-up verification, password reset).
class CodeInput extends StatelessWidget {
  const CodeInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.hasError,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => focusNode.requestFocus(),
      child: Stack(
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([controller, focusNode]),
            builder: (context, _) {
              final text = controller.text;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(length, (i) {
                  final filled = i < text.length;
                  final current = focusNode.hasFocus && i == text.length;
                  final borderColor = hasError
                      ? AppColors.primaryDark
                      : (filled || current)
                          ? AppColors.primary
                          : AppColors.border;
                  return Container(
                    height: 52,
                    width: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.mdAll,
                      border: Border.all(
                        color: borderColor,
                        width: (filled || current || hasError) ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      filled ? text[i] : '-',
                      style: AppTextStyles.h2.copyWith(
                        fontSize: 20,
                        color: filled ? AppColors.textPrimary : AppColors.textMuted,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(length),
                ],
                showCursor: false,
                enableInteractiveSelection: false,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
