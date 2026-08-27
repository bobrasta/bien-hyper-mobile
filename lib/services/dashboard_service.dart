import 'api_client.dart';

class DashboardData {
  final int    totalMachines;
  final int    operational;
  final int    needsService;
  final int    down;
  final int    warranty;
  final int    totalHospitals;
  final int    openTickets;
  final int    overdueTickets;
  final double revenueThisMonth;
  final double revenueLastMonth;
  final List<String> revenueMonths;
  final List<double> revenueActual;
  final List<double> revenueTarget;
  final List<Map<String, dynamic>> recentTickets;
  final List<Map<String, dynamic>> topHospitals;

  const DashboardData({
    required this.totalMachines,
    required this.operational,
    required this.needsService,
    required this.down,
    required this.warranty,
    required this.totalHospitals,
    required this.openTickets,
    required this.overdueTickets,
    required this.revenueThisMonth,
    required this.revenueLastMonth,
    required this.revenueMonths,
    required this.revenueActual,
    required this.revenueTarget,
    required this.recentTickets,
    required this.topHospitals,
  });

  factory DashboardData.fromJson(
    Map<String, dynamic> j, [
    Map<String, dynamic>? rev,
  ]) {
    final kpi = (j['kpi'] as Map?)?.cast<String, dynamic>() ?? const {};
    return DashboardData(
        totalMachines:    (kpi['total_machines']     as num? ?? 0).toInt(),
        operational:      (kpi['operational']        as num? ?? 0).toInt(),
        needsService:     (kpi['needs_service']      as num? ?? 0).toInt(),
        down:             (kpi['down']               as num? ?? 0).toInt(),
        warranty:         (kpi['warranty']           as num? ?? 0).toInt(),
        totalHospitals:   (kpi['total_hospitals']    as num? ?? 0).toInt(),
        openTickets:      (kpi['open_tickets']       as num? ?? 0).toInt(),
        overdueTickets:   (kpi['overdue_tickets']    as num? ?? 0).toInt(),
        revenueThisMonth: (kpi['revenue_this_month'] as num? ?? 0).toDouble(),
        revenueLastMonth: (kpi['revenue_last_month'] as num? ?? 0).toDouble(),
        revenueMonths: rev != null
            ? (rev['months'] as List? ?? []).cast<String>()
            : const ['Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May','Jun'],
        revenueActual: rev != null
            ? (rev['actual'] as List? ?? []).map((e) => (e as num).toDouble()).toList()
            : const [],
        revenueTarget: rev != null
            ? (rev['target'] as List? ?? []).map((e) => (e as num).toDouble()).toList()
            : const [],
        recentTickets: (j['recent_tickets'] as List? ?? []).cast<Map<String, dynamic>>(),
        topHospitals:  (j['top_hospitals']  as List? ?? []).cast<Map<String, dynamic>>(),
      );
  }

  double get uptimePct => totalMachines == 0
      ? 0 : operational / totalMachines;

  double get revenueGrowth => revenueLastMonth == 0
      ? 0 : (revenueThisMonth - revenueLastMonth) / revenueLastMonth * 100;

  Map<String, int> get statusBreakdown => {
    'Operational':   operational,
    'Needs Service': needsService,
    'Down':          down,
    'Warranty':      warranty,
  };
}

class DashboardService {
  DashboardService._();
  static final instance = DashboardService._();
  final _dio = ApiClient.instance.dio;

  Future<DashboardData> load() async {
    // Both requests start immediately — revenue fires before dashboard is awaited.
    final dashFuture = _dio.get('/dashboard');
    final revFuture  = _dio.get('/revenue/summary');

    final dash = ApiClient.unwrap(await dashFuture) as Map<String, dynamic>;

    Map<String, dynamic>? rev;
    try {
      final raw = ApiClient.unwrap(await revFuture);
      if (raw is Map) rev = Map<String, dynamic>.from(raw);
    } catch (_) {}

    return DashboardData.fromJson(dash, rev);
  }
}
