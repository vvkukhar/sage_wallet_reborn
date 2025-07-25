import 'package:flutter/material.dart';
import '../../../utils/app_palette.dart';

class PinIndicator extends StatelessWidget {
  final int pinLength;
  final int maxLength;
  final bool hasError;

  const PinIndicator({
    super.key,
    required this.pinLength,
    this.maxLength = 4,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(maxLength, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index < pinLength
                ? (hasError ? errorColor : AppPalette.darkPrimary)
                : AppPalette.darkSurface,
            border: Border.all(
              color: hasError ? errorColor.withAlpha(128) : AppPalette.darkPrimary.withAlpha(77),
            ),
          ),
        );
      }),
    );
  }
}