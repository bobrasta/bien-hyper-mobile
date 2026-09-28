import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_palette.dart';
import 'labeled_field.dart';

/// True only where mobile_scanner has a real camera-scanning backend —
/// Windows/Linux desktop have no native implementation, so the scan button
/// is hidden there rather than shown and failing when tapped. Manual entry
/// always works everywhere.
bool get _cameraScanSupported {
  if (kIsWeb) return true;
  try {
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  } catch (_) {
    return false;
  }
}

/// A text field for barcode/serial-number entry with an optional camera-scan
/// button — manual typing always available, scanning only where supported.
class ScanOrTypeField extends StatelessWidget {
  const ScanOrTypeField({
    super.key,
    required this.controller,
    this.hint = 'Enter or scan a code…',
    this.onScanned,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onScanned;

  Future<void> _scan(BuildContext context) async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _ScannerScreen(), fullscreenDialog: true),
    );
    if (code != null && code.isNotEmpty) {
      controller.text = code;
      onScanned?.call(code);
    }
  }

  @override
  Widget build(BuildContext context) => FieldFocusBox(
    minHeight: kFieldHeight,
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    builder: (context, focusNode) => Row(children: [
      Expanded(child: TextField(
        controller: controller,
        focusNode: focusNode,
        cursorColor: context.pal.text,
        cursorWidth: 1.5,
        style: AppTheme.fieldText.copyWith(color: context.pal.text),
        decoration: InputDecoration(
          hintText: hint, hintStyle: AppTheme.fieldHint,
          filled: false, border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
        ),
      )),
      if (_cameraScanSupported)
        GestureDetector(
          onTap: () => _scan(context),
          child: Icon(Symbols.qr_code_scanner, size: 18, color: AppColors.teal),
        ),
    ]),
  );
}

class _ScannerScreen extends StatefulWidget {
  const _ScannerScreen();

  @override
  State<_ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<_ScannerScreen> {
  final _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: const Text('Scan Code'),
      actions: [
        IconButton(
          icon: const Icon(Symbols.flash_on),
          onPressed: () => _controller.toggleTorch(),
        ),
      ],
    ),
    body: MobileScanner(controller: _controller, onDetect: _onDetect),
  );
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
