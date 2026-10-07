import 'package:flutter/material.dart';
import 'package:stock_management/core/utils/number_input.dart';

/// Decimal field (prices, quantities, thresholds): numeric keyboard with
/// separator, accepts `,` or `.`, optional select-all on focus.
class DecimalTextField extends StatefulWidget {
  const DecimalTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.labelText,
    this.helperText,
    this.onChanged,
    this.textInputAction = TextInputAction.next,
    this.selectAllOnFocus = true,
  }) : assert(controller == null || initialValue == null);

  final TextEditingController? controller;
  final String? initialValue;
  final String? labelText;
  final String? helperText;
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;
  final bool selectAllOnFocus;

  @override
  State<DecimalTextField> createState() => _DecimalTextFieldState();
}

class _DecimalTextFieldState extends State<DecimalTextField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController(text: widget.initialValue);
  final _focusNode = FocusNode();
  final _formatters = [DecimalInputFormatter()];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocus);
  }

  void _handleFocus() {
    if (widget.selectAllOnFocus && _focusNode.hasFocus) {
      _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: _formatters,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      decoration: InputDecoration(labelText: widget.labelText, helperText: widget.helperText),
    );
  }
}
