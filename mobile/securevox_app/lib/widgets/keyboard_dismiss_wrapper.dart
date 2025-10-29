import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget wrapper per gestire la chiusura automatica della tastiera
/// Avvolge il contenuto e chiude la tastiera quando si tocca fuori dai campi
class KeyboardDismissWrapper extends StatelessWidget {
  final Widget child;
  final bool enableDismiss;
  final VoidCallback? onDismiss;

  const KeyboardDismissWrapper({
    Key? key,
    required this.child,
    this.enableDismiss = true,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!enableDismiss) {
      return child;
    }

    return GestureDetector(
      onTap: () {
        // Chiude la tastiera quando si tocca fuori dai campi
        _dismissKeyboard(context);
        onDismiss?.call();
      },
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }

  /// Chiude la tastiera e rimuove il focus dai campi
  static void _dismissKeyboard(BuildContext context) {
    // Rimuove il focus da tutti i campi di input
    FocusScope.of(context).unfocus();
    
    // Nasconde la tastiera
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  /// Metodo statico per chiudere la tastiera da qualsiasi punto dell'app
  static void dismissKeyboard(BuildContext context) {
    _dismissKeyboard(context);
  }
}

/// Mixin per aggiungere facilmente la funzionalità di dismiss tastiera
mixin KeyboardDismissMixin<T extends StatefulWidget> on State<T> {
  
  /// Chiude la tastiera
  void dismissKeyboard() {
    KeyboardDismissWrapper.dismissKeyboard(context);
  }

  /// Wrapper per GestureDetector che chiude la tastiera
  Widget buildWithKeyboardDismiss({
    required Widget child,
    VoidCallback? onTap,
    bool enableDismiss = true,
  }) {
    return GestureDetector(
      onTap: () {
        if (enableDismiss) {
          dismissKeyboard();
        }
        onTap?.call();
      },
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}

/// Widget per campi di input con dismiss automatico
class KeyboardDismissTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? maxLines;
  final int? maxLength;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final EdgeInsetsGeometry? contentPadding;
  final InputBorder? border;
  final InputBorder? enabledBorder;
  final InputBorder? focusedBorder;
  final TextStyle? style;
  final TextStyle? hintStyle;
  final Color? fillColor;
  final bool filled;
  final bool enabled;
  final bool readOnly;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;

  const KeyboardDismissTextField({
    Key? key,
    this.controller,
    this.hintText,
    this.labelText,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.contentPadding,
    this.border,
    this.enabledBorder,
    this.focusedBorder,
    this.style,
    this.hintStyle,
    this.fillColor,
    this.filled = false,
    this.enabled = true,
    this.readOnly = false,
    this.focusNode,
    this.textInputAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        contentPadding: contentPadding,
        border: border,
        enabledBorder: enabledBorder,
        focusedBorder: focusedBorder,
        hintStyle: hintStyle,
        fillColor: fillColor,
        filled: filled,
      ),
      enabled: enabled,
      readOnly: readOnly,
      focusNode: focusNode,
      textInputAction: textInputAction,
      // Chiude la tastiera quando si preme invio (se maxLines = 1)
    );
  }

  /// Chiude la tastiera
  static void dismissKeyboard(BuildContext context) {
    KeyboardDismissWrapper.dismissKeyboard(context);
  }
}

/// Widget per liste scrollabili con dismiss tastiera
class KeyboardDismissListView extends StatelessWidget {
  final List<Widget> children;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final Axis scrollDirection;
  final bool reverse;

  const KeyboardDismissListView({
    Key? key,
    required this.children,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return KeyboardDismissWrapper(
      child: ListView(
        controller: controller,
        padding: padding,
        shrinkWrap: shrinkWrap,
        physics: physics,
        scrollDirection: scrollDirection,
        reverse: reverse,
        children: children,
      ),
    );
  }
}

/// Widget per colonne con dismiss tastiera
class KeyboardDismissColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final TextBaseline? textBaseline;

  const KeyboardDismissColumn({
    Key? key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.textBaseline,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return KeyboardDismissWrapper(
      child: Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        textDirection: textDirection,
        verticalDirection: verticalDirection,
        textBaseline: textBaseline,
        children: children,
      ),
    );
  }
}

/// Widget per righe con dismiss tastiera
class KeyboardDismissRow extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final TextBaseline? textBaseline;

  const KeyboardDismissRow({
    Key? key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.textBaseline,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return KeyboardDismissWrapper(
      child: Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        textDirection: textDirection,
        verticalDirection: verticalDirection,
        textBaseline: textBaseline,
        children: children,
      ),
    );
  }
}
