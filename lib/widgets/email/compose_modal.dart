import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../services/email_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_error.dart';

/// Full-screen overlay compose modal. Place inside a [Stack] at the root of
/// the screen — it renders its own semi-transparent backdrop.
///
/// Pass [initialTo] to pre-fill the recipient field (e.g. from a contact card).
class ComposeModal extends StatefulWidget {
  const ComposeModal({
    super.key,
    required this.onClose,
    this.onSent,
    this.initialTo,
    this.initialSubject,
  });

  final VoidCallback  onClose;
  final VoidCallback? onSent;
  final String?       initialTo;
  final String?       initialSubject;

  @override
  State<ComposeModal> createState() => _ComposeModalState();
}

class _ComposeModalState extends State<ComposeModal> {
  late final _toCtrl      = TextEditingController(text: widget.initialTo ?? '');
  late final _ccCtrl      = TextEditingController();
  late final _bccCtrl     = TextEditingController();
  late final _subjectCtrl = TextEditingController(text: widget.initialSubject ?? '');
  late final _bodyCtrl    = TextEditingController();
  bool    _sending = false;
  String? _error;
  bool    _showBcc = false;

  @override
  void dispose() {
    for (final c in [_toCtrl, _ccCtrl, _bccCtrl, _subjectCtrl, _bodyCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    if (_toCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Recipient (To) is required.');
      return;
    }
    if (_subjectCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Subject is required.');
      return;
    }
    setState(() { _sending = true; _error = null; });
    try {
      await EmailService.instance.compose(
        to:      _toCtrl.text.trim(),
        cc:      _ccCtrl.text.trim().isNotEmpty  ? _ccCtrl.text.trim()  : null,
        bcc:     _bccCtrl.text.trim().isNotEmpty ? _bccCtrl.text.trim() : null,
        subject: _subjectCtrl.text.trim(),
        body:    _bodyCtrl.text.trim(),
      );
      widget.onSent?.call();
    } catch (e) {
      if (mounted) setState(() { _sending = false; _error = friendlyError(e); });
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xB306070A),
    alignment: Alignment.bottomCenter,
    padding: const EdgeInsets.only(bottom: 40, left: 16, right: 16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Container(
        decoration: BoxDecoration(
          color: context.pal.surface1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.pal.borderStrong),
          boxShadow: const [BoxShadow(
            color: Color(0x80000000), blurRadius: 80, offset: Offset(0, 30))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Text('New Message', style: AppTheme.bodyStrong),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _showBcc = !_showBcc),
                child: Text('BCC', style: AppTheme.bodySub.copyWith(
                    color: _showBcc ? AppColors.teal : context.pal.textDim,
                    fontSize: 12)),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: widget.onClose,
                child: Icon(Symbols.close, size: 18, color: context.pal.textDim),
              ),
            ]),
          ),
          _ComposeField(label: 'To',      ctrl: _toCtrl,      hint: 'recipient@example.com'),
          _ComposeField(label: 'CC',      ctrl: _ccCtrl,      hint: ''),
          if (_showBcc)
            _ComposeField(label: 'BCC',   ctrl: _bccCtrl,     hint: ''),
          _ComposeField(label: 'Subject', ctrl: _subjectCtrl, hint: 'Subject'),
          // Body
          Container(
            constraints: const BoxConstraints(minHeight: 130, maxHeight: 240),
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _bodyCtrl,
              maxLines: null,
              expands: true,
              style: AppTheme.bodySm.copyWith(height: 1.6),
              decoration: InputDecoration(
                hintText: 'Compose your message…',
                hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x04FFFFFF),
              border: Border(top: BorderSide(color: context.pal.border)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!,
                      style: TextStyle(color: AppColors.coral, fontSize: 12.5)),
                ),
              Row(children: [
                GestureDetector(
                  onTap: _sending ? null : _send,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                        color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
                    child: _sending
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                color: Color(0xFF06120F), strokeWidth: 2))
                        : Text('Send', style: AppTheme.bodyStrong.copyWith(
                            color: const Color(0xFF06120F))),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onClose,
                  child: Icon(Symbols.delete_outline, size: 20, color: context.pal.textDim),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    ),
  );
}

class _ComposeField extends StatelessWidget {
  const _ComposeField({required this.label, required this.ctrl, required this.hint});
  final String label, hint;
  final TextEditingController ctrl;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.pal.divider))),
    child: Row(children: [
      SizedBox(width: 55,
          child: Text(label, style: AppTheme.bodySub.copyWith(fontSize: 12))),
      const SizedBox(width: 8),
      Expanded(
        child: TextField(
          controller: ctrl,
          style: AppTheme.bodySm,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    ]),
  );
}
