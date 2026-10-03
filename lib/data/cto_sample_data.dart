// lib/data/cto_sample_data.dart — mirrors CTO Dashboard.dc.html (turn 2) so the
// screen can be reviewed before /dashboard/cto-overview exists:
//   CtoDashboardScreen(useSampleData: true)
// Calendar anchored on Mon 29 Sep 2026 to match the mock (today = Fri 03 Oct).
import '../models/cto_approval.dart';
import '../models/cto_overview.dart';

class CtoSampleData {
  CtoSampleData._();

  static final _mon = DateTime(2026, 9, 29);
  static DateTime _d(int i) => _mon.add(Duration(days: i));
  static TripBar _bar(int s, int len, TripBarKind k, String label, [int? pd]) =>
      TripBar(perDiemRequestId: pd, label: label, start: _d(s), end: _d(s + len - 1), kind: k);

  static CtoOverview overview() => CtoOverview(
        name: 'Sharif',
        kpis: const CtoKpis(
          fleetUptimePct: 94.1, machinesOperational: 253, machinesTotal: 269, machinesDown: 14,
          machinesDownToday: 3, hospitalsAffected: 9, openTickets: 5, slaBreached: 1, slaAtRisk: 1,
          techniciansTotal: 8, techniciansOut: 3, techniciansOnLeave: 1, lowStockCount: 29, openPurchaseOrders: 0,
        ),
        fleetLegend: const {'operational': 253, 'needs_service': 2, 'down': 14, 'technician_en_route': 3},
        downLongest: const [
          DownMachine(machineId: 1, name: 'MRI scanner', hospital: 'Mount Meru RRH', note: 'Arusha · unassigned', downHours: 72),
          DownMachine(machineId: 2, name: 'CT unit', hospital: 'Temeke RRH', note: 'Dar · waiting HV board', downHours: 48),
          DownMachine(machineId: 3, name: 'Dialysis line', hospital: 'Bukoba RRH', note: 'Kagera · A. Kimaro en route', downHours: 26),
          DownMachine(machineId: 4, name: 'X-ray', hospital: 'Singida RRH', note: 'J. Mkonyi on site', downHours: 14),
        ],
        tickets: const [
          SlaTicket(id: 921, number: 'ST-0921', title: 'MRI offline', hospital: 'Mount Meru RRH', slaTargetHours: 48, hoursLeft: -72),
          SlaTicket(id: 918, number: 'ST-0918', title: 'CT unit down', hospital: 'Temeke RRH', assigneeName: 'D. Ngassa', assigneeNote: 'waiting HV board', slaTargetHours: 48, hoursLeft: 4),
          SlaTicket(id: 915, number: 'ST-0915', title: 'Dialysis line down', hospital: 'Bukoba RRH', assigneeName: 'A. Kimaro', assigneeNote: 'en route', slaTargetHours: 48, hoursLeft: 18),
          SlaTicket(id: 912, number: 'ST-0912', title: 'X-ray no exposure', hospital: 'Singida RRH', assigneeName: 'J. Mkonyi', assigneeNote: 'on site', slaTargetHours: 48, hoursLeft: 30),
          SlaTicket(id: 909, number: 'ST-0909', title: 'Ventilator alarm', hospital: 'Njombe RRH', assigneeName: 'S. Haule', assigneeNote: 'on site', slaTargetHours: 48, hoursLeft: 46),
        ],
        team: [
          TeamMember(userId: 1, name: 'J. Mkonyi', state: 'en_route', where: 'Singida RRH', tripNote: 'Trip PD-0139 · day 2 of 3 · per diem paid',
              bars: [_bar(2, 3, TripBarKind.approved, 'Singida RRH'), _bar(7, 4, TripBarKind.pendingCto, 'PD-0142 · Dodoma, Singida', 142)]),
          TeamMember(userId: 2, name: 'S. Haule', state: 'en_route', where: 'Njombe RRH', tripNote: 'Trip PD-0137 · day 5 of 5 · next trip pending you',
              bars: [_bar(0, 5, TripBarKind.approved, 'Njombe RRH'), _bar(8, 6, TripBarKind.pendingCto, 'PD-0143 · Iringa, Mufindi', 143)]),
          TeamMember(userId: 3, name: 'A. Kimaro', state: 'en_route', where: 'Bukoba RRH', tripNote: 'Trip PD-0140 · day 1 of 3 · expense pending you',
              bars: [_bar(4, 3, TripBarKind.approved, 'Bukoba RRH')]),
          const TeamMember(userId: 4, name: 'D. Ngassa', state: 'base', where: 'Dar workshop', tripNote: 'Team lead · no trip planned'),
          TeamMember(userId: 5, name: 'R. Mwita', state: 'base', where: 'Mwanza workshop', tripNote: 'Trip PD-0144 · Mwanza BMC from 08 Oct',
              bars: [_bar(9, 2, TripBarKind.approved, 'Mwanza BMC')]),
          TeamMember(userId: 6, name: 'E. Massawe', state: 'base', where: 'Mtwara', tripNote: 'Back from Mtwara RRH',
              bars: [_bar(0, 3, TripBarKind.approved, 'Mtwara RRH')]),
          const TeamMember(userId: 7, name: 'N. Temu', state: 'base', where: 'Dar workshop', tripNote: 'No trip planned'),
          TeamMember(userId: 8, name: 'P. Lyimo', state: 'on_leave', where: 'Annual leave', tripNote: 'Back 09 Oct',
              bars: [_bar(0, 10, TripBarKind.leave, 'Annual leave')]),
        ],
        spares: const [
          SpareAlert(itemId: 1, name: 'HV generator board', qty: 1, note: 'Blocks ST-0918 · request pending you', severity: 'warning'),
          SpareAlert(itemId: 2, name: 'Detector cable', qty: 0, note: 'Out · no PO raised', severity: 'critical'),
          SpareAlert(itemId: 3, name: 'Collimator lamp', qty: 2, note: 'Reorder level 4', severity: 'warning'),
          SpareAlert(itemId: 4, name: 'Dialysis pump head', qty: 5, note: 'Reorder level 2', severity: 'ok'),
        ],
        calendarStart: _mon,
        calendarDays: 14,
      );

  static const _tlDone = CtoApprovalStep('Team lead', 'D. Ngassa ✓', CtoStepState.done);
  static const _cto = CtoApprovalStep('CTO · you', 'Pending', CtoStepState.current);
  static const _fin = CtoApprovalStep('Finance', 'pays', CtoStepState.upcoming);

  // Source objects (perDiem/expense/stock) are null — the service no-ops,
  // and the screen skips API calls when useSampleData is on.
  static List<CtoApproval> approvals() => const [
        CtoApproval(
          kind: CtoApprovalKind.trip, key: 'trip-142', ref: 'PD-0142', requester: 'J. Mkonyi',
          title: 'Dodoma & Singida PM round', meta: '06–09 Oct · 4 days', amount: 480000,
          lines: [
            CtoApprovalLine('06 Oct', 'Dar → Dodoma · travel day', '120,000'),
            CtoApprovalLine('07 Oct', 'Dodoma RRH · PM on 3 X-ray units', '120,000'),
            CtoApprovalLine('08 Oct', 'Singida RRH · follow-up ST-0912', '120,000'),
            CtoApprovalLine('09 Oct', 'Singida → Dar · travel day', '120,000'),
          ],
          steps: [CtoApprovalStep('Requester', 'J. Mkonyi ✓', CtoStepState.done), _tlDone, _cto, _fin],
        ),
        CtoApproval(
          kind: CtoApprovalKind.trip, key: 'trip-143', ref: 'PD-0143', requester: 'S. Haule',
          title: 'Iringa & Mufindi PM round', meta: '07–12 Oct · 6 days', amount: 720000,
          flag: 'Technician proposed edit · +1 day at Mufindi',
          lines: [
            CtoApprovalLine('07 Oct', 'Njombe → Iringa · travel day', '120,000'),
            CtoApprovalLine('08 Oct', 'Iringa RRH · ventilators ×4', '120,000'),
            CtoApprovalLine('09 Oct', 'Iringa RRH · anaesthesia units', '120,000'),
            CtoApprovalLine('10 Oct', 'Mufindi DH · X-ray', '120,000'),
            CtoApprovalLine('11 Oct', 'Mufindi DH · added day', '120,000'),
            CtoApprovalLine('12 Oct', 'Iringa → Dar · travel day', '120,000'),
          ],
          steps: [CtoApprovalStep('Requester', 'S. Haule ✓', CtoStepState.done), _tlDone, _cto, _fin],
        ),
        CtoApproval(
          kind: CtoApprovalKind.expense, key: 'expense-311', ref: 'EX-0311', requester: 'A. Kimaro',
          title: 'Fuel & ferry · Bukoba callout', meta: '3 receipts · ST-0915', amount: 186500,
          lines: [
            CtoApprovalLine('R-1', 'Fuel · Puma Bukoba', '124,000'),
            CtoApprovalLine('R-2', 'Ferry · Mwanza → Bukoba', '48,500'),
            CtoApprovalLine('R-3', 'Parking · Bukoba RRH', '14,000'),
          ],
          steps: [CtoApprovalStep('Requester', 'A. Kimaro ✓', CtoStepState.done), _cto, _fin],
        ),
        CtoApproval(
          kind: CtoApprovalKind.expense, key: 'expense-312', ref: 'EX-0312', requester: 'R. Mwita',
          title: 'Courier · detector board', meta: '1 receipt · ST-0918', amount: 42000,
          lines: [CtoApprovalLine('R-1', 'DHL · Dar → Mwanza, next day', '42,000')],
          steps: [CtoApprovalStep('Requester', 'R. Mwita ✓', CtoStepState.done), _cto, _fin],
        ),
        CtoApproval(
          kind: CtoApprovalKind.stock, key: 'stock-88', ref: 'SR-0088', requester: 'D. Ngassa',
          title: 'HV generator board ×1', meta: 'For ST-0918 · CT Temeke', qtyLabel: '×1',
          lines: [
            CtoApprovalLine('Stock', 'In stock now', '1'),
            CtoApprovalLine('After', 'Left after issue · reorder level 2', '0'),
            CtoApprovalLine('Ticket', 'ST-0918 · CT unit down, Temeke RRH', '4 h left'),
          ],
          steps: [CtoApprovalStep('Requester', 'D. Ngassa ✓', CtoStepState.done), _cto, CtoApprovalStep('Stores', 'issues part', CtoStepState.upcoming)],
        ),
        CtoApproval(
          kind: CtoApprovalKind.stock, key: 'stock-89', ref: 'SR-0089', requester: 'A. Kimaro',
          title: 'Dialysis pump head ×2', meta: 'For ST-0915 · Bukoba', qtyLabel: '×2',
          lines: [
            CtoApprovalLine('Stock', 'In stock now', '5'),
            CtoApprovalLine('After', 'Left after issue · reorder level 2', '3'),
            CtoApprovalLine('Ticket', 'ST-0915 · dialysis line down, Bukoba RRH', '18 h left'),
          ],
          steps: [CtoApprovalStep('Requester', 'A. Kimaro ✓', CtoStepState.done), _cto, CtoApprovalStep('Stores', 'issues part', CtoStepState.upcoming)],
        ),
      ];
}
