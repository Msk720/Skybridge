import 'package:skybridge02/Services/app_imports.dart';
import 'package:flutter/services.dart';

class CustomInputField extends StatefulWidget {
  final TextEditingController? controller;
  final String hint;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool readOnly;
  final int maxLines;
  final FocusNode? focusNode;
  final bool disableBottomSheet;
  final Function(String)? onChanged;
  final bool hasError;
  final bool plainStyle;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  final List<String>? items;
  final Function(String)? onItemSelected;

  final List<DropdownMenuItem<String>>? categoryItems;
  final Function(String?)? onChangedDropdown;
  final String? value;
  final bool enabled;

  const CustomInputField({
    super.key,
    this.controller,
    required this.hint,
    this.icon,
    this.onTap,
    this.readOnly = false,
    this.maxLines = 1,
    this.items,
    this.onItemSelected,
    this.focusNode,
    this.disableBottomSheet = false,
    this.onChanged,
    this.hasError = false,
    this.enabled = true,
    this.plainStyle = false,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.categoryItems,
    this.onChangedDropdown,
    this.value,
  });

  @override
  State<CustomInputField> createState() => _CustomInputFieldState();
}

class _CustomInputFieldState extends State<CustomInputField> {
  bool isFocused = false;
  late bool isPlain = widget.plainStyle;
  late FocusNode focusNode;

  @override
  void initState() {
    super.initState();
    focusNode = widget.focusNode ?? FocusNode();

    focusNode.addListener(() {
      setState(() {
        isFocused = focusNode.hasFocus;
      });
    });
  }

  Future<void> showSelectionSheet({
    required BuildContext context,
    required List<String> items,
    required Function(String) onSelect,
  }) async {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, index) {
            return ListTile(
              title: Text(items[index]),
              onTap: () {
                Navigator.pop(context);
                onSelect(items[index]);
              },
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Widget _disabledSingleLineText() {
    final text = widget.controller?.text.trim() ?? '';

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.icon == null ? 16 : 12,
        vertical: 12,
      ),
      child: Row(
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, color: AppColors.icon, size: 20),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              text.isEmpty ? widget.hint : text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: text.isEmpty ? AppColors.icon : const Color(0xFF111827),
              ),
            ),
          ),
          if (widget.suffixIcon != null) widget.suffixIcon!,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: isPlain ? EdgeInsets.only(bottom: 2) : EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isPlain ? 0 : 18),
        color: (widget.hasError && isFocused)
            ? const Color.fromARGB(255, 255, 190, 172)
            : widget.plainStyle
                ? (isFocused
                    ? const Color.fromARGB(255, 102, 119, 143)
                    : Colors.transparent)
                : (isFocused ? const Color(0xFFD1D5DB) : Colors.transparent),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isPlain
              ? const Color.fromARGB(255, 255, 255, 255)
              : Color(0xFFF3F4F6), // light grey,

          borderRadius: isPlain ? BorderRadius.zero : BorderRadius.circular(18),
          border: isPlain
              ? Border(
                  bottom: BorderSide(
                    color: isFocused
                        ? const Color.fromARGB(255, 90, 101, 122)
                        : const Color.fromARGB(255, 167, 172, 182),
                    width: 2,
                  ),
                )
              : Border.all(
                  color: (widget.hasError && isFocused)
                      ? Colors.red
                      : isFocused
                          ? const Color(0xFF6B7280)
                          : const Color(0xFFE5E7EB),
                  width: 1.2,
                ),

          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  )
                ]
              : [],
        ),
        child: widget.categoryItems != null
            ? GestureDetector(
                onTap: () {
                  setState(() {
                    isFocused = true;
                  });
                },
                child: DropdownButtonFormField<String>(
                  value: widget.hasError ? null : widget.value,
                  items: widget.categoryItems,
                  onChanged: (val) {
                    setState(() {
                      isFocused = false;
                    });
                    widget.onChangedDropdown?.call(val);
                  },
                  style: TextStyle(
                    color: const Color(0xFF111827),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText:
                      widget.hint,
                      hintStyle: TextStyle(
                        color: widget.hasError ? Colors.red : AppColors.icon,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      
                    ),
                    prefixIcon: widget.icon != null
                        ? Icon(widget.icon, color: AppColors.icon, size: 19)
                        : null,
                    border: InputBorder.none,
                  ),
                  icon: const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(Icons.keyboard_arrow_down),
                  ),
                  isExpanded: true,
                  dropdownColor: Colors.white,
                ))
            : (!widget.enabled && widget.maxLines == 1)
                ? _disabledSingleLineText()
                : TextField(
                controller: widget.controller,
                onChanged: widget.onChanged,
                readOnly: widget.readOnly,
                enabled: widget.enabled,
                obscureText: widget.obscureText,
                keyboardType: widget.keyboardType,
                inputFormatters: widget.inputFormatters,
                onTap: () {
                  if (widget.items != null && widget.items!.isNotEmpty) {
                    showSelectionSheet(
                      context: context,
                      items: widget.items!,
                      onSelect: (val) {
                        widget.controller?.text = val;
                        widget.onItemSelected?.call(val);
                      },
                    );
                  } else {
                    widget.onTap?.call();
                  }
                },
                focusNode: focusNode,
                maxLines: widget.maxLines,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: TextStyle(
                    color: widget.hasError ? Colors.red : AppColors.icon,
                  ),
                  prefixIcon: widget.icon != null
                      ? Icon(widget.icon, color: AppColors.icon, size: 20)
                      : null,
                  suffixIcon: widget.suffixIcon,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: widget.icon == null ? 16 : 12,
                    vertical: 12,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF111827),
                ),
              ),
      ),
    );
  }
}
