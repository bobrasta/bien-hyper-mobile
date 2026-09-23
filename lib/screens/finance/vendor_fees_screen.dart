import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../main.dart' show userRoleNotifier, hasAccountantAuthority, hasDirectorAuthority;
import '../../models/vendor.dart';
import '../../services/vendor_fee_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_palette.dart';
import '../../utils/api_error.dart';
import '../../utils/format.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/error_view.dart';

// UI-hint approximations only, same fail-safe rule as the rest of this
// app's client-side role checks — the real gates are
// VendorFeeController/ReceiptController/DeliveryJobController's
// hasProcurementCreateAuthority()/hasLogisticsDeliverAuthority()/
// hasAccountantAuthority()/hasFinanceApprovalAuthority()/hasDirectorAuthority().
bool _isVendorOpsTier(String role) => const {
  'super_admin', 'admin', 'procurement_manager', 'logistics', 'accountant', 'finance_manager', 'finance',
}.contains(role);
bool _canVerifyReceipts(String role) =>
    hasAccountantAuthority(role) || const {'finance_manager', 'finance'}.contains(role);

(Color, Color, String) _feeStatusStyle(VendorFeeStatus s) => switch (s) {
  VendorFeeStatus.paid            => (AppColors.teal, AppColors.tealSoft, 'Paid'),
  VendorFeeStatus.rejected        => (AppColors.coral, AppColors.coralSoft, 'Rejected'),
  VendorFeeStatus.readyForPayment => (AppColors.amber, AppColors.amberSoft, 'Ready for Payment'),
  VendorFeeStatus.pendingReceipt  => (AppColors.textMute, const Color(0x0AFFFFFF), 'Pending Receipt'),
};

class VendorFeesScreen extends StatefulWidget {
  const VendorFeesScreen({super.key});

  @override
  State<VendorFeesScreen> createState() => _VendorFeesScreenState();
}

class _VendorFeesScreenState extends State<VendorFeesScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<VendorFee>   _fees = [];
  List<DeliveryJob> _jobs = [];
  List<Vendor>      _vendors = [];
  bool    _loading = true;
  String? _error;

  bool _showCreateFee = false;
  bool _showCreateJob = false;
  bool _showVendorForm = false;
  Vendor? _editingVendor;
  VendorFee? _openFee;
  DeliveryJob? _openJob;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        VendorFeeService.instance.fees(),
        VendorFeeService.instance.deliveryJobs(),
        VendorFeeService.instance.vendors(includeInactive: true),
      ]);
      if (mounted) setState(() {
        _fees = results[0] as List<VendorFee>;
        _jobs = results[1] as List<DeliveryJob>;
        _vendors = results[2] as List<Vendor>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = userRoleNotifier.value;
    final opsTier = _isVendorOpsTier(role);

    return Stack(children: [
      Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [
            Text('Vendors', style: AppTheme.pageTitle),
            const Spacer(),
            if (opsTier) ...[
              AppButton(label: 'New vendor', icon: Symbols.add, variant: BtnVariant.ghost, small: true,
                onPressed: () => setState(() { _editingVendor = null; _showVendorForm = true; })),
              const SizedBox(width: 8),
              AppButton(label: 'New job', icon: Symbols.add, variant: BtnVariant.ghost, small: true,
                onPressed: () => setState(() => _showCreateJob = true)),
              const SizedBox(width: 8),
              AppButton(label: 'Record fee', icon: Symbols.add, variant: BtnVariant.primary, small: true,
                onPressed: () => setState(() => _showCreateFee = true)),
            ],
          ]),
        ),
        const SizedBox(height: 8),
        TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: const [Tab(text: 'Vendor Fees'), Tab(text: 'Delivery Jobs'), Tab(text: 'Vendors')],
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorView(message: _error!, onRetry: _load)
                  : TabBarView(controller: _tab, children: [
                      _feesTab(opsTier),
                      _jobsTab(opsTier),
                      _vendorsTab(opsTier),
                    ]),
        ),
      ]),
      if (_showCreateFee)
        _CreateFeeDialog(
          vendors: _vendors,
          deliveryJobs: _jobs.where((j) => j.status == 'delivered' && j.feeId == null).toList(),
          onClose: () => setState(() => _showCreateFee = false),
          onSaved: () { setState(() => _showCreateFee = false); _load(); },
        ),
      if (_showCreateJob)
        _CreateJobDialog(
          deliveryVendors: _vendors.where((v) => v.type == 'delivery').toList(),
          onClose: () => setState(() => _showCreateJob = false),
          onSaved: () { setState(() => _showCreateJob = false); _load(); },
        ),
      if (_showVendorForm)
        _VendorFormDialog(
          vendor: _editingVendor,
          onClose: () => setState(() => _showVendorForm = false),
          onSaved: () { setState(() => _showVendorForm = false); _load(); },
        ),
      if (_openFee != null)
        _FeeDetailDialog(
          feeId: _openFee!.id,
          onClose: () => setState(() => _openFee = null),
          onChanged: _load,
        ),
      if (_openJob != null)
        _JobDetailDialog(
          jobId: _openJob!.id,
          onClose: () => setState(() => _openJob = null),
          onChanged: _load,
        ),
    ]);
  }

  Widget _feesTab(bool opsTier) {
    if (_fees.isEmpty) {
      return const Center(child: Text('No vendor fees recorded yet.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _fees.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final f = _fees[i];
        final (fg, bg, label) = _feeStatusStyle(f.status);
        return _Card(
          onTap: () => setState(() => _openFee = f),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f.vendorName ?? '—', style: AppTheme.bodyStrong),
              const SizedBox(height: 2),
              Text(f.description, style: AppTheme.bodySub.copyWith(color: AppColors.textMute)),
              if (f.deliveryJob != null) ...[
                const SizedBox(height: 2),
                Text('Job ${f.deliveryJob!.jobNumber}', style: AppTheme.monoSm.copyWith(fontSize: 11, color: AppColors.textMute)),
              ],
            ])),
            Text(tshFromDouble(f.billedAmount), style: AppTheme.bodyStrong),
            const SizedBox(width: 16),
            _Chip(fg: fg, bg: bg, label: label),
          ]),
        );
      },
    );
  }

  Widget _jobsTab(bool opsTier) {
    if (_jobs.isEmpty) {
      return const Center(child: Text('No delivery jobs recorded yet.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _jobs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final j = _jobs[i];
        return _Card(
          onTap: () => setState(() => _openJob = j),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(j.jobNumber, style: AppTheme.monoSm.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(j.destination ?? '—', style: AppTheme.bodySub.copyWith(color: AppColors.textMute)),
            ])),
            _Chip(
              fg: j.hasDeliveryNote ? AppColors.teal : AppColors.amber,
              bg: j.hasDeliveryNote ? AppColors.tealSoft : AppColors.amberSoft,
              label: j.hasDeliveryNote ? 'Note attached' : 'No note',
            ),
          ]),
        );
      },
    );
  }

  Widget _vendorsTab(bool opsTier) {
    if (_vendors.isEmpty) {
      return const Center(child: Text('No vendors on file yet.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _vendors.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final v = _vendors[i];
        return _Card(
          onTap: opsTier ? () => setState(() { _editingVendor = v; _showVendorForm = true; }) : null,
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.name, style: AppTheme.bodyStrong),
              const SizedBox(height: 2),
              Text(v.typeLabel, style: AppTheme.bodySub.copyWith(color: AppColors.textMute)),
            ])),
            _Chip(
              fg: v.isActive ? AppColors.teal : AppColors.textMute,
              bg: v.isActive ? AppColors.tealSoft : const Color(0x0AFFFFFF),
              label: v.isActive ? 'Active' : 'Inactive',
            ),
          ]),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: context.pal.surface1,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: context.pal.border)),
        child: child,
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.fg, required this.bg, required this.label});
  final Color fg;
  final Color bg;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: fg.withValues(alpha: 0.3))),
    child: Text(label, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w500)),
  );
}

class _DialogShell extends StatelessWidget {
  const _DialogShell({required this.title, required this.icon, required this.onClose, required this.body, this.width = 460, this.footer});
  final String title;
  final IconData icon;
  final VoidCallback onClose;
  final Widget body;
  final double width;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onClose,
    child: Container(
      color: const Color(0xAA06070A),
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          width: width,
          constraints: const BoxConstraints(maxHeight: 640),
          decoration: BoxDecoration(
            color: context.pal.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.pal.borderStrong),
            boxShadow: const [BoxShadow(color: Color(0x70000000), blurRadius: 60, offset: Offset(0, 20))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                Icon(icon, size: 18, color: AppColors.teal),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: AppTheme.bodyStrong)),
                GestureDetector(onTap: onClose, child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
              ]),
            ),
            Flexible(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: body)),
            if (footer != null)
              Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), child: footer!),
          ]),
        ),
      ),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: AppTheme.labelCaps.copyWith(fontSize: 10)),
  );
}

InputDecoration _fieldDecoration(BuildContext context) => InputDecoration(
  isDense: true,
  filled: true,
  fillColor: context.pal.surface2,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.pal.border)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.pal.border)),
);

// ── Create Vendor Fee ────────────────────────────────────────────────────

class _CreateFeeDialog extends StatefulWidget {
  const _CreateFeeDialog({required this.vendors, required this.deliveryJobs, required this.onClose, required this.onSaved});
  final List<Vendor> vendors;
  final List<DeliveryJob> deliveryJobs;
  final VoidCallback onClose;
  final VoidCallback onSaved;

  @override
  State<_CreateFeeDialog> createState() => _CreateFeeDialogState();
}

class _CreateFeeDialogState extends State<_CreateFeeDialog> {
  Vendor? _vendor;
  DeliveryJob? _job;
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() { _descCtrl.dispose(); _amountCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_saving || _vendor == null || _descCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Vendor and description are required.');
      return;
    }
    final amount = int.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount < 1) { setState(() => _error = 'Enter a valid billed amount.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      await VendorFeeService.instance.createFee(
        vendorId: _vendor!.id, deliveryJobId: _job?.id,
        description: _descCtrl.text.trim(), billedAmount: amount,
      );
      widget.onSaved();
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) => _DialogShell(
    title: 'Record vendor fee',
    icon: Symbols.receipt_long,
    onClose: widget.onClose,
    footer: Row(children: [
      const Spacer(),
      AppButton(label: 'Cancel', variant: BtnVariant.ghost, onPressed: widget.onClose),
      const SizedBox(width: 8),
      AppButton(label: _saving ? 'Saving…' : 'Save', variant: BtnVariant.primary, onPressed: _saving ? null : _save),
    ]),
    body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_error != null) ...[
        Container(width: double.infinity, padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: AppColors.coralSoft, borderRadius: BorderRadius.circular(8)),
          child: Text(_error!, style: TextStyle(color: AppColors.coral, fontSize: 12))),
      ],
      const _FieldLabel('VENDOR *'),
      DropdownButtonFormField<Vendor>(
        initialValue: _vendor,
        decoration: _fieldDecoration(context),
        items: widget.vendors.map((v) => DropdownMenuItem(value: v, child: Text('${v.name} (${v.typeLabel})', overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) => setState(() => _vendor = v),
      ),
      const SizedBox(height: 14),
      const _FieldLabel('DELIVERY JOB (USIRI only — optional)'),
      DropdownButtonFormField<DeliveryJob?>(
        initialValue: _job,
        decoration: _fieldDecoration(context),
        items: [
          const DropdownMenuItem(value: null, child: Text('— Not linked —')),
          ...widget.deliveryJobs.map((j) => DropdownMenuItem(value: j, child: Text(j.jobNumber))),
        ],
        onChanged: (j) => setState(() => _job = j),
      ),
      const SizedBox(height: 14),
      const _FieldLabel('DESCRIPTION *'),
      TextField(controller: _descCtrl, decoration: _fieldDecoration(context)),
      const SizedBox(height: 14),
      const _FieldLabel('BILLED AMOUNT (TZS) *'),
      TextField(controller: _amountCtrl, keyboardType: TextInputType.number, decoration: _fieldDecoration(context)),
    ]),
  );
}

// ── Vendor Fee detail ────────────────────────────────────────────────────

class _FeeDetailDialog extends StatefulWidget {
  const _FeeDetailDialog({required this.feeId, required this.onClose, required this.onChanged});
  final int feeId;
  final VoidCallback onClose;
  final VoidCallback onChanged;

  @override
  State<_FeeDetailDialog> createState() => _FeeDetailDialogState();
}

class _FeeDetailDialogState extends State<_FeeDetailDialog> {
  VendorFee? _fee;
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final fee = await VendorFeeService.instance.fee(widget.feeId);
      if (mounted) setState(() { _fee = fee; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  Future<void> _uploadReceipt() async {
    final fee = _fee;
    if (fee == null) return;
    final data = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _ReceiptUploadDialog(issuerHint: fee.vendorName));
    if (!mounted || data == null) return;
    if (Platform.isAndroid) {
      showErrorToast(context, Exception('File uploads aren\'t available on Android in this build.'));
      return;
    }
    final result = await FilePicker.pickFiles(allowMultiple: false, withData: false);
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    setState(() => _busy = true);
    try {
      await VendorFeeService.instance.uploadReceipt(
        fee.id, result.files.first.path!, result.files.first.name,
        receiptType: data['receipt_type'], receiptNumber: data['receipt_number'],
        issuerName: data['issuer_name'], issuerTin: data['issuer_tin'],
        receiptDate: data['receipt_date'], amount: data['amount'],
      );
      if (mounted) { showSuccessToast(context, 'Receipt attached.'); await _load(); widget.onChanged(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyReceipt(VendorReceipt r) async {
    setState(() => _busy = true);
    try {
      await VendorFeeService.instance.verifyReceipt(widget.feeId, r.id);
      if (mounted) { showSuccessToast(context, 'Receipt verified.'); await _load(); widget.onChanged(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteReceipt(VendorReceipt r) async {
    setState(() => _busy = true);
    try {
      await VendorFeeService.instance.deleteReceipt(widget.feeId, r.id);
      if (mounted) { showSuccessToast(context, 'Receipt removed.'); await _load(); widget.onChanged(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitForPayment() async {
    setState(() => _busy = true);
    try {
      await VendorFeeService.instance.submitForPayment(widget.feeId);
      if (mounted) { showSuccessToast(context, 'Submitted for payment approval.'); await _load(); widget.onChanged(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve() async {
    final ref = await showDialog<String>(context: context, builder: (_) => const _PaymentReferenceDialog());
    if (ref == null || ref.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await VendorFeeService.instance.approve(widget.feeId, paymentReference: ref.trim());
      if (mounted) { showSuccessToast(context, 'Payment approved.'); await _load(); widget.onChanged(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(context: context, builder: (_) => const _ReasonDialog(title: 'Reject vendor fee', minLength: 10));
    if (reason == null || reason.trim().length < 10) return;
    setState(() => _busy = true);
    try {
      await VendorFeeService.instance.reject(widget.feeId, reason: reason.trim());
      if (mounted) { showSuccessToast(context, 'Vendor fee rejected.'); await _load(); widget.onChanged(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = userRoleNotifier.value;
    final opsTier = _isVendorOpsTier(role);
    final canVerify = _canVerifyReceipts(role);
    final canSubmit = hasAccountantAuthority(role);
    final canApproveReject = hasDirectorAuthority(role);
    final fee = _fee;

    return _DialogShell(
      title: fee?.description ?? 'Vendor fee',
      icon: Symbols.receipt_long,
      onClose: widget.onClose,
      width: 560,
      footer: fee == null ? null : Row(children: [
        if (fee.status == VendorFeeStatus.pendingReceipt && canSubmit)
          AppButton(label: 'Submit for Payment', variant: BtnVariant.primary, icon: Symbols.check,
            onPressed: (_busy || !fee.isPayable) ? null : _submitForPayment),
        if (fee.status == VendorFeeStatus.readyForPayment && canApproveReject) ...[
          AppButton(label: 'Approve & Pay', variant: BtnVariant.primary, icon: Symbols.check, onPressed: _busy ? null : _approve),
          const SizedBox(width: 8),
          AppButton(label: 'Reject', variant: BtnVariant.danger, icon: Symbols.close, onPressed: _busy ? null : _reject),
        ],
        const Spacer(),
        AppButton(label: 'Close', variant: BtnVariant.ghost, onPressed: widget.onClose),
      ]),
      body: _loading
          ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
          : _error != null
              ? Text(_error!, style: TextStyle(color: AppColors.coral))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(fee!.vendorName ?? '—', style: AppTheme.bodyStrong)),
                    Text(tshFromDouble(fee.billedAmount), style: AppTheme.bodyStrong),
                  ]),
                  const SizedBox(height: 4),
                  Builder(builder: (_) {
                    final (fg, bg, label) = _feeStatusStyle(fee.status);
                    return _Chip(fg: fg, bg: bg, label: label);
                  }),
                  if (fee.paymentBlockReason != null) ...[
                    const SizedBox(height: 12),
                    Container(width: double.infinity, padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.amberSoft, borderRadius: BorderRadius.circular(8)),
                      child: Text(fee.paymentBlockReason!, style: TextStyle(color: AppColors.amber, fontSize: 12.5))),
                  ],
                  if (fee.rejectionReason != null) ...[
                    const SizedBox(height: 12),
                    Container(width: double.infinity, padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.coralSoft, borderRadius: BorderRadius.circular(8)),
                      child: Text('Rejected by ${fee.rejectedBy ?? '—'} — ${fee.rejectionReason}', style: TextStyle(color: AppColors.coral, fontSize: 12.5))),
                  ],
                  if (fee.paymentReference != null) ...[
                    const SizedBox(height: 12),
                    Container(width: double.infinity, padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.tealSoft, borderRadius: BorderRadius.circular(8)),
                      child: Text('Paid by ${fee.paidBy ?? '—'} · Ref ${fee.paymentReference}', style: TextStyle(color: AppColors.teal, fontSize: 12.5))),
                  ],
                  const SizedBox(height: 20),
                  Row(children: [
                    Text('RECEIPTS', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
                    const Spacer(),
                    if (opsTier && fee.status == VendorFeeStatus.pendingReceipt)
                      AppButton(label: 'Attach', icon: Symbols.add, variant: BtnVariant.ghost, small: true, onPressed: _busy ? null : _uploadReceipt),
                  ]),
                  const SizedBox(height: 8),
                  if (fee.receipts.isEmpty)
                    Text('No receipts attached yet.', style: TextStyle(color: AppColors.textMute, fontSize: 13))
                  else
                    ...fee.receipts.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: context.pal.surface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${r.receiptType.toUpperCase()} · ${r.receiptNumber}', style: AppTheme.monoSm.copyWith(fontSize: 12)),
                            Text('${r.issuerName} · ${tshFromDouble(r.amount)}', style: TextStyle(color: AppColors.textMute, fontSize: 11.5)),
                          ])),
                          if (r.verified)
                            _Chip(fg: AppColors.teal, bg: AppColors.tealSoft, label: 'Verified')
                          else ...[
                            _Chip(fg: AppColors.amber, bg: AppColors.amberSoft, label: 'Unverified'),
                            if (canVerify)
                              IconButton(icon: const Icon(Symbols.check, size: 16), onPressed: _busy ? null : () => _verifyReceipt(r), tooltip: 'Verify'),
                            if (opsTier)
                              IconButton(icon: Icon(Symbols.delete, size: 16, color: AppColors.coral), onPressed: _busy ? null : () => _deleteReceipt(r), tooltip: 'Remove'),
                          ],
                        ]),
                      ),
                    )),
                ]),
    );
  }
}

class _ReceiptUploadDialog extends StatefulWidget {
  const _ReceiptUploadDialog({this.issuerHint});
  final String? issuerHint;

  @override
  State<_ReceiptUploadDialog> createState() => _ReceiptUploadDialogState();
}

class _ReceiptUploadDialogState extends State<_ReceiptUploadDialog> {
  String _type = 'efd';
  final _numberCtrl = TextEditingController();
  late final _issuerCtrl = TextEditingController(text: widget.issuerHint ?? '');
  final _tinCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  final _amountCtrl = TextEditingController();

  @override
  void dispose() { _numberCtrl.dispose(); _issuerCtrl.dispose(); _tinCtrl.dispose(); _amountCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Attach receipt'),
    content: SizedBox(width: 380, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      DropdownButtonFormField<String>(
        initialValue: _type,
        decoration: const InputDecoration(labelText: 'Receipt type'),
        items: const [DropdownMenuItem(value: 'efd', child: Text('EFD')), DropdownMenuItem(value: 'other', child: Text('Other'))],
        onChanged: (v) => setState(() => _type = v ?? 'efd'),
      ),
      TextField(controller: _numberCtrl, decoration: const InputDecoration(labelText: 'Receipt number')),
      TextField(controller: _issuerCtrl, decoration: const InputDecoration(labelText: 'Issuer name')),
      TextField(controller: _tinCtrl, decoration: const InputDecoration(labelText: 'Issuer TIN (optional)')),
      TextField(controller: _amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (TZS)')),
      const SizedBox(height: 8),
      Row(children: [
        Text('Date: ${_date.toIso8601String().substring(0, 10)}'),
        const Spacer(),
        TextButton(onPressed: () async {
          final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
          if (picked != null) setState(() => _date = picked);
        }, child: const Text('Change')),
      ]),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () {
        final amount = int.tryParse(_amountCtrl.text.trim());
        if (_numberCtrl.text.trim().isEmpty || _issuerCtrl.text.trim().isEmpty || amount == null || amount < 1) return;
        Navigator.pop(context, {
          'receipt_type': _type, 'receipt_number': _numberCtrl.text.trim(), 'issuer_name': _issuerCtrl.text.trim(),
          'issuer_tin': _tinCtrl.text.trim().isEmpty ? null : _tinCtrl.text.trim(),
          'receipt_date': _date.toIso8601String().substring(0, 10), 'amount': amount,
        });
      }, child: const Text('Pick file & attach')),
    ],
  );
}

class _PaymentReferenceDialog extends StatefulWidget {
  const _PaymentReferenceDialog();
  @override
  State<_PaymentReferenceDialog> createState() => _PaymentReferenceDialogState();
}

class _PaymentReferenceDialogState extends State<_PaymentReferenceDialog> {
  final _ctrl = TextEditingController();
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Approve & release payment'),
    content: TextField(controller: _ctrl, decoration: const InputDecoration(labelText: 'Transfer reference'), autofocus: true),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(context, _ctrl.text), child: const Text('Approve & Pay')),
    ],
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title, this.minLength = 0});
  final String title;
  final int minLength;
  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _ctrl = TextEditingController();
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(controller: _ctrl, decoration: InputDecoration(labelText: widget.minLength > 0 ? 'Reason (min. ${widget.minLength} characters)' : 'Reason'), maxLines: 3, autofocus: true),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(context, _ctrl.text), child: const Text('Confirm')),
    ],
  );
}

// ── Delivery jobs ────────────────────────────────────────────────────────

class _CreateJobDialog extends StatefulWidget {
  const _CreateJobDialog({required this.deliveryVendors, required this.onClose, required this.onSaved});
  final List<Vendor> deliveryVendors;
  final VoidCallback onClose;
  final VoidCallback onSaved;

  @override
  State<_CreateJobDialog> createState() => _CreateJobDialogState();
}

class _CreateJobDialogState extends State<_CreateJobDialog> {
  final _numberCtrl = TextEditingController();
  Vendor? _vendor;
  final _destCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final List<_GoodsLineControllers> _lines = [_GoodsLineControllers()];
  bool _saving = false;
  String? _error;

  @override
  void initState() { super.initState(); _vendor = widget.deliveryVendors.isNotEmpty ? widget.deliveryVendors.first : null; }

  @override
  void dispose() {
    _numberCtrl.dispose(); _destCtrl.dispose(); _addressCtrl.dispose();
    for (final l in _lines) { l.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _vendor == null || _numberCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Job number and vendor are required.');
      return;
    }
    final goods = _lines.where((l) => l.itemCtrl.text.trim().isNotEmpty).map((l) => DeliveryGoodsLine(
      item: l.itemCtrl.text.trim(),
      serial: l.serialCtrl.text.trim().isEmpty ? null : l.serialCtrl.text.trim(),
      quantity: int.tryParse(l.qtyCtrl.text.trim()) ?? 1,
    )).toList();
    if (goods.isEmpty) { setState(() => _error = 'Add at least one goods line.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      await VendorFeeService.instance.createDeliveryJob(
        jobNumber: _numberCtrl.text.trim(), vendorId: _vendor!.id,
        destinationName: _destCtrl.text.trim().isEmpty ? null : _destCtrl.text.trim(),
        destinationAddress: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        goodsList: goods,
      );
      widget.onSaved();
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) => _DialogShell(
    title: 'New delivery job',
    icon: Symbols.local_shipping,
    onClose: widget.onClose,
    footer: Row(children: [
      const Spacer(),
      AppButton(label: 'Cancel', variant: BtnVariant.ghost, onPressed: widget.onClose),
      const SizedBox(width: 8),
      AppButton(label: _saving ? 'Saving…' : 'Create job', variant: BtnVariant.primary, onPressed: _saving ? null : _save),
    ]),
    body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_error != null) ...[
        Container(width: double.infinity, padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: AppColors.coralSoft, borderRadius: BorderRadius.circular(8)),
          child: Text(_error!, style: TextStyle(color: AppColors.coral, fontSize: 12))),
      ],
      if (widget.deliveryVendors.isEmpty)
        Text('No delivery-type vendors yet — add one first.', style: TextStyle(color: AppColors.amber, fontSize: 12.5)),
      const _FieldLabel('JOB NUMBER *'),
      TextField(controller: _numberCtrl, decoration: _fieldDecoration(context)),
      const SizedBox(height: 14),
      const _FieldLabel('VENDOR (USIRI / delivery) *'),
      DropdownButtonFormField<Vendor>(
        initialValue: _vendor,
        decoration: _fieldDecoration(context),
        items: widget.deliveryVendors.map((v) => DropdownMenuItem(value: v, child: Text(v.name))).toList(),
        onChanged: (v) => setState(() => _vendor = v),
      ),
      const SizedBox(height: 14),
      const _FieldLabel('DESTINATION NAME'),
      TextField(controller: _destCtrl, decoration: _fieldDecoration(context)),
      const SizedBox(height: 14),
      const _FieldLabel('DESTINATION ADDRESS'),
      TextField(controller: _addressCtrl, decoration: _fieldDecoration(context), maxLines: 2),
      const SizedBox(height: 14),
      const _FieldLabel('GOODS LIST *'),
      ..._lines.map((l) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(flex: 2, child: TextField(controller: l.itemCtrl, decoration: _fieldDecoration(context).copyWith(hintText: 'Item'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: l.serialCtrl, decoration: _fieldDecoration(context).copyWith(hintText: 'Serial'))),
          const SizedBox(width: 8),
          SizedBox(width: 60, child: TextField(controller: l.qtyCtrl, keyboardType: TextInputType.number, decoration: _fieldDecoration(context).copyWith(hintText: 'Qty'))),
          IconButton(icon: const Icon(Symbols.close, size: 16), onPressed: () => setState(() => _lines.remove(l))),
        ]),
      )),
      AppButton(label: 'Add item', icon: Symbols.add, variant: BtnVariant.ghost, small: true,
        onPressed: () => setState(() => _lines.add(_GoodsLineControllers()))),
    ]),
  );
}

class _GoodsLineControllers {
  final itemCtrl = TextEditingController();
  final serialCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');
  void dispose() { itemCtrl.dispose(); serialCtrl.dispose(); qtyCtrl.dispose(); }
}

class _JobDetailDialog extends StatefulWidget {
  const _JobDetailDialog({required this.jobId, required this.onClose, required this.onChanged});
  final int jobId;
  final VoidCallback onClose;
  final VoidCallback onChanged;

  @override
  State<_JobDetailDialog> createState() => _JobDetailDialogState();
}

class _JobDetailDialogState extends State<_JobDetailDialog> {
  DeliveryJob? _job;
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final job = await VendorFeeService.instance.deliveryJob(widget.jobId);
      if (mounted) setState(() { _job = job; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  Future<void> _uploadNote() async {
    final job = _job;
    if (job == null) return;
    final data = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _DeliveryNoteDialog(goodsList: job.goodsList));
    if (!mounted || data == null) return;
    if (Platform.isAndroid) {
      showErrorToast(context, Exception('File uploads aren\'t available on Android in this build.'));
      return;
    }
    final result = await FilePicker.pickFiles(allowMultiple: false, withData: false);
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    setState(() => _busy = true);
    try {
      await VendorFeeService.instance.uploadDeliveryNote(
        job.id, result.files.first.path!, result.files.first.name,
        receiverName: data['receiver_name'], deliveryDate: data['delivery_date'],
        deliveredGoods: data['delivered_goods'] as List<DeliveryGoodsLine>,
      );
      if (mounted) { showSuccessToast(context, 'Delivery note attached.'); await _load(); widget.onChanged(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final opsTier = _isVendorOpsTier(userRoleNotifier.value);
    final job = _job;
    return _DialogShell(
      title: job?.jobNumber ?? 'Delivery job',
      icon: Symbols.local_shipping,
      onClose: widget.onClose,
      width: 520,
      footer: Row(children: [
        if (job != null && !job.hasDeliveryNote && opsTier)
          AppButton(label: 'Attach delivery note', icon: Symbols.add, variant: BtnVariant.primary, onPressed: _busy ? null : _uploadNote),
        const Spacer(),
        AppButton(label: 'Close', variant: BtnVariant.ghost, onPressed: widget.onClose),
      ]),
      body: _loading
          ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
          : _error != null
              ? Text(_error!, style: TextStyle(color: AppColors.coral))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(job!.vendorName ?? '—', style: AppTheme.bodyStrong),
                  Text(job.destination ?? '—', style: TextStyle(color: AppColors.textMute, fontSize: 13)),
                  if (job.feeId != null) ...[
                    const SizedBox(height: 8),
                    Text('Already billed (fee #${job.feeId}).', style: TextStyle(color: AppColors.teal, fontSize: 12.5)),
                  ],
                  const SizedBox(height: 16),
                  Text('GOODS LIST', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
                  const SizedBox(height: 8),
                  ...job.goodsList.map((g) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('${g.item} × ${g.quantity}${g.serial != null ? ' (${g.serial})' : ''}', style: const TextStyle(fontSize: 13)),
                  )),
                  const SizedBox(height: 16),
                  Text('DELIVERY NOTE', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
                  const SizedBox(height: 8),
                  if (job.hasDeliveryNote) ...[
                    Text('Received by ${job.deliveryNoteReceiverName ?? '—'} on ${job.deliveryNoteDate ?? '—'}', style: const TextStyle(fontSize: 13)),
                    if (job.deliveryNoteGoodsMismatch)
                      Padding(padding: const EdgeInsets.only(top: 8), child: Container(width: double.infinity, padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.amberSoft, borderRadius: BorderRadius.circular(8)),
                        child: Text('The delivered goods list doesn\'t match the job\'s original goods list — review before paying.', style: TextStyle(color: AppColors.amber, fontSize: 12.5)))),
                  ] else
                    Text('No delivery note attached yet — required before this job\'s fee can be paid.', style: TextStyle(color: AppColors.textMute, fontSize: 13)),
                ]),
    );
  }
}

class _DeliveryNoteDialog extends StatefulWidget {
  const _DeliveryNoteDialog({required this.goodsList});
  final List<DeliveryGoodsLine> goodsList;

  @override
  State<_DeliveryNoteDialog> createState() => _DeliveryNoteDialogState();
}

class _DeliveryNoteDialogState extends State<_DeliveryNoteDialog> {
  final _receiverCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  late final List<_GoodsLineControllers> _lines = widget.goodsList.isEmpty
      ? [_GoodsLineControllers()]
      : widget.goodsList.map((g) {
          final c = _GoodsLineControllers();
          c.itemCtrl.text = g.item;
          c.serialCtrl.text = g.serial ?? '';
          c.qtyCtrl.text = g.quantity.toString();
          return c;
        }).toList();

  @override
  void dispose() { _receiverCtrl.dispose(); for (final l in _lines) { l.dispose(); } super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Attach signed delivery note'),
    content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(controller: _receiverCtrl, decoration: const InputDecoration(labelText: "Receiver's full name")),
      const SizedBox(height: 8),
      Row(children: [
        Text('Date: ${_date.toIso8601String().substring(0, 10)}'),
        const Spacer(),
        TextButton(onPressed: () async {
          final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
          if (picked != null) setState(() => _date = picked);
        }, child: const Text('Change')),
      ]),
      const SizedBox(height: 8),
      const Text('Delivered goods'),
      ..._lines.map((l) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(children: [
          Expanded(flex: 2, child: TextField(controller: l.itemCtrl, decoration: const InputDecoration(hintText: 'Item'))),
          const SizedBox(width: 6),
          Expanded(child: TextField(controller: l.serialCtrl, decoration: const InputDecoration(hintText: 'Serial'))),
          const SizedBox(width: 6),
          SizedBox(width: 50, child: TextField(controller: l.qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Qty'))),
        ]),
      )),
    ]))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () {
        if (_receiverCtrl.text.trim().isEmpty) return;
        final goods = _lines.where((l) => l.itemCtrl.text.trim().isNotEmpty).map((l) => DeliveryGoodsLine(
          item: l.itemCtrl.text.trim(), serial: l.serialCtrl.text.trim().isEmpty ? null : l.serialCtrl.text.trim(),
          quantity: int.tryParse(l.qtyCtrl.text.trim()) ?? 1,
        )).toList();
        Navigator.pop(context, {
          'receiver_name': _receiverCtrl.text.trim(),
          'delivery_date': _date.toIso8601String().substring(0, 10),
          'delivered_goods': goods,
        });
      }, child: const Text('Pick file & attach')),
    ],
  );
}

// ── Vendor form ──────────────────────────────────────────────────────────

class _VendorFormDialog extends StatefulWidget {
  const _VendorFormDialog({required this.onClose, required this.onSaved, this.vendor});
  final Vendor? vendor;
  final VoidCallback onClose;
  final VoidCallback onSaved;

  @override
  State<_VendorFormDialog> createState() => _VendorFormDialogState();
}

class _VendorFormDialogState extends State<_VendorFormDialog> {
  late final _nameCtrl = TextEditingController(text: widget.vendor?.name ?? '');
  late String _type = widget.vendor?.type ?? 'clearing';
  late final _tinCtrl = TextEditingController(text: widget.vendor?.tin ?? '');
  late String? _accountType = widget.vendor?.paymentAccountType;
  late final _accountNameCtrl = TextEditingController(text: widget.vendor?.paymentAccountName ?? '');
  late final _accountNumberCtrl = TextEditingController(text: widget.vendor?.paymentAccountNumber ?? '');
  late final _bankNameCtrl = TextEditingController(text: widget.vendor?.paymentBankName ?? '');
  late final _contactNameCtrl = TextEditingController(text: widget.vendor?.contactName ?? '');
  late final _contactPhoneCtrl = TextEditingController(text: widget.vendor?.contactPhone ?? '');
  late final _contactEmailCtrl = TextEditingController(text: widget.vendor?.contactEmail ?? '');
  late bool _isActive = widget.vendor?.isActive ?? true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose(); _tinCtrl.dispose(); _accountNameCtrl.dispose(); _accountNumberCtrl.dispose();
    _bankNameCtrl.dispose(); _contactNameCtrl.dispose(); _contactPhoneCtrl.dispose(); _contactEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _nameCtrl.text.trim().isEmpty) { setState(() => _error = 'Name is required.'); return; }
    setState(() { _saving = true; _error = null; });
    final data = {
      'name': _nameCtrl.text.trim(), 'type': _type,
      'tin': _tinCtrl.text.trim().isEmpty ? null : _tinCtrl.text.trim(),
      'payment_account_type': _accountType,
      'payment_account_name': _accountNameCtrl.text.trim().isEmpty ? null : _accountNameCtrl.text.trim(),
      'payment_account_number': _accountNumberCtrl.text.trim().isEmpty ? null : _accountNumberCtrl.text.trim(),
      'payment_bank_name': _bankNameCtrl.text.trim().isEmpty ? null : _bankNameCtrl.text.trim(),
      'contact_name': _contactNameCtrl.text.trim().isEmpty ? null : _contactNameCtrl.text.trim(),
      'contact_phone': _contactPhoneCtrl.text.trim().isEmpty ? null : _contactPhoneCtrl.text.trim(),
      'contact_email': _contactEmailCtrl.text.trim().isEmpty ? null : _contactEmailCtrl.text.trim(),
      if (widget.vendor != null) 'is_active': _isActive,
    };
    try {
      if (widget.vendor != null) {
        await VendorFeeService.instance.updateVendor(widget.vendor!.id, data);
      } else {
        await VendorFeeService.instance.createVendor(data);
      }
      widget.onSaved();
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) => _DialogShell(
    title: widget.vendor != null ? 'Edit vendor' : 'Add vendor',
    icon: Symbols.local_shipping,
    onClose: widget.onClose,
    footer: Row(children: [
      const Spacer(),
      AppButton(label: 'Cancel', variant: BtnVariant.ghost, onPressed: widget.onClose),
      const SizedBox(width: 8),
      AppButton(label: _saving ? 'Saving…' : 'Save', variant: BtnVariant.primary, onPressed: _saving ? null : _save),
    ]),
    body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_error != null) ...[
        Container(width: double.infinity, padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: AppColors.coralSoft, borderRadius: BorderRadius.circular(8)),
          child: Text(_error!, style: TextStyle(color: AppColors.coral, fontSize: 12))),
      ],
      const _FieldLabel('NAME *'),
      TextField(controller: _nameCtrl, decoration: _fieldDecoration(context)),
      const SizedBox(height: 14),
      const _FieldLabel('TYPE *'),
      DropdownButtonFormField<String>(
        initialValue: _type,
        decoration: _fieldDecoration(context),
        items: const [
          DropdownMenuItem(value: 'clearing', child: Text('Clearing / transit')),
          DropdownMenuItem(value: 'delivery', child: Text('Delivery')),
          DropdownMenuItem(value: 'other', child: Text('Other')),
        ],
        onChanged: (v) => setState(() => _type = v ?? 'clearing'),
      ),
      const SizedBox(height: 14),
      const _FieldLabel('TIN'),
      TextField(controller: _tinCtrl, decoration: _fieldDecoration(context)),
      const SizedBox(height: 14),
      const _FieldLabel('PAYMENT ACCOUNT TYPE'),
      DropdownButtonFormField<String?>(
        initialValue: _accountType,
        decoration: _fieldDecoration(context),
        items: const [
          DropdownMenuItem(value: null, child: Text('—')),
          DropdownMenuItem(value: 'bank', child: Text('Bank')),
          DropdownMenuItem(value: 'mobile_money', child: Text('Mobile money')),
        ],
        onChanged: (v) => setState(() => _accountType = v),
      ),
      const SizedBox(height: 14),
      const _FieldLabel('ACCOUNT NAME'),
      TextField(controller: _accountNameCtrl, decoration: _fieldDecoration(context)),
      const SizedBox(height: 14),
      const _FieldLabel('ACCOUNT NUMBER'),
      TextField(controller: _accountNumberCtrl, decoration: _fieldDecoration(context)),
      const SizedBox(height: 14),
      const _FieldLabel('BANK NAME'),
      TextField(controller: _bankNameCtrl, decoration: _fieldDecoration(context)),
      const SizedBox(height: 14),
      const _FieldLabel('CONTACT NAME'),
      TextField(controller: _contactNameCtrl, decoration: _fieldDecoration(context)),
      const SizedBox(height: 14),
      const _FieldLabel('CONTACT PHONE'),
      TextField(controller: _contactPhoneCtrl, decoration: _fieldDecoration(context)),
      const SizedBox(height: 14),
      const _FieldLabel('CONTACT EMAIL'),
      TextField(controller: _contactEmailCtrl, decoration: _fieldDecoration(context)),
      if (widget.vendor != null) ...[
        const SizedBox(height: 14),
        Row(children: [
          Checkbox(value: _isActive, onChanged: (v) => setState(() => _isActive = v ?? true)),
          const Text('Active'),
        ]),
      ],
    ]),
  );
}
