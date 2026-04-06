import 'package:flutter/material.dart';

class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration charDelay;
  final TextAlign textAlign;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.charDelay = const Duration(milliseconds: 40),
    this.textAlign = TextAlign.center,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    _animate();
  }

  @override
  void didUpdateWidget(TypewriterText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _charCount = 0;
      _animate();
    }
  }

  Future<void> _animate() async {
    for (var i = 0; i <= widget.text.length; i++) {
      await Future.delayed(widget.charDelay);
      if (!mounted) return;
      setState(() => _charCount = i);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.text.substring(0, _charCount);
    return Text(
      visible,
      style: widget.style,
      textAlign: widget.textAlign,
    );
  }
}
