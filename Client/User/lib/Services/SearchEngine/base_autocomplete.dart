import 'package:flutter/material.dart';
import 'package:skybridge02/Services/custom_inputfield.dart';

class BaseAutocompleteField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Iterable<String> Function(String) optionsBuilder;
  final Function(String)? onSelected;
  final bool hasError;
  final Function(String)? onChanged;
  final bool enabled;
  final bool plainStyle;

  const BaseAutocompleteField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    required this.optionsBuilder,
    this.onSelected,
    this.hasError = false,
    this.onChanged,
    this.enabled = true,
    this.plainStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (value) {
        final query = value.text.trim();
        final results = optionsBuilder(query);

        if (query.isEmpty) return results;

        final isExactMatch = results.any(
          (e) => e.toLowerCase() == query.toLowerCase(),
        );

        return isExactMatch ? [] : results;
      },
      onSelected: (val) {
        controller.text = val;
        onSelected?.call(val);
        FocusScope.of(context).unfocus();
      },
      fieldViewBuilder: (context, textCtrl, focusNode, _) {
        if (textCtrl.text != controller.text) {
          textCtrl.value = TextEditingValue(
            text: controller.text,
            selection: TextSelection.collapsed(
              offset: controller.text.length,
            ),
          );
        }

        return CustomInputField(
          controller: textCtrl,
          hint: hint,
          icon: icon,
          focusNode: focusNode,
          disableBottomSheet: true,
          enabled: enabled,
          hasError: hasError,
          plainStyle: plainStyle,
          onChanged: (v) {
            controller.text = v;
            onChanged?.call(v);
          },
        );
      },
    );
  }
}
