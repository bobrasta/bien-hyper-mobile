import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/my_service_report.dart';
import '../../services/my_reports_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_palette.dart';
import '../../utils/api_error.dart';
import '../../utils/pdf_download.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/labeled_field.dart';

// Section 7: "My past service reports" — a technician's own uploaded
// service/installation report files, searchable/filterable, downloadable,
// and each one linking straight back to the ticket it came from.
class MyServiceReportsScreen extends StatefulWidget {
  const MyServiceReportsScreen({super.key, this.onOpenTicket});
  final void Function(int ticketId)? onOpenTicket;

  @override
  State<MyServiceReportsScreen> createState() => _MyServiceReportsScreenState();
}

class _MyServiceReportsScreenState extends State<MyServiceReportsScreen> {
  List<MyServiceReport> _reports = [];
  bool    _loading = true;
  String? _error;

  final _ticketCtrl = TextEditingController();
  String? _typeFilter; // null = all, 'repair', 'installation'

  @override
  void initState() {
    super.initState();
    // Stale-while-revalidate: show the last-known default (unfiltered)
    // report list instantly if cached, then quietly refresh — same
    // reasoning as MachineListScreen.
    final cached = MyReportsService.cachedDefaultList;
    if (cached != null) { _reports = cached; _loading = false; }
    _load();
  }

  @override
  void dispose() {
    _ticketCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      if (_reports.isEmpty) _loading = true;
      _error = null;
    });
    try {
      final results = await MyReportsService.instance.serviceReports(
        ticketNumber: _ticketCtrl.text.trim().isEmpty ? null : _ticketCtrl.text.trim(),
        type: _typeFilter,
      );
      if (mounted) setState(() { _reports = results; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  Future<void> _download(MyServiceReport r) => downloadPdf(
    context, () => MyReportsService.instance.fetchBytes(r.url), r.name,
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, cst) {
      final pad = cst.maxWidth < 560 ? 16.0 : 28.0;
      return RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(pad),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('My Reports', style: AppTheme.pageTitle),
            const SizedBox(height: 4),
            Text('Service and installation reports from work you\'ve done', style: AppTheme.bodySub),
            const SizedBox(height: 20),
            _FilterRow(
              ticketCtrl: _ticketCtrl,
              typeFilter: _typeFilter,
              onTypeChanged: (v) { setState(() => _typeFilter = v); _load(); },
              onSearch: _load,
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 48), child: CircularProgressIndicator(strokeWidth: 2)))
            // A background refresh failing while stale-but-valid cached
            // data is already showing shouldn't blow that away.
            else if (_error != null && _reports.isEmpty)
              ErrorView(message: _error!, onRetry: _load)
            else if (_reports.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 32), child: Center(child: Text('No reports found', style: TextStyle(color: context.pal.textMute))))
            else
              Column(children: _reports.map((r) => _ReportCard(
                report: r,
                onDownload: () => _download(r),
                onOpenTicket: widget.onOpenTicket == null ? null : () => widget.onOpenTicket!(r.ticketId),
              )).toList()),
          ]),
        ),
      );
    });
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.ticketCtrl, required this.typeFilter, required this.onTypeChanged, required this.onSearch});
  final TextEditingController ticketCtrl;
  final String? typeFilter;
  final ValueChanged<String?> onTypeChanged;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 10, runSpacing: 10, children: [
    SearchField(width: 220, hint: 'Ticket number', controller: ticketCtrl, onSubmitted: (_) => onSearch()),
    DropdownFieldBox<String?>(
      value: typeFilter,
      hint: 'All types',
      items: const [
          DropdownMenuItem(value: null, child: Text('All types')),
          DropdownMenuItem(value: 'repair', child: Text('Service reports')),
          DropdownMenuItem(value: 'installation', child: Text('Installation reports')),
        ],
      onChanged: onTypeChanged,
    ),
    GestureDetector(
      onTap: onSearch,
      child: Container(
        height: kFieldHeight,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(10)),
        child: Center(child: Text('Search', style: AppTheme.bodySm.copyWith(color: const Color(0xFF06120F), fontWeight: FontWeight.w600))),
      ),
    ),
  ]);
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onDownload, this.onOpenTicket});
  final MyServiceReport report;
  final VoidCallback onDownload;
  final VoidCallback? onOpenTicket;

  IconData get _icon => switch (report.mimeType) {
    'application/pdf' => Symbols.picture_as_pdf,
    'image/png' || 'image/jpeg' => Symbols.image,
    _ => Symbols.description,
  };

  String _fmtBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.pal.surface1,
      borderRadius: BorderRadius.circular(AppColors.rLg),
      border: Border.all(color: context.pal.border),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(_icon, size: 20, color: AppColors.teal),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(report.name, style: AppTheme.bodyStrong.copyWith(fontSize: 13.5), overflow: TextOverflow.ellipsis),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: context.pal.surface2, borderRadius: BorderRadius.circular(999)),
            child: Text(report.ticketType == 'installation' ? 'Installation' : 'Service', style: AppTheme.bodySub.copyWith(fontSize: 10.5)),
          ),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 12, runSpacing: 4, children: [
          GestureDetector(
            onTap: onOpenTicket,
            child: Text('Ticket ${report.ticketNumber}', style: AppTheme.bodySm.copyWith(
              fontSize: 12.5, color: onOpenTicket != null ? AppColors.teal : null,
              decoration: onOpenTicket != null ? TextDecoration.underline : null,
            )),
          ),
          if (report.hospitalName != null) Text(report.hospitalName!, style: AppTheme.bodySub.copyWith(fontSize: 12.5)),
          if (report.machines.isNotEmpty)
            Text(report.machines.map((m) => m.serialNo ?? m.model ?? '—').join(', '), style: AppTheme.bodySub.copyWith(fontSize: 12.5)),
          Text(_fmtBytes(report.size), style: AppTheme.bodySub.copyWith(fontSize: 12.5)),
        ]),
      ])),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: onDownload,
        child: Tooltip(message: 'Download', child: Icon(Symbols.download, size: 18, color: AppColors.teal)),
      ),
    ]),
  );
}
