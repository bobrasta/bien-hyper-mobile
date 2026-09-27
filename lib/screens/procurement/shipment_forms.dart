import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/machine.dart';
import '../../models/shipment.dart';
import '../../services/machine_service.dart';
import '../../services/shipment_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_error.dart';
import '../../utils/format.dart';
import '../../widgets/common/labeled_field.dart';
import '../../widgets/procurement/proc_widgets.dart';
import 'tender_forms.dart' show ProcDialog, formHeading, formRow, OptionalDateField, isoDate;

// Dialogs for Section 18: shipment create/edit, moving the status, the
// Section 16 clearing fee and linked machines. Every rule is checked again
// server-side (ShipmentFlow) — these only guide.

String _tsh(int v) => 'TSh ${v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';

Future<({String path, String name})?> pickShipmentFile(BuildContext context) async {
  if (Platform.isAndroid) {
    showErrorToast(context, Exception('File uploads aren\'t available on Android in this build.'));
    return null;
  }
  final r = await FilePicker.pickFiles(allowMultiple: false, withData: false,
      type: FileType.custom, allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx', 'xls', 'xlsx']);
  if (r == null || r.files.isEmpty || r.files.first.path == null) return null;
  return (path: r.files.first.path!, name: r.files.first.name);
}

/// Mirrors ShipmentFlow::requiredDocTypes on the API.
List<String> requiredShipmentDocs(String direction, String mode) => [
  mode == 'air' ? 'air_waybill' : 'bill_of_lading',
  'packing_list',
  'commercial_invoice',
  if (direction == 'import') 'coa',
];

const shipmentDocLabels = {
  'air_waybill': 'Air Waybill',
  'bill_of_lading': 'Bill of Lading',
  'packing_list': 'Packing list',
  'commercial_invoice': 'Commercial invoice',
  'coa': 'Certificate of Analysis',
  'tmda_permit': 'TMDA permit',
  'recipient_receipt': 'Signed receipt from recipient',
};

// ── Create / edit ───────────────────────────────────────────────────────────

Future<Shipment?> showShipmentForm(BuildContext context, {Shipment? shipment, int? tenderId}) =>
    showDialog<Shipment>(context: context, builder: (_) => _ShipmentForm(shipment: shipment, tenderId: tenderId));

class _ShipmentForm extends StatefulWidget {
  const _ShipmentForm({this.shipment, this.tenderId});
  final Shipment? shipment;
  final int? tenderId;
  @override
  State<_ShipmentForm> createState() => _ShipmentFormState();
}

class _ShipmentFormState extends State<_ShipmentForm> {
  late final Shipment? s = widget.shipment;
  late String _dir = s?.direction ?? 'import';
  late String _mode = s?.freightMode ?? 'sea';
  late final _desc = TextEditingController(text: s?.description ?? '');
  late final _reason = TextEditingController(text: s?.outboundReason ?? '');
  late final _port = TextEditingController(text: s?.port ?? '');
  late final _notes = TextEditingController(text: s?.locationNotes ?? '');
  late DateTime? _eta = s?.expectedArrival;
  late int? _supplierId = s?.supplierId;
  late int? _poId = s?.purchaseOrderId;
  late int? _deptId = s?.departmentId;
  late int? _tenderId = (s?.tender?['id'] as num?)?.toInt() ?? widget.tenderId;
  final _files = <String, ({String path, String name})>{};
  ShipmentOptions? _opts;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    ShipmentService.instance.options().then((o) {
      if (mounted) setState(() => _opts = o);
    }).catchError((Object e) {
      if (mounted) showErrorToast(context, e);
    });
  }

  @override
  void dispose() {
    for (final c in [_desc, _reason, _port, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _attach(String type) async {
    final f = await pickShipmentFile(context);
    if (f != null && mounted) setState(() => _files[type] = f);
  }

  Future<void> _save() async {
    if (_desc.text.trim().isEmpty) {
      showErrorToast(context, Exception('Describe what is being shipped.'));
      return;
    }
    String? txt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final data = <String, dynamic>{
      if (s == null) 'direction': _dir,
      'freight_mode': _mode,
      'description': _desc.text.trim(),
      'supplier_id': _supplierId,
      'purchase_order_id': _dir == 'import' ? _poId : null,
      'outbound_reason': _dir == 'export' ? txt(_reason) : null,
      'department_id': _deptId,
      'tender_id': _tenderId,
      'expected_arrival': _eta == null ? null : isoDate(_eta!),
      'port': txt(_port),
      'location_notes': txt(_notes),
    };
    setState(() => _saving = true);
    try {
      final saved = s == null
          ? await ShipmentService.instance.create(data, {
              for (final e in _files.entries)
                if (requiredShipmentDocs(_dir, _mode).contains(e.key)) e.key: e.value,
            })
          : await ShipmentService.instance.update(s!.id, data);
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final o = _opts;
    final docs = requiredShipmentDocs(_dir, _mode);
    final attached = docs.where(_files.containsKey).length;
    final pos = (o?.purchaseOrders ?? []).where((p) => _supplierId == null || p['supplier_id'] == _supplierId).toList();

    return ProcDialog(
      title: s == null ? 'New shipment' : 'Edit ${s!.reference}',
      icon: Symbols.local_shipping,
      width: 720,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _saving || o == null ? null : _save,
          icon: const Icon(Symbols.check, size: 15),
          label: Text(_saving ? 'Saving…' : s == null ? 'Create shipment' : 'Save'),
        ),
      ],
      body: o == null
          ? const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              formRow([
                if (s == null)
                  LabeledDropdown<String>(label: 'Direction', value: _dir, items: const ['import', 'export'],
                      displayBuilder: (v) => v == 'import' ? 'Import' : 'Export', onChanged: (v) => setState(() => _dir = v))
                else
                  LabeledStaticField(label: 'Direction', value: s!.isImport ? 'Import' : 'Export'),
                LabeledDropdown<String>(label: 'Freight', value: _mode, items: const ['sea', 'air', 'road'],
                    displayBuilder: freightLabel, onChanged: (v) => setState(() => _mode = v)),
              ]),
              LabeledTextField(label: "What's being shipped", controller: _desc,
                  hint: 'e.g. Haematology analysers ×3 — Mnazi Mmoja Hospital'),
              const SizedBox(height: 12),
              formRow([
                LabeledDropdown<int?>(
                  label: _dir == 'import' ? 'Supplier' : 'Recipient (supplier)',
                  value: o.suppliers.any((x) => x['id'] == _supplierId) ? _supplierId : null,
                  items: [null, ...o.suppliers.map((x) => (x['id'] as num).toInt())],
                  displayBuilder: (id) => id == null ? 'Not set' : o.suppliers.firstWhere((x) => x['id'] == id)['name'] as String,
                  onChanged: (v) => setState(() {
                    _supplierId = v;
                    if (_poId != null && !o.purchaseOrders.any((p) => p['id'] == _poId && (v == null || p['supplier_id'] == v))) _poId = null;
                  }),
                ),
                if (_dir == 'import')
                  LabeledDropdown<int?>(
                    label: 'Purchase order',
                    value: pos.any((p) => p['id'] == _poId) ? _poId : null,
                    items: [null, ...pos.map((p) => (p['id'] as num).toInt())],
                    displayBuilder: (id) {
                      if (id == null) return 'Not linked';
                      final p = pos.firstWhere((x) => x['id'] == id);
                      return '${p['po_number']}${p['supplier_name'] == null ? '' : ' · ${p['supplier_name']}'}';
                    },
                    onChanged: (v) => setState(() => _poId = v),
                  )
                else
                  LabeledTextField(label: 'Reason for export', controller: _reason, hint: 'e.g. Warranty return, RMA 4471'),
              ]),
              formRow([
                LabeledDropdown<int?>(
                  label: 'Relevant department · its manager is notified',
                  value: o.departments.any((d) => d.id == _deptId) ? _deptId : null,
                  items: [null, ...o.departments.map((d) => d.id)],
                  displayBuilder: (id) {
                    if (id == null) return 'None';
                    final d = o.departments.firstWhere((x) => x.id == id);
                    return '${d.name} · ${d.managerName ?? 'no head set'}';
                  },
                  onChanged: (v) => setState(() => _deptId = v),
                ),
                LabeledDropdown<int?>(
                  label: 'Tender · optional',
                  value: o.tenders.any((t) => t['id'] == _tenderId) ? _tenderId : null,
                  items: [null, ...o.tenders.map((t) => (t['id'] as num).toInt())],
                  displayBuilder: (id) => id == null ? 'None' : o.tenders.firstWhere((t) => t['id'] == id)['tender_number'] as String,
                  onChanged: (v) => setState(() => _tenderId = v),
                ),
              ]),
              formRow([
                OptionalDateField(label: _dir == 'import' ? 'Expected arrival' : 'Expected delivery', value: _eta,
                    onChanged: (v) => setState(() => _eta = v)),
                LabeledTextField(label: _dir == 'import' ? 'Port / airport' : 'Destination', controller: _port,
                    hint: _dir == 'import' ? 'e.g. Dar es Salaam port' : null),
              ]),
              LabeledTextField(label: 'Location / notes · optional', controller: _notes, maxLines: 3,
                  hint: 'e.g. Loaded at Shenzhen, vessel MSC Aurora, ETA Dar 18 Oct'),
              if (s == null) ...[
                formHeading('Shipping documents · $attached / ${docs.length}'),
                for (final t in docs) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: pal.border)),
                  child: Row(children: [
                    Icon(_files.containsKey(t) ? Symbols.check_circle : Symbols.upload_file, size: 16,
                        color: _files.containsKey(t) ? AppColors.green : pal.textDim),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(shipmentDocLabels[t]!, style: AppTheme.bodySm.copyWith(fontSize: 12.5)),
                      if (_files[t] != null) Text(_files[t]!.name, style: AppTheme.bodySub.copyWith(fontSize: 11, color: pal.textDim),
                          overflow: TextOverflow.ellipsis),
                    ])),
                    TextButton(onPressed: () => _attach(t), child: Text(_files.containsKey(t) ? 'Replace' : 'Attach')),
                  ]),
                ),
                if (attached < docs.length)
                  ProcNote('Documents can follow later. Until all ${docs.length} are in, the shipment is flagged and can\'t move past '
                      '"${_dir == 'import' ? 'Shipped' : 'Preparing'}".', icon: Symbols.warning, tone: ProcTone.amber),
              ],
            ]),
    );
  }
}

// ── Move status ─────────────────────────────────────────────────────────────

Future<Shipment?> showShipmentStatusDialog(BuildContext context, Shipment s) =>
    showDialog<Shipment>(context: context, builder: (_) => _StatusDialog(s));

class _StatusDialog extends StatefulWidget {
  const _StatusDialog(this.s);
  final Shipment s;
  @override
  State<_StatusDialog> createState() => _StatusDialogState();
}

class _StatusDialogState extends State<_StatusDialog> {
  Shipment get s => widget.s;
  late int _step = s.step < s.lastStep ? s.step + 1 : s.step;
  final _note = TextEditingController();
  final _reason = TextEditingController();
  late final _appRef = TextEditingController(text: s.tmda?['application_ref'] as String? ?? '');
  late final _control = TextEditingController(text: s.controlNumber ?? '');
  late DateTime? _issued = s.tmda?['issued_at'] == null ? null : DateTime.tryParse(s.tmda!['issued_at'] as String);
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_note, _reason, _appRef, _control]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _back => _step < s.step;

  Future<void> _save() async {
    if (_step == s.step) {
      Navigator.pop(context);
      return;
    }
    if (_back && _reason.text.trim().length < 10) {
      showErrorToast(context, Exception('Going back a status needs a reason (at least 10 characters).'));
      return;
    }
    String? txt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    setState(() => _saving = true);
    try {
      final saved = await ShipmentService.instance.setStep(s.id, {
        'step': _step,
        'note': txt(_note),
        if (_back) 'reason': _reason.text.trim(),
        if (s.isImport && _step >= 4) 'tmda_application_ref': txt(_appRef),
        if (s.isImport && _step >= 5 && _issued != null) 'tmda_issued_at': isoDate(_issued!),
        if (s.isImport && _step >= 7) 'control_number': txt(_control),
      });
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final fee = s.clearingFee;
    return ProcDialog(
      title: 'Move ${s.reference}',
      icon: Symbols.route,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Symbols.check, size: 15),
            label: Text(_saving ? 'Saving…' : _back ? 'Correct status' : 'Update status')),
      ],
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Now: ${s.step}. ${s.statusLabel}', style: AppTheme.bodySub.copyWith(color: pal.textMute)),
        const SizedBox(height: 12),
        LabeledDropdown<int>(
          label: 'Move to',
          value: _step,
          items: [for (var i = 1; i <= s.lastStep; i++) i],
          displayBuilder: (i) => '$i. ${s.labelFor(i)}${i == s.step ? ' (current)' : i < s.step ? ' · correction' : ''}',
          onChanged: (v) => setState(() => _step = v),
        ),
        const SizedBox(height: 12),
        if (s.isImport && _step >= 4 && !_back) ...[
          LabeledTextField(label: 'TMDA permit application reference', controller: _appRef),
          const SizedBox(height: 12),
        ],
        if (s.isImport && _step >= 5 && !_back) ...[
          OptionalDateField(label: 'TMDA permit issued', value: _issued, onChanged: (v) => setState(() => _issued = v),
              hint: _step == 5 ? 'Required for this status' : 'Required before documents go to the clearing agent (unless switched off in settings)'),
          const SizedBox(height: 12),
        ],
        if (s.isImport && _step >= 7 && !_back) ...[
          LabeledTextField(label: "Clearing agent's control number", controller: _control),
          const SizedBox(height: 12),
        ],
        if (s.isImport && _step >= 8 && !_back)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: ProcNote(
            fee == null
                ? 'Link the clearing agent\'s vendor fee first. Payment runs through Section 16 (receipt, Finance check, Director approval).'
                : fee.paid ? 'Clearing fee ${_tsh(fee.billed)} is paid.' : 'Clearing fee: ${fee.statusLabel}. ${fee.blockReason ?? ''}',
            icon: fee?.paid == true ? Symbols.verified : Symbols.info,
            tone: fee?.paid == true ? ProcTone.green : ProcTone.amber)),
        if (_back) ...[
          LabeledTextField(label: 'Reason for the correction · required', controller: _reason, maxLines: 2,
              hint: 'Logged on the timeline and sent with the notification'),
          const SizedBox(height: 12),
        ],
        LabeledTextField(label: 'Note · optional', controller: _note, maxLines: 2, hint: 'e.g. cleared customs, awaiting pickup by transporter'),
        const SizedBox(height: 8),
        Text('The CTO, MD, Sales Manager and the department manager are notified.',
            style: AppTheme.bodySub.copyWith(fontSize: 11, color: pal.textDim)),
      ]),
    );
  }
}

// ── Clearing fee (Section 16) ───────────────────────────────────────────────

Future<Shipment?> showClearingFeeDialog(BuildContext context, Shipment s) =>
    showDialog<Shipment>(context: context, builder: (_) => _ClearingFeeDialog(s));

class _ClearingFeeDialog extends StatefulWidget {
  const _ClearingFeeDialog(this.s);
  final Shipment s;
  @override
  State<_ClearingFeeDialog> createState() => _ClearingFeeDialogState();
}

class _ClearingFeeDialogState extends State<_ClearingFeeDialog> {
  ShipmentOptions? _opts;
  bool _existing = false;
  int? _feeId;
  int? _vendorId;
  final _amount = TextEditingController();
  late final _desc = TextEditingController(text: 'Clearing — ${widget.s.reference}');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    ShipmentService.instance.options().then((o) {
      if (!mounted) return;
      setState(() {
        _opts = o;
        final clearing = o.vendors.where((v) => v['type'] == 'clearing');
        _vendorId = clearing.isEmpty ? null : (clearing.first['id'] as num).toInt();
      });
    }).catchError((Object e) {
      if (mounted) showErrorToast(context, e);
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = int.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (_existing ? _feeId == null : (_vendorId == null || amount == null || amount < 1)) {
      showErrorToast(context, Exception(_existing ? 'Pick the vendor fee to link.' : 'Pick the clearing agent and enter the billed amount.'));
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await ShipmentService.instance.linkClearingFee(widget.s.id, _existing
          ? {'vendor_fee_id': _feeId}
          : {'vendor_id': _vendorId, 'billed_amount': amount, 'description': _desc.text.trim()});
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _opts;
    return ProcDialog(
      title: 'Clearing fee · ${widget.s.reference}',
      icon: Symbols.receipt_long,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton.icon(onPressed: _saving || o == null ? null : _save, icon: const Icon(Symbols.link, size: 15),
            label: Text(_saving ? 'Saving…' : _existing ? 'Link fee' : 'Record fee')),
      ],
      body: o == null
          ? const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const ProcNote('The clearing cost is a Section 16 vendor fee: no receipt, no payment. The receipt, Finance check and '
                  'Director approval all happen in Vendors & Delivery, not here.'),
              const SizedBox(height: 12),
              LabeledDropdown<bool>(label: 'Fee', value: _existing, items: const [false, true],
                  displayBuilder: (v) => v ? 'Link a fee already recorded' : 'Record a new fee',
                  onChanged: (v) => setState(() => _existing = v)),
              const SizedBox(height: 12),
              if (_existing)
                LabeledDropdown<int?>(
                  label: 'Vendor fee',
                  value: _feeId,
                  items: [null, ...o.openVendorFees.map((f) => (f['id'] as num).toInt())],
                  displayBuilder: (id) {
                    if (id == null) return o.openVendorFees.isEmpty ? 'No unlinked fees' : 'Select…';
                    final f = o.openVendorFees.firstWhere((x) => x['id'] == id);
                    return '${f['vendor_name'] ?? 'Vendor'} · ${_tsh((f['billed_amount'] as num).toInt())} · ${f['description']}';
                  },
                  onChanged: (v) => setState(() => _feeId = v),
                )
              else ...[
                LabeledDropdown<int?>(
                  label: 'Clearing agent',
                  value: o.vendors.any((v) => v['id'] == _vendorId) ? _vendorId : null,
                  items: [null, ...o.vendors.map((v) => (v['id'] as num).toInt())],
                  displayBuilder: (id) {
                    if (id == null) return o.vendors.isEmpty ? 'No vendors — add one in Vendors & Delivery' : 'Select…';
                    final v = o.vendors.firstWhere((x) => x['id'] == id);
                    return '${v['name']}${v['type'] == 'clearing' ? '' : ' · ${v['type']}'}';
                  },
                  onChanged: (v) => setState(() => _vendorId = v),
                ),
                const SizedBox(height: 12),
                formRow([
                  LabeledTextField(label: 'Billed amount (TZS)', controller: _amount, keyboardType: TextInputType.number),
                  LabeledTextField(label: 'Description', controller: _desc),
                ]),
              ],
            ]),
    );
  }
}

// ── Machines ────────────────────────────────────────────────────────────────

Future<Shipment?> showShipmentMachinesDialog(BuildContext context, Shipment s) =>
    showDialog<Shipment>(context: context, builder: (_) => _MachinesDialog(s));

class _MachinesDialog extends StatefulWidget {
  const _MachinesDialog(this.s);
  final Shipment s;
  @override
  State<_MachinesDialog> createState() => _MachinesDialogState();
}

class _MachinesDialogState extends State<_MachinesDialog> {
  List<Machine>? _all;
  late final Set<int> _picked = {for (final m in widget.s.machines) (m['id'] as num).toInt()};
  String _q = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    MachineService.instance.list().then((m) {
      if (mounted) setState(() => _all = m);
    }).catchError((Object e) {
      if (mounted) showErrorToast(context, e);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final saved = await ShipmentService.instance.syncMachines(widget.s.id, _picked.toList());
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final q = _q.toLowerCase();
    final rows = (_all ?? []).where((m) => _picked.contains(m.id) || q.isEmpty
        ? true
        : m.serialNo.toLowerCase().contains(q) || m.model.toLowerCase().contains(q) || m.type.toLowerCase().contains(q)).toList()
      ..sort((a, b) => (_picked.contains(b.id) ? 1 : 0) - (_picked.contains(a.id) ? 1 : 0));
    return ProcDialog(
      title: 'Machines on ${widget.s.reference}',
      icon: Symbols.precision_manufacturing,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton.icon(onPressed: _saving || _all == null ? null : _save, icon: const Icon(Symbols.save, size: 15),
            label: Text(_saving ? 'Saving…' : 'Save · ${_picked.length}')),
      ],
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Machines get their serials once the storekeeper receives them. Attach them here to keep the shipment\'s record complete.',
            style: AppTheme.bodySub.copyWith(fontSize: 11.5, color: pal.textDim)),
        const SizedBox(height: 10),
        ProcSearchField(hint: 'Serial, model, type…', width: double.infinity, onChanged: (v) => setState(() => _q = v)),
        const SizedBox(height: 10),
        if (_all == null)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else
          for (final m in rows.take(80)) CheckboxListTile(
            dense: true,
            value: _picked.contains(m.id),
            onChanged: (v) => setState(() => v == true ? _picked.add(m.id) : _picked.remove(m.id)),
            title: Text(m.serialNo, style: procMono(context, color: pal.text)),
            subtitle: Text('${m.model} · ${m.type}', style: AppTheme.bodySub.copyWith(fontSize: 11)),
          ),
      ]),
    );
  }
}

/// "18 Oct 2026" or "—".
String shipDate(DateTime? d) => d == null ? '—' : formatDate(d);
