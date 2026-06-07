import '../models/contact.dart';
import '../models/hospital.dart';
import '../models/invoice.dart';
import '../models/machine.dart';
import '../models/notification.dart';
import '../models/sales_lead.dart';
import '../models/service_ticket.dart';
import '../models/spare_part.dart';

class SampleData {
  SampleData._();

  // ── Machines ──────────────────────────────────────────────────────────────
  static const List<Machine> machines = [
    Machine(id: 1,  serialNo: 'BC68-2421',  model: 'Mindray BC-6800 Plus',    type: 'Hematology Analyzer', hospital: 'Muhimbili National Hospital',   ward: 'Lab · Ward 4B',  installDate: '14 Mar 2023', warrantyExpiry: '14 Mar 2026', status: MachineStatus.operational,  revenuePerMonth: 4200000),
    Machine(id: 2,  serialNo: 'ACX3-1098',  model: 'Siemens Acuson NX3',      type: 'Ultrasound Unit',     hospital: 'Aga Khan Hospital',             ward: 'Radiology',      installDate: '02 Jul 2023', warrantyExpiry: '02 Jul 2025', status: MachineStatus.needsService, revenuePerMonth: 3850000),
    Machine(id: 3,  serialNo: 'EVV3-7720',  model: 'Dräger Evita V300',       type: 'Ventilator',          hospital: 'Jakaya Kikwete Cardiac Inst.', ward: 'ICU',            installDate: '21 Nov 2022', warrantyExpiry: '21 Nov 2024', status: MachineStatus.down,         revenuePerMonth: 2100000),
    Machine(id: 4,  serialNo: 'MAC20-558',  model: 'GE MAC 2000',             type: 'ECG Machine',         hospital: 'CCBRT Disability Hospital',    ward: 'Cardiology',     installDate: '08 Feb 2024', warrantyExpiry: '08 Feb 2027', status: MachineStatus.operational,  revenuePerMonth: 1450000),
    Machine(id: 5,  serialNo: 'TUT38-301',  model: 'Tuttnauer 3870EA',        type: 'Autoclave',           hospital: 'Kilimanjaro Christian MC',     ward: 'Sterile Supply', installDate: '15 May 2022', warrantyExpiry: '15 May 2024', status: MachineStatus.warranty,     revenuePerMonth: 980000),
    Machine(id: 6,  serialNo: 'PRM80-441',  model: 'Philips Affiniti 50',     type: 'Ultrasound Unit',     hospital: 'Bugando Medical Centre',       ward: 'OB/GYN',         installDate: '30 Sep 2023', warrantyExpiry: '30 Sep 2026', status: MachineStatus.operational,  revenuePerMonth: 3650000),
    Machine(id: 7,  serialNo: 'IT45-2210',  model: 'Mindray iTM-A',           type: 'Patient Monitor',     hospital: 'Mbeya Zonal Referral Hosp.',  ward: 'Emergency',      installDate: '12 Jan 2024', warrantyExpiry: '12 Jan 2027', status: MachineStatus.operational,  revenuePerMonth: 1820000),
    Machine(id: 8,  serialNo: 'BC68-2422',  model: 'Mindray BC-6800 Plus',    type: 'Hematology Analyzer', hospital: 'Hubert Kairuki Memorial Hosp.',ward: 'Pathology',      installDate: '07 Apr 2023', warrantyExpiry: '07 Apr 2026', status: MachineStatus.operational,  revenuePerMonth: 3920000),
    Machine(id: 9,  serialNo: 'EVV3-7721',  model: 'Dräger Evita V300',       type: 'Ventilator',          hospital: 'Aga Khan Hospital',            ward: 'ICU',            installDate: '19 Aug 2023', warrantyExpiry: '19 Aug 2025', status: MachineStatus.needsService, revenuePerMonth: 2680000),
    Machine(id: 10, serialNo: 'NEX-991',    model: 'Nihon Kohden Cardiolife', type: 'Defibrillator',       hospital: 'Muhimbili National Hospital',  ward: 'Emergency',      installDate: '04 Jun 2024', warrantyExpiry: '04 Jun 2027', status: MachineStatus.operational,  revenuePerMonth: 1240000),
    Machine(id: 11, serialNo: 'OXY-22A',    model: 'Hamilton-C6',             type: 'Ventilator',          hospital: 'TMJ Hospital',                 ward: 'ICU · Ward 2',   installDate: '23 Oct 2023', warrantyExpiry: '23 Oct 2025', status: MachineStatus.operational,  revenuePerMonth: 2540000),
    Machine(id: 12, serialNo: 'MAC20-559',  model: 'GE MAC 2000',             type: 'ECG Machine',         hospital: 'Aga Khan Hospital',            ward: 'Outpatient',     installDate: '11 Dec 2023', warrantyExpiry: '11 Dec 2026', status: MachineStatus.operational,  revenuePerMonth: 1390000),
  ];

  // ── Service Tickets ───────────────────────────────────────────────────────
  static const List<ServiceTicket> tickets = [
    ServiceTicket(dbId: 1, id: '#1042', machineName: 'Mindray BC-6800 Plus',   machineType: 'Hematology Analyzer', hospital: 'Muhimbili National Hospital',   ward: 'Ward 4B',       technicianInitials: 'AK', technicianName: 'Asha Komba',      status: TicketStatus.inProgress, createdAt: '2h ago'),
    ServiceTicket(dbId: 2, id: '#1041', machineName: 'Siemens Acuson NX3',     machineType: 'Ultrasound Unit',     hospital: 'Aga Khan Hospital',             ward: 'Radiology',     technicianInitials: 'EM', technicianName: 'Elias Mtui',       status: TicketStatus.open,       createdAt: '5h ago'),
    ServiceTicket(dbId: 3, id: '#1040', machineName: 'Dräger Evita V300',      machineType: 'Ventilator',          hospital: 'Jakaya Kikwete Cardiac Inst.', ward: 'ICU',           technicianInitials: 'NK', technicianName: 'Neema Kileo',      status: TicketStatus.open,       createdAt: '6h ago'),
    ServiceTicket(dbId: 4, id: '#1039', machineName: 'GE MAC 2000',            machineType: 'ECG Machine',         hospital: 'CCBRT Disability Hospital',    ward: 'Cardiology',    technicianInitials: 'AK', technicianName: 'Asha Komba',      status: TicketStatus.resolved,   createdAt: 'Yesterday'),
    ServiceTicket(dbId: 5, id: '#1038', machineName: 'Tuttnauer 3870EA',       machineType: 'Autoclave',           hospital: 'Kilimanjaro Christian MC',     ward: 'Sterile Supply',technicianInitials: 'PR', technicianName: 'Peter Rwakatare', status: TicketStatus.inProgress, createdAt: 'Yesterday'),
    ServiceTicket(dbId: 6, id: '#1037', machineName: 'Philips Affiniti 50',    machineType: 'Ultrasound Unit',     hospital: 'Bugando Medical Centre',       ward: 'OB/GYN',        technicianInitials: 'EM', technicianName: 'Elias Mtui',       status: TicketStatus.resolved,   createdAt: '3 days ago'),
    ServiceTicket(dbId: 7, id: '#1036', machineName: 'Mindray BC-6800 Plus',   machineType: 'Hematology Analyzer', hospital: 'Hubert Kairuki Memorial Hosp.',ward: 'Pathology',     technicianInitials: 'NK', technicianName: 'Neema Kileo',      status: TicketStatus.overdue,    createdAt: '8 days ago'),
    ServiceTicket(dbId: 8, id: '#1035', machineName: 'Hamilton-C6',            machineType: 'Ventilator',          hospital: 'TMJ Hospital',                 ward: 'ICU Ward 2',    technicianInitials: 'AK', technicianName: 'Asha Komba',      status: TicketStatus.resolved,   createdAt: '10 days ago'),
  ];

  // ── Revenue data (12 months) ──────────────────────────────────────────────
  static const List<String> revenueMonths = ['Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May','Jun'];
  static const List<double> revenueActual = [185,192,208,215,224,238,245,258,268,285,298,312];
  static const List<double> revenueTarget = [180,190,200,210,220,230,240,250,260,270,280,290];

  // ── Hospital ranking ──────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> hospitalRanking = [
    {'name': 'Muhimbili National Hospital',   'city': 'Dar es Salaam', 'count': 87, 'pct': 1.00, 'rev': 42.8},
    {'name': 'Aga Khan Hospital',             'city': 'Dar es Salaam', 'count': 64, 'pct': 0.73, 'rev': 31.2},
    {'name': 'Kilimanjaro Christian MC',      'city': 'Moshi',         'count': 52, 'pct': 0.60, 'rev': 24.6},
    {'name': 'Jakaya Kikwete Cardiac Inst.',  'city': 'Dar es Salaam', 'count': 41, 'pct': 0.47, 'rev': 19.8},
    {'name': 'CCBRT Disability Hospital',     'city': 'Dar es Salaam', 'count': 38, 'pct': 0.44, 'rev': 17.2},
    {'name': 'Bugando Medical Centre',        'city': 'Mwanza',        'count': 34, 'pct': 0.39, 'rev': 14.5},
    {'name': 'Mbeya Zonal Referral Hosp.',    'city': 'Mbeya',         'count': 28, 'pct': 0.32, 'rev': 11.8},
  ];

  // ── Sales Pipeline ────────────────────────────────────────────────────────
  static const List<SalesLead> salesLeads = [
    SalesLead(id: 1,  hospital: 'Mwananyamala Regional Hosp.', contact: 'Dr. James Mbeki',  machineType: 'Hematology Analyzer', dealValue: 185000000, daysInStage: 3,  stage: PipelineStage.lead),
    SalesLead(id: 2,  hospital: 'Benjamin Mkapa Hospital',     contact: 'Ms. Grace Nkomo',  machineType: 'Ultrasound Unit',     dealValue: 120000000, daysInStage: 7,  stage: PipelineStage.lead),
    SalesLead(id: 3,  hospital: 'Arusha Lutheran Med. Ctr.',   contact: 'Mr. David Osei',   machineType: 'Patient Monitor',     dealValue: 95000000,  daysInStage: 2,  stage: PipelineStage.qualified),
    SalesLead(id: 4,  hospital: 'Dodoma Regional Hospital',    contact: 'Dr. Sarah Kiiza',  machineType: 'Ventilator',          dealValue: 275000000, daysInStage: 5,  stage: PipelineStage.qualified),
    SalesLead(id: 5,  hospital: 'Iringa Regional Hospital',    contact: 'Mr. Peter Banda',  machineType: 'ECG Machine',         dealValue: 68000000,  daysInStage: 12, stage: PipelineStage.demoScheduled, demoDate: 'Jun 28'),
    SalesLead(id: 6,  hospital: 'Mbeya Zonal Referral',        contact: 'Dr. Amina Hassan', machineType: 'Autoclave',           dealValue: 142000000, daysInStage: 8,  stage: PipelineStage.proposalSent),
    SalesLead(id: 7,  hospital: 'Muhimbili Orthopaedic',       contact: 'Dr. Rashid Ally',  machineType: 'Ultrasound Unit',     dealValue: 310000000, daysInStage: 18, stage: PipelineStage.negotiation),
    SalesLead(id: 8,  hospital: 'Aga Khan Mombasa',            contact: 'Mr. Ali Farouk',   machineType: 'Hematology Analyzer', dealValue: 220000000, daysInStage: 4,  stage: PipelineStage.won),
    SalesLead(id: 9,  hospital: 'Kilimanjaro Christian MC',    contact: 'Dr. Martha Lyimo', machineType: 'Ventilator',          dealValue: 385000000, daysInStage: 22, stage: PipelineStage.won),
    SalesLead(id: 10, hospital: 'Temeke District Hospital',    contact: 'Dr. Julius Swai',  machineType: 'Defibrillator',       dealValue: 58000000,  daysInStage: 30, stage: PipelineStage.lost),
  ];

  // ── Tanzania map pins ─────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> mapPins = [
    {'city': 'Dar es Salaam', 'x': 0.75, 'y': 0.64, 'count': 142, 'status': 'teal',  'lg': true},
    {'city': 'Dodoma',        'x': 0.53, 'y': 0.56, 'count': 38,  'status': 'teal'},
    {'city': 'Arusha',        'x': 0.60, 'y': 0.24, 'count': 86,  'status': 'teal'},
    {'city': 'Mwanza',        'x': 0.32, 'y': 0.22, 'count': 64,  'status': 'teal'},
    {'city': 'Mbeya',         'x': 0.28, 'y': 0.76, 'count': 41,  'status': 'amber'},
    {'city': 'Tanga',         'x': 0.72, 'y': 0.42, 'count': 29,  'status': 'teal'},
    {'city': 'Iringa',        'x': 0.44, 'y': 0.68, 'count': 34,  'status': 'amber'},
    {'city': 'Morogoro',      'x': 0.64, 'y': 0.60, 'count': 47,  'status': 'teal'},
    {'city': 'Mtwara',        'x': 0.76, 'y': 0.88, 'count': 18,  'status': 'down'},
    {'city': 'Kigoma',        'x': 0.12, 'y': 0.44, 'count': 22,  'status': 'teal'},
    {'city': 'Songea',        'x': 0.42, 'y': 0.86, 'count': 14,  'status': 'teal'},
  ];

  // ── Machine status breakdown ──────────────────────────────────────────────
  static const Map<String, int> statusBreakdown = {
    'Operational':    782,
    'Needs Service':  38,
    'Down':           18,
    'Warranty Claim': 9,
  };

  // ── KPI sparklines ────────────────────────────────────────────────────────
  static const List<double> sparkMachines = [12,18,16,22,20,28,32,30,38,42,40,46];
  static const List<double> sparkUptime   = [85,88,84,90,89,92,91,94,93,92,92,92.3];
  static const List<double> sparkService  = [8,12,18,22,20,28,32,30,27,25,23,23];
  static const List<double> sparkRevenue  = [180,200,220,240,255,275,290,300,310,308,312,312];

  // ── Hospitals ─────────────────────────────────────────────────────────────
  static const List<Hospital> hospitals = [
    Hospital(id: 1,  name: 'Muhimbili National Hospital',         shortCode: 'MNH',   type: 'public',  region: 'Dar es Salaam', district: 'Ilala',       latitude: -6.8042, longitude: 39.2694, machineCount: 87, machinesOperational: 81, revenueMonthly: 42.8, contactName: 'Dr. Amina Hassan',   contactPhone: '+255 22 215 0610', contactEmail: 'procurement@mnh.go.tz'),
    Hospital(id: 2,  name: 'Aga Khan Hospital',                   shortCode: 'AKH',   type: 'private', region: 'Dar es Salaam', district: 'Upanga',      latitude: -6.7924, longitude: 39.2728, machineCount: 64, machinesOperational: 62, revenueMonthly: 31.2, contactName: 'Mr. Khalid Rashid',  contactPhone: '+255 22 211 5151', contactEmail: 'biomedical@akhtz.org'),
    Hospital(id: 3,  name: 'Kilimanjaro Christian Medical Centre', shortCode: 'KCMC',  type: 'mission', region: 'Kilimanjaro',   district: 'Moshi Urban', latitude: -3.3530, longitude: 37.3428, machineCount: 52, machinesOperational: 48, revenueMonthly: 24.6, contactName: 'Dr. Martha Lyimo',   contactPhone: '+255 27 275 4377', contactEmail: 'equipment@kcmc.ac.tz'),
    Hospital(id: 4,  name: 'Jakaya Kikwete Cardiac Institute',    shortCode: 'JKCI',  type: 'public',  region: 'Dar es Salaam', district: 'Kinondoni',   latitude: -6.7689, longitude: 39.2503, machineCount: 41, machinesOperational: 36, revenueMonthly: 19.8, contactName: 'Eng. Simon Mwangi',  contactPhone: '+255 22 260 1543', contactEmail: 'biomed@jkci.go.tz'),
    Hospital(id: 5,  name: 'CCBRT Disability Hospital',           shortCode: 'CCBRT', type: 'mission', region: 'Dar es Salaam', district: 'Kinondoni',   latitude: -6.7725, longitude: 39.2381, machineCount: 38, machinesOperational: 36, revenueMonthly: 17.2, contactName: 'Ms. Lucy Ndunguru',  contactPhone: '+255 22 261 1090', contactEmail: 'supplies@ccbrt.or.tz'),
    Hospital(id: 6,  name: 'Bugando Medical Centre',              shortCode: 'BMC',   type: 'public',  region: 'Mwanza',        district: 'Ilemela',     latitude: -2.5060, longitude: 32.8936, machineCount: 34, machinesOperational: 32, revenueMonthly: 14.5, contactName: 'Dr. Francis Msigwa', contactPhone: '+255 28 250 0610', contactEmail: 'procurement@bugando.ac.tz'),
    Hospital(id: 7,  name: 'Mbeya Zonal Referral Hospital',       shortCode: 'MZRH',  type: 'public',  region: 'Mbeya',         district: 'Mbeya City',  latitude: -8.9143, longitude: 33.4607, machineCount: 28, machinesOperational: 24, revenueMonthly: 11.8, contactName: 'Eng. Peter Temba',   contactPhone: '+255 25 250 2491', contactEmail: 'biomed@mbeyareferral.go.tz'),
    Hospital(id: 8,  name: 'Hubert Kairuki Memorial Hospital',    shortCode: 'HKMH',  type: 'private', region: 'Dar es Salaam', district: 'Mikocheni',   latitude: -6.7536, longitude: 39.2568, machineCount: 26, machinesOperational: 26, revenueMonthly: 10.4, contactName: 'Mr. Davis Kinabo',   contactPhone: '+255 22 277 5678', contactEmail: 'engineering@kairuki.ac.tz'),
    Hospital(id: 9,  name: 'Arusha Lutheran Medical Centre',      shortCode: 'ALMC',  type: 'mission', region: 'Arusha',         district: 'Arusha City', latitude: -3.3667, longitude: 36.6833, machineCount: 24, machinesOperational: 22, revenueMonthly: 9.6,  contactName: 'Dr. David Osei',     contactPhone: '+255 27 250 8430', contactEmail: 'biomedical@almc.or.tz'),
    Hospital(id: 10, name: 'TMJ Hospital',                        shortCode: 'TMJ',   type: 'private', region: 'Dar es Salaam', district: 'Msasani',     latitude: -6.7681, longitude: 39.2784, machineCount: 22, machinesOperational: 21, revenueMonthly: 8.8,  contactName: 'Ms. Grace Mwangi',   contactPhone: '+255 22 260 2820', contactEmail: 'procurement@tmj.co.tz'),
    Hospital(id: 11, name: 'Benjamin Mkapa Hospital',             shortCode: 'BMH',   type: 'public',  region: 'Dodoma',         district: 'Dodoma City', latitude: -6.1811, longitude: 35.7395, machineCount: 18, machinesOperational: 15, revenueMonthly: 7.2,  contactName: 'Eng. Ali Materu',    contactPhone: '+255 26 232 4114', contactEmail: 'biomed@bmh.go.tz'),
    Hospital(id: 12, name: 'Mwananyamala Regional Hospital',      shortCode: 'MRH',   type: 'public',  region: 'Dar es Salaam', district: 'Kinondoni',   latitude: -6.7922, longitude: 39.2276, machineCount: 16, machinesOperational: 14, revenueMonthly: 6.4,  contactName: 'Dr. James Mbeki',    contactPhone: '+255 22 246 0030', contactEmail: 'procurement@mrh.go.tz'),
  ];

  // ── Invoices ──────────────────────────────────────────────────────────────
  static final List<Invoice> invoices = [
    Invoice(id: 1,  invoiceNumber: 'INV-2025-0142', hospitalName: 'Muhimbili National Hospital',    issueDate: '01 Jun 2025', dueDate: '30 Jun 2025', subtotal: 3559322, taxRate: 18, taxAmount: 640678, total: 4200000, amountPaid: 4200000, status: PaymentStatus.paid,    lineItems: [InvoiceLineItem(description: 'Monthly service contract — Hematology Analyzer', quantity: 1, unitPrice: 3559322, total: 3559322)]),
    Invoice(id: 2,  invoiceNumber: 'INV-2025-0141', hospitalName: 'Aga Khan Hospital',              issueDate: '01 Jun 2025', dueDate: '30 Jun 2025', subtotal: 3262712, taxRate: 18, taxAmount: 587288, total: 3850000, amountPaid: 1925000, status: PaymentStatus.partial, lineItems: [InvoiceLineItem(description: 'Monthly service contract — Ultrasound Unit', quantity: 1, unitPrice: 3262712, total: 3262712)]),
    Invoice(id: 3,  invoiceNumber: 'INV-2025-0140', hospitalName: 'Jakaya Kikwete Cardiac Inst.',   issueDate: '01 Jun 2025', dueDate: '30 Jun 2025', subtotal: 1779661, taxRate: 18, taxAmount: 320339, total: 2100000, amountPaid: 0,       status: PaymentStatus.overdue, lineItems: [InvoiceLineItem(description: 'Monthly service contract — Ventilator', quantity: 1, unitPrice: 1779661, total: 1779661)]),
    Invoice(id: 4,  invoiceNumber: 'INV-2025-0139', hospitalName: 'CCBRT Disability Hospital',      issueDate: '01 Jun 2025', dueDate: '30 Jun 2025', subtotal: 1228814, taxRate: 18, taxAmount: 221186, total: 1450000, amountPaid: 1450000, status: PaymentStatus.paid,    lineItems: [InvoiceLineItem(description: 'Monthly service contract — ECG Machine', quantity: 1, unitPrice: 1228814, total: 1228814)]),
    Invoice(id: 5,  invoiceNumber: 'INV-2025-0138', hospitalName: 'Kilimanjaro Christian MC',       issueDate: '01 Jun 2025', dueDate: '30 Jun 2025', subtotal: 830508,  taxRate: 18, taxAmount: 149492, total: 980000,  amountPaid: 0,       status: PaymentStatus.pending, lineItems: [InvoiceLineItem(description: 'Monthly service contract — Autoclave', quantity: 1, unitPrice: 830508, total: 830508)]),
    Invoice(id: 6,  invoiceNumber: 'INV-2025-0137', hospitalName: 'Bugando Medical Centre',         issueDate: '01 Jun 2025', dueDate: '30 Jun 2025', subtotal: 3093220, taxRate: 18, taxAmount: 556780, total: 3650000, amountPaid: 3650000, status: PaymentStatus.paid,    lineItems: [InvoiceLineItem(description: 'Monthly service contract — Ultrasound Unit', quantity: 1, unitPrice: 3093220, total: 3093220)]),
    Invoice(id: 7,  invoiceNumber: 'INV-2025-0136', hospitalName: 'Mbeya Zonal Referral Hosp.',    issueDate: '01 Jun 2025', dueDate: '30 Jun 2025', subtotal: 1542373, taxRate: 18, taxAmount: 277627, total: 1820000, amountPaid: 1820000, status: PaymentStatus.paid,    lineItems: [InvoiceLineItem(description: 'Monthly service contract — Patient Monitor', quantity: 1, unitPrice: 1542373, total: 1542373)]),
    Invoice(id: 8,  invoiceNumber: 'INV-2025-0135', hospitalName: 'Hubert Kairuki Memorial Hosp.', issueDate: '01 Jun 2025', dueDate: '30 Jun 2025', subtotal: 3322034, taxRate: 18, taxAmount: 597966, total: 3920000, amountPaid: 0,       status: PaymentStatus.pending, lineItems: [InvoiceLineItem(description: 'Monthly service contract — Hematology Analyzer', quantity: 1, unitPrice: 3322034, total: 3322034)]),
    Invoice(id: 9,  invoiceNumber: 'INV-2025-0134', hospitalName: 'Aga Khan Hospital',              issueDate: '01 Jun 2025', dueDate: '30 Jun 2025', subtotal: 2271186, taxRate: 18, taxAmount: 408814, total: 2680000, amountPaid: 2680000, status: PaymentStatus.paid,    lineItems: [InvoiceLineItem(description: 'Monthly service contract — Ventilator', quantity: 1, unitPrice: 2271186, total: 2271186)]),
    Invoice(id: 10, invoiceNumber: 'INV-2025-0133', hospitalName: 'Muhimbili National Hospital',    issueDate: '01 Jun 2025', dueDate: '30 Jun 2025', subtotal: 1050847, taxRate: 18, taxAmount: 189153, total: 1240000, amountPaid: 0,       status: PaymentStatus.overdue, lineItems: [InvoiceLineItem(description: 'Monthly service contract — Defibrillator', quantity: 1, unitPrice: 1050847, total: 1050847)]),
  ];

  // ── Contacts / CRM ────────────────────────────────────────────────────────
  static const List<Contact> contacts = [
    Contact(id: 1, firstName: 'Amina',   lastName: 'Hassan',   jobTitle: 'Head of Procurement',       department: 'Administration', email: 'a.hassan@mnh.go.tz',         phone: '+255 754 123 001', hospitalName: 'Muhimbili National Hospital',   lastContactedAt: '2 days ago', nextFollowupAt: 'Jul 2', tags: ['key-account', 'decision-maker'],
      interactions: [
        ContactInteraction(type: 'email', summary: 'Sent Q3 service contract renewal terms',    outcome: 'Awaiting sign-off',       nextAction: 'Follow up on signature', nextActionDate: 'Jul 2', createdAt: '2 days ago'),
        ContactInteraction(type: 'call',  summary: 'Discussed Ventilator maintenance schedule', outcome: 'Agreed on monthly visit', createdAt: '2 weeks ago'),
      ]),
    Contact(id: 2, firstName: 'Khalid',  lastName: 'Rashid',   jobTitle: 'Biomedical Engineer',       department: 'Engineering',    email: 'k.rashid@akhtz.org',         phone: '+255 754 123 002', hospitalName: 'Aga Khan Hospital',             lastContactedAt: '5 days ago', nextFollowupAt: 'Jun 30', tags: ['technical', 'gatekeeper'],
      interactions: [
        ContactInteraction(type: 'meeting', summary: 'On-site calibration review for Ultrasound NX3', outcome: 'Calibration passed', createdAt: '5 days ago'),
      ]),
    Contact(id: 3, firstName: 'Martha',  lastName: 'Lyimo',    jobTitle: 'Medical Equipment Officer', department: 'Technical',      email: 'm.lyimo@kcmc.ac.tz',         phone: '+255 754 123 003', hospitalName: 'Kilimanjaro Christian MC',      lastContactedAt: 'Last week', nextFollowupAt: 'Jul 5', tags: ['technical'], interactions: []),
    Contact(id: 4, firstName: 'James',   lastName: 'Mbeki',    jobTitle: 'Director of Medicine',      department: 'Administration', email: 'j.mbeki@mwananyamala.go.tz', phone: '+255 754 123 004', hospitalName: 'Mwananyamala Regional Hosp.',  lastContactedAt: '3 days ago', nextFollowupAt: 'Jun 28', tags: ['lead', 'decision-maker'],
      interactions: [
        ContactInteraction(type: 'call', summary: 'Initial call about Hematology Analyzer interest', outcome: 'Very interested, requested quote', nextAction: 'Send formal proposal', nextActionDate: 'Jun 28', createdAt: '3 days ago'),
      ]),
    Contact(id: 5, firstName: 'Grace',   lastName: 'Nkomo',    jobTitle: 'Procurement Officer',       department: 'Finance',        email: 'g.nkomo@bmh.go.tz',          phone: '+255 754 123 005', hospitalName: 'Benjamin Mkapa Hospital',       lastContactedAt: 'Yesterday', nextFollowupAt: 'Jul 1', tags: ['lead'],
      interactions: [
        ContactInteraction(type: 'email', summary: 'Sent ultrasound unit brochure and pricing', outcome: 'Acknowledged receipt', createdAt: 'Yesterday'),
      ]),
    Contact(id: 6, firstName: 'Simon',   lastName: 'Mwangi',   jobTitle: 'Chief Biomedical Eng.',     department: 'Engineering',    email: 's.mwangi@jkci.go.tz',        phone: '+255 754 123 006', hospitalName: 'Jakaya Kikwete Cardiac Inst.', lastContactedAt: '1 week ago', tags: ['technical', 'key-account'], interactions: []),
    Contact(id: 7, firstName: 'Francis', lastName: 'Msigwa',   jobTitle: 'Procurement Manager',       department: 'Administration', email: 'f.msigwa@bugando.ac.tz',      phone: '+255 754 123 007', hospitalName: 'Bugando Medical Centre',        lastContactedAt: '4 days ago', tags: ['key-account'], interactions: []),
    Contact(id: 8, firstName: 'David',   lastName: 'Osei',     jobTitle: 'Medical Director',          department: 'Administration', email: 'd.osei@almc.or.tz',           phone: '+255 754 123 008', hospitalName: 'Arusha Lutheran Med. Ctr.',    lastContactedAt: '2 days ago', nextFollowupAt: 'Jun 29', tags: ['lead', 'decision-maker'],
      interactions: [
        ContactInteraction(type: 'meeting', summary: 'Demo scheduled for Patient Monitor range', outcome: 'Very positive — requested formal quote', nextAction: 'Prepare proposal', nextActionDate: 'Jun 29', createdAt: '2 days ago'),
      ]),
  ];

  // ── Spare Parts (legacy — no longer used by screens, all data comes from API) ──
  static const List<SparePart> spareParts = [
    SparePart(id: 1,  sku: 'MIN-FS-6800',   name: 'Flow Sensor Module',        category: 'machine_part', unitOfMeasure: 'piece', compatibleModels: ['Mindray BC-6800', 'Mindray BC-6800 Plus'], unitCost: 280000,  stockQty: 4,  reorderLevel: 2, isLowStock: true,  supplier: 'Mindray East Africa'),
    SparePart(id: 2,  sku: 'MIN-RP-50T',    name: 'Reagent Pack 50T',          category: 'consumable',   unitOfMeasure: 'box',   compatibleModels: ['Mindray BC-6800 Plus', 'Mindray BC-5800'],  unitCost: 95000,   stockQty: 12, reorderLevel: 5, isLowStock: false, supplier: 'Mindray East Africa'),
    SparePart(id: 3,  sku: 'MIN-CF-1L',     name: 'Calibration Fluid 1L',      category: 'consumable',   unitOfMeasure: 'litre', compatibleModels: ['Mindray BC-6800', 'Mindray BC-5800'],       unitCost: 45000,   stockQty: 8,  reorderLevel: 3, isLowStock: false, supplier: 'Mindray East Africa'),
    SparePart(id: 4,  sku: 'DRG-EXV-FLT',  name: 'Expiratory Valve Filter',   category: 'machine_part', unitOfMeasure: 'piece', compatibleModels: ['Dräger Evita V300', 'Dräger Evita XL'],    unitCost: 185000,  stockQty: 2,  reorderLevel: 3, isLowStock: true,  supplier: 'Dräger East Africa Ltd'),
    SparePart(id: 5,  sku: 'DRG-TB-SET',   name: 'Breathing Circuit Tubing',  category: 'consumable',   unitOfMeasure: 'set',   compatibleModels: ['Dräger Evita V300', 'Dräger Evita XL'],    unitCost: 62000,   stockQty: 0,  reorderLevel: 5, isLowStock: true,  supplier: 'Dräger East Africa Ltd'),
    SparePart(id: 6,  sku: 'GE-MAC-ELEC',  name: 'ECG Electrode Pads 100pk',  category: 'consumable',   unitOfMeasure: 'box',   compatibleModels: ['GE MAC 2000', 'GE MAC 5500'],               unitCost: 28000,   stockQty: 15, reorderLevel: 5, isLowStock: false, supplier: 'GE Healthcare Africa'),
    SparePart(id: 7,  sku: 'SIE-US-PROBE', name: 'Linear Transducer Probe',   category: 'machine_part', unitOfMeasure: 'piece', compatibleModels: ['Siemens Acuson NX3'],                       unitCost: 1850000, stockQty: 1,  reorderLevel: 1, isLowStock: false, supplier: 'Siemens Healthineers EA'),
    SparePart(id: 8,  sku: 'TUT-GASKET',   name: 'Door Gasket / Seal Kit',    category: 'machine_part', unitOfMeasure: 'set',   compatibleModels: ['Tuttnauer 3870EA', 'Tuttnauer 2540EK'],     unitCost: 95000,   stockQty: 3,  reorderLevel: 2, isLowStock: false, supplier: 'Tuttnauer Africa'),
    SparePart(id: 9,  sku: 'PHI-GEL-5L',   name: 'Ultrasound Gel 5L',         category: 'consumable',   unitOfMeasure: 'litre', compatibleModels: ['Philips Affiniti 50', 'Siemens Acuson NX3'],unitCost: 35000,   stockQty: 6,  reorderLevel: 3, isLowStock: false, supplier: 'Parker Laboratories'),
    SparePart(id: 10, sku: 'MIN-BATT-12V',  name: 'Internal Battery 12V',      category: 'machine_part', unitOfMeasure: 'piece', compatibleModels: ['Mindray iTM-A', 'Mindray ePM-10'],          unitCost: 125000,  stockQty: 4,  reorderLevel: 2, isLowStock: false, supplier: 'Mindray East Africa'),
  ];

  // ── Notifications ─────────────────────────────────────────────────────────
  static const List<AppNotification> notifications = [
    AppNotification(id: 1, type: NotificationType.ticketAssigned,   title: 'Ticket #1042 assigned to you',    body: 'Mindray BC-6800 Plus at Muhimbili — E-32 error code. Please attend.',               entityType: 'ticket',  entityId: '1042',     isRead: false, createdAt: '2h ago'),
    AppNotification(id: 2, type: NotificationType.paymentOverdue,   title: 'Invoice INV-2025-0140 overdue',   body: 'Payment of TSh 2.1M from Jakaya Kikwete Cardiac Inst. is 5 days overdue.',           entityType: 'invoice', entityId: '3',        isRead: false, createdAt: '5h ago'),
    AppNotification(id: 3, type: NotificationType.warrantyExpiring, title: 'Warranty expiring in 14 days',   body: 'Siemens Acuson NX3 (ACX3-1098) at Aga Khan Hospital warranty ends 02 Jul 2025.',     entityType: 'machine', entityId: 'ACX3-1098',isRead: false, createdAt: 'Yesterday'),
    AppNotification(id: 4, type: NotificationType.serviceDue,       title: 'Preventive maintenance due',     body: 'Dräger Evita V300 (EVV3-7721) at Aga Khan ICU is due for 6-month PM service.',        entityType: 'machine', entityId: 'EVV3-7721',isRead: false, createdAt: 'Yesterday'),
    AppNotification(id: 5, type: NotificationType.ticketUpdated,    title: 'Ticket #1040 status updated',    body: 'Neema Kileo updated ticket #1040 to In Progress. Dräger Evita V300 — Jakaya Kikwete.',entityType: 'ticket',  entityId: '1040',     isRead: true,  createdAt: '2 days ago'),
    AppNotification(id: 6, type: NotificationType.dealUpdated,      title: 'Deal moved to Negotiation',      body: 'Muhimbili Orthopaedic — Ultrasound Unit deal (TSh 310M) moved to Negotiation stage.', entityType: 'deal',    isRead: true,  createdAt: '3 days ago'),
    AppNotification(id: 7, type: NotificationType.paymentOverdue,   title: 'Invoice INV-2025-0133 overdue',  body: 'Payment of TSh 1.24M from Muhimbili National Hospital is 3 days overdue.',           entityType: 'invoice', entityId: '10',       isRead: true,  createdAt: '3 days ago'),
    AppNotification(id: 8, type: NotificationType.system,           title: 'System backup completed',        body: 'Nightly database backup completed successfully. All 847 machine records synced.',      isRead: true,  createdAt: '4 days ago'),
  ];

  // ── Machine service history (for MachineDetailScreen) ────────────────────
  static const List<Map<String, dynamic>> machineServiceHistory = [
    {'ticketId': '#1042', 'date': '23 Jun 2025', 'type': 'Corrective',   'technician': 'Asha Komba',      'status': 'in_progress', 'issue': 'E-32 error on startup, WBC inconsistencies',      'resolution': ''},
    {'ticketId': '#1021', 'date': '12 May 2025', 'type': 'PM',           'technician': 'Peter Rwakatare', 'status': 'resolved',    'issue': 'Scheduled 6-month preventive maintenance',         'resolution': 'Cleaned flow path, replaced reagents, recalibrated'},
    {'ticketId': '#0998', 'date': '14 Jan 2025', 'type': 'Corrective',   'technician': 'Asha Komba',      'status': 'resolved',    'issue': 'Reagent line blockage causing low WBC count',      'resolution': 'Flushed reagent lines, replaced flow sensor'},
    {'ticketId': '#0965', 'date': '02 Nov 2024', 'type': 'PM',           'technician': 'Neema Kileo',     'status': 'resolved',    'issue': 'Scheduled 6-month preventive maintenance',         'resolution': 'Full service completed, calibration updated'},
    {'ticketId': '#0901', 'date': '18 Jul 2024', 'type': 'Inspection',   'technician': 'Asha Komba',      'status': 'resolved',    'issue': 'Annual compliance inspection & calibration check', 'resolution': 'Passed inspection, certificates renewed'},
    {'ticketId': '#0844', 'date': '05 Apr 2024', 'type': 'PM',           'technician': 'Peter Rwakatare', 'status': 'resolved',    'issue': 'Scheduled 6-month preventive maintenance',         'resolution': 'Service complete, replaced consumables'},
    {'ticketId': '#0780', 'date': '12 Nov 2023', 'type': 'Installation', 'technician': 'Asha Komba',      'status': 'resolved',    'issue': 'Initial installation and commissioning',           'resolution': 'Installed, tested, and handed over to hospital'},
  ];

  // ── Helpers ───────────────────────────────────────────────────────────────
  static String tshShort(int n) {
    if (n >= 1000000000) return 'TSh ${(n / 1e9).toStringAsFixed(2)}B';
    if (n >= 1000000)    return 'TSh ${(n / 1e6).toStringAsFixed(1)}M';
    if (n >= 1000)       return 'TSh ${(n / 1e3).toStringAsFixed(0)}K';
    return 'TSh $n';
  }

  static String tshFromDouble(double n) {
    if (n >= 1000000000) return 'TSh ${(n / 1e9).toStringAsFixed(2)}B';
    if (n >= 1000000)    return 'TSh ${(n / 1e6).toStringAsFixed(1)}M';
    if (n >= 1000)       return 'TSh ${(n / 1e3).toStringAsFixed(0)}K';
    return 'TSh ${n.toStringAsFixed(0)}';
  }
}
