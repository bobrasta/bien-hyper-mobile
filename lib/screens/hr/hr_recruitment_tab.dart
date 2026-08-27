import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../services/position_service.dart';
import '../../services/recruitment_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_palette.dart';
import '../../utils/api_error.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/labeled_field.dart';

class HrRecruitmentTab extends StatefulWidget {
  const HrRecruitmentTab({super.key});

  @override
  State<HrRecruitmentTab> createState() => _HrRecruitmentTabState();
}

class _HrRecruitmentTabState extends State<HrRecruitmentTab> with SingleTickerProviderStateMixin {
  late final _tab = TabController(length: 2, vsync: this);

  @override
  Widget build(BuildContext context) => Column(children: [
    TabBar(
      controller: _tab, isScrollable: true, tabAlignment: TabAlignment.start,
      labelColor: AppColors.teal, unselectedLabelColor: context.pal.textMute,
      indicatorColor: AppColors.teal,
      tabs: const [Tab(text: 'Vacancies'), Tab(text: 'Applicants / Talent Pool')],
    ),
    Expanded(child: TabBarView(controller: _tab, children: const [_VacanciesTab(), _ApplicantsTab()])),
  ]);
}

// ── Vacancies ────────────────────────────────────────────────────────────────

class _VacanciesTab extends StatefulWidget {
  const _VacanciesTab();
  @override
  State<_VacanciesTab> createState() => _VacanciesTabState();
}

class _VacanciesTabState extends State<_VacanciesTab> {
  List<Vacancy> _vacancies = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await RecruitmentService.instance.vacancies();
      if (mounted) setState(() { _vacancies = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _newVacancy() async {
    List<Position> positions = [];
    try { positions = await PositionService.instance.list(); } catch (_) {}
    if (!mounted) return;
    int? positionId = positions.isNotEmpty ? positions.first.id : null;
    final reqCtrl = TextEditingController();
    final go = await showDialog<bool>(context: context, builder: (dialogCtx) => StatefulBuilder(
      builder: (dialogCtx, setDialogState) => AlertDialog(
        backgroundColor: context.pal.surface1,
        title: Text('New Vacancy', style: AppTheme.cardTitle),
        content: SizedBox(width: 340, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          LabeledDropdown<int?>(
            label: 'Position',
            value: positionId,
            items: positions.map((p) => p.id).toList(),
            displayBuilder: (id) => positions.firstWhere((p) => p.id == id).title,
            onChanged: (v) => setDialogState(() => positionId = v),
          ),
          const SizedBox(height: 12),
          LabeledTextField(label: 'Requirements', controller: reqCtrl, maxLines: 3),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogCtx).pop(true), child: const Text('Create')),
        ],
      ),
    ));
    if (go != true || positionId == null) return;
    try {
      await RecruitmentService.instance.createVacancy({
        'position_id': positionId,
        'requirements': reqCtrl.text.trim().isNotEmpty ? reqCtrl.text.trim() : null,
      });
      _load();
    } catch (e) { if (mounted) showErrorToast(context, e); }
  }

  Future<void> _openPipeline(Vacancy v) async {
    final changed = await showDialog<bool>(context: context, builder: (_) => _PipelineDialog(vacancy: v));
    if (changed == true) _load();
  }

  Future<void> _setStatus(Vacancy v, String status) async {
    try {
      await RecruitmentService.instance.updateVacancy(v.id, {'status': status});
      _load();
    } catch (e) { if (mounted) showErrorToast(context, e); }
  }

  Color _statusColor(String s) => switch (s) {
    'open' => AppColors.teal, 'on_hold' => AppColors.amber, 'closed' => AppColors.textMute,
    _ => AppColors.textMute,
  };

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Align(alignment: Alignment.centerRight, child: FilledButton.icon(
          onPressed: _newVacancy, icon: const Icon(Symbols.add, size: 16), label: const Text('New Vacancy'),
        )),
        const SizedBox(height: 12),
        Expanded(
          child: _vacancies.isEmpty
              ? Center(child: Text('No vacancies yet.', style: AppTheme.bodySub))
              : ListView.separated(
                  itemCount: _vacancies.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final v = _vacancies[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.pal.surface1, borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.pal.border),
                      ),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text(v.positionTitle ?? '—', style: AppTheme.bodyStrong.copyWith(fontSize: 13.5)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: _statusColor(v.status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                              child: Text(v.status, style: AppTheme.monoXs.copyWith(color: _statusColor(v.status), fontSize: 10)),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Text('${v.applicationsCount} applicant(s) · opened ${v.openedAt}', style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
                        ])),
                        TextButton(onPressed: () => _openPipeline(v), child: const Text('View Pipeline')),
                        if (v.status == 'open') ...[
                          TextButton(onPressed: () => _setStatus(v, 'on_hold'), child: const Text('Hold')),
                          TextButton(onPressed: () => _setStatus(v, 'closed'), child: Text('Close', style: TextStyle(color: AppColors.coral))),
                        ] else if (v.status == 'on_hold')
                          TextButton(onPressed: () => _setStatus(v, 'open'), child: const Text('Reopen')),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class _PipelineDialog extends StatefulWidget {
  const _PipelineDialog({required this.vacancy});
  final Vacancy vacancy;

  @override
  State<_PipelineDialog> createState() => _PipelineDialogState();
}

class _PipelineDialogState extends State<_PipelineDialog> {
  List<Application> _applications = [];
  bool _loading = true;
  bool _changed = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await RecruitmentService.instance.pipeline(widget.vacancy.id);
      if (mounted) setState(() { _applications = list; _loading = false; });
    } catch (e) {
      if (mounted) { setState(() => _loading = false); showErrorToast(context, e); }
    }
  }

  Future<void> _addApplicant() async {
    List<Applicant> applicants = [];
    try { applicants = await RecruitmentService.instance.applicants(); } catch (_) {}
    if (!mounted || applicants.isEmpty) {
      if (mounted) showErrorToast(context, 'No applicants exist yet — add one from the Applicants tab first.');
      return;
    }
    final id = await showDialog<int>(context: context, builder: (dialogCtx) => SimpleDialog(
      backgroundColor: context.pal.surface1,
      title: const Text('Add Applicant to Pipeline'),
      children: applicants.map((a) => SimpleDialogOption(
        onPressed: () => Navigator.of(dialogCtx).pop(a.id),
        child: Text(a.name),
      )).toList(),
    ));
    if (id == null) return;
    try {
      await RecruitmentService.instance.applyToVacancy(widget.vacancy.id, id);
      _changed = true;
      _load();
    } catch (e) { if (mounted) showErrorToast(context, e); }
  }

  Future<void> _advanceStage(Application a) async {
    final next = await showDialog<String>(context: context, builder: (dialogCtx) => SimpleDialog(
      backgroundColor: context.pal.surface1,
      title: const Text('Move to Stage'),
      children: Application.stageLabels.entries.map((e) => SimpleDialogOption(
        onPressed: () => Navigator.of(dialogCtx).pop(e.key),
        child: Text(e.value),
      )).toList(),
    ));
    if (next == null) return;
    try {
      await RecruitmentService.instance.updateStage(a.id, next);
      _changed = true;
      _load();
    } catch (e) { if (mounted) showErrorToast(context, e); }
  }

  Future<void> _scheduleInterview(Application a) async {
    DateTime date = DateTime.now().add(const Duration(days: 3));
    final stageCtrl = TextEditingController();
    final go = await showDialog<bool>(context: context, builder: (dialogCtx) => StatefulBuilder(
      builder: (dialogCtx, setDialogState) => AlertDialog(
        backgroundColor: context.pal.surface1,
        title: Text('Schedule Interview', style: AppTheme.cardTitle),
        content: SizedBox(width: 320, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          LabeledDateField(
            label: 'Date',
            date: date,
            onTap: () async {
              final picked = await showDatePicker(context: dialogCtx, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (picked != null) setDialogState(() => date = picked);
            },
          ),
          const SizedBox(height: 12),
          LabeledTextField(label: 'Stage', controller: stageCtrl, hint: 'e.g. Technical'),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogCtx).pop(true), child: const Text('Schedule')),
        ],
      ),
    ));
    if (go != true) return;
    try {
      await RecruitmentService.instance.scheduleInterview(a.id, {
        'scheduled_at': date.toIso8601String(),
        'stage': stageCtrl.text.trim().isNotEmpty ? stageCtrl.text.trim() : null,
      });
      _changed = true;
      _load();
    } catch (e) { if (mounted) showErrorToast(context, e); }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: context.pal.surface1,
    child: Container(
      width: 520,
      constraints: const BoxConstraints(maxHeight: 560),
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Icon(Symbols.groups, size: 18, color: AppColors.teal),
          const SizedBox(width: 10),
          Expanded(child: Text('Pipeline — ${widget.vacancy.positionTitle ?? ''}', style: AppTheme.bodyStrong)),
          TextButton.icon(onPressed: _addApplicant, icon: const Icon(Symbols.add, size: 16), label: const Text('Add')),
          GestureDetector(onTap: () => Navigator.of(context).pop(_changed), child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
        ]),
        const Divider(height: 24),
        Flexible(child: _loading
            ? const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            : _applications.isEmpty
                ? Padding(padding: const EdgeInsets.symmetric(vertical: 32), child: Center(child: Text('No applicants in this pipeline yet.', style: AppTheme.bodySub)))
                : SingleChildScrollView(child: Column(children: _applications.map((a) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: context.pal.surface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(a.applicantName ?? '—', style: AppTheme.bodyStrong.copyWith(fontSize: 13))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.tealSoft, borderRadius: BorderRadius.circular(4)),
                          child: Text(a.stageLabel, style: AppTheme.monoXs.copyWith(color: AppColors.teal, fontSize: 10)),
                        ),
                      ]),
                      if (a.interviews.isNotEmpty)
                        ...a.interviews.map((iv) => Padding(padding: const EdgeInsets.only(top: 4),
                            child: Text('Interview: ${iv.scheduledAt} · ${iv.stage ?? 'N/A'}${iv.rating != null ? ' · ${iv.rating}/5' : ''}',
                                style: AppTheme.bodySub.copyWith(fontSize: 11)))),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, children: [
                        TextButton(onPressed: () => _advanceStage(a), child: const Text('Move Stage')),
                        TextButton(onPressed: () => _scheduleInterview(a), child: const Text('Schedule Interview')),
                      ]),
                    ]),
                  )).toList())),
        ),
      ]),
    ),
  );
}

// ── Applicants / Talent Pool ────────────────────────────────────────────────

class _ApplicantsTab extends StatefulWidget {
  const _ApplicantsTab();
  @override
  State<_ApplicantsTab> createState() => _ApplicantsTabState();
}

class _ApplicantsTabState extends State<_ApplicantsTab> {
  List<Applicant> _applicants = [];
  bool _loading = true;
  String? _error;
  bool _talentPoolOnly = false;
  String _search = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await RecruitmentService.instance.applicants(
        talentPool: _talentPoolOnly ? true : null,
        search: _search.isNotEmpty ? _search : null,
      );
      if (mounted) setState(() { _applicants = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _newApplicant() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final sourceCtrl = TextEditingController();
    final skillsCtrl = TextEditingController();
    bool talentPool = false;
    final go = await showDialog<bool>(context: context, builder: (dialogCtx) => StatefulBuilder(
      builder: (dialogCtx, setDialogState) => AlertDialog(
        backgroundColor: context.pal.surface1,
        title: Text('New Applicant', style: AppTheme.cardTitle),
        content: SizedBox(width: 380, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          LabeledTextField(label: 'Name', controller: nameCtrl),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: LabeledTextField(label: 'Email', controller: emailCtrl, keyboardType: TextInputType.emailAddress)),
            const SizedBox(width: 10),
            Expanded(child: LabeledTextField(label: 'Phone', controller: phoneCtrl, keyboardType: TextInputType.phone)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: LabeledTextField(label: 'Source', controller: sourceCtrl, hint: 'e.g. LinkedIn')),
            const SizedBox(width: 10),
            Expanded(child: LabeledTextField(label: 'Skills tags', controller: skillsCtrl)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Checkbox(value: talentPool, onChanged: (v) => setDialogState(() => talentPool = v ?? false)),
            const Text('Add to talent pool'),
          ]),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogCtx).pop(true), child: const Text('Create')),
        ],
      ),
    ));
    if (go != true || nameCtrl.text.trim().isEmpty) return;
    try {
      await RecruitmentService.instance.createApplicant({
        'name': nameCtrl.text.trim(),
        'email': emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
        'phone': phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
        'source_channel': sourceCtrl.text.trim().isNotEmpty ? sourceCtrl.text.trim() : null,
        'skills_tags': skillsCtrl.text.trim().isNotEmpty ? skillsCtrl.text.trim() : null,
        'talent_pool': talentPool,
      });
      _load();
    } catch (e) { if (mounted) showErrorToast(context, e); }
  }

  Future<void> _uploadCv(Applicant a) async {
    final result = await FilePicker.pickFiles(allowMultiple: false, withData: false);
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final name = result.files.single.name;
    try {
      await RecruitmentService.instance.uploadCv(a.id, path, name);
      if (mounted) showSuccessToast(context, 'CV uploaded.');
      _load();
    } catch (e) { if (mounted) showErrorToast(context, e); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: TextField(
            onChanged: (v) { _search = v; _load(); },
            decoration: InputDecoration(hintText: 'Search by name or email…', prefixIcon: const Icon(Symbols.search, size: 18), isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
          )),
          const SizedBox(width: 10),
          FilterChip(
            label: const Text('Talent Pool'),
            selected: _talentPoolOnly,
            onSelected: (v) { setState(() => _talentPoolOnly = v); _load(); },
          ),
          const SizedBox(width: 10),
          FilledButton.icon(onPressed: _newApplicant, icon: const Icon(Symbols.add, size: 16), label: const Text('New Applicant')),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: _applicants.isEmpty
              ? Center(child: Text('No applicants found.', style: AppTheme.bodySub))
              : ListView.separated(
                  itemCount: _applicants.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final a = _applicants[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(10), border: Border.all(color: context.pal.border)),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text(a.name, style: AppTheme.bodyStrong.copyWith(fontSize: 13.5)),
                            if (a.talentPool) ...[
                              const SizedBox(width: 8),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(color: AppColors.violetSoft, borderRadius: BorderRadius.circular(4)),
                                  child: Text('Talent Pool', style: AppTheme.monoXs.copyWith(color: AppColors.violet, fontSize: 9.5))),
                            ],
                          ]),
                          Text([a.email, a.phone, a.sourceChannel].where((s) => s != null && s.isNotEmpty).join(' · '),
                              style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
                          if (a.skillsTags != null) Text(a.skillsTags!, style: AppTheme.bodySub.copyWith(fontSize: 11)),
                          if (a.latestCv != null) Text('CV v${a.latestCv!.version}: ${a.latestCv!.originalName}', style: AppTheme.bodySub.copyWith(fontSize: 11)),
                        ])),
                        TextButton(onPressed: () => _uploadCv(a), child: const Text('Upload CV')),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
