import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../models/contact.dart';
import '../models/service_ticket.dart';
import '../models/inventory_item.dart';
import '../models/spare_part.dart';
import '../models/task_item.dart';

class CsvExport {
  CsvExport._();

  static Future<String?> tickets(List<ServiceTicket> items) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Service Tickets',
      fileName: 'tickets_${_today()}.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (path == null) return null;

    final buf = StringBuffer();
    buf.writeln(_row(['Ticket #', 'Machine', 'Type', 'Hospital', 'Ward',
        'Technician', 'Status', 'Created At', 'Description', 'Resolution Notes']));
    for (final t in items) {
      buf.writeln(_row([
        t.id, t.machineName, t.machineType, t.hospital, t.ward,
        t.technicianName, t.status.label, t.createdAt,
        t.description ?? '', t.resolutionNotes ?? '',
      ]));
    }
    await File(path).writeAsString(buf.toString(), flush: true);
    return path;
  }

  static Future<String?> inventoryItems(List<InventoryItem> items) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Inventory',
      fileName: 'inventory_${_today()}.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (path == null) return null;

    final buf = StringBuffer();
    buf.writeln(_row(['SKU', 'Name', 'Category', 'Manufacturer', 'Unit',
        'Stock Qty', 'Reorder Level', 'Unit Cost', 'Currency', 'CE', 'FDA', 'TBS']));
    for (final p in items) {
      buf.writeln(_row([
        p.sku, p.name, p.category, p.manufacturer ?? '',
        p.unitOfMeasure, p.stockQty.toString(), p.reorderLevel.toString(),
        p.unitCost.toStringAsFixed(0), p.currency,
        p.hasCe ? 'Yes' : 'No', p.hasFda ? 'Yes' : 'No', p.hasTbs ? 'Yes' : 'No',
      ]));
    }
    await File(path).writeAsString(buf.toString(), flush: true);
    return path;
  }

  static Future<String?> inventory(List<SparePart> items) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Inventory',
      fileName: 'inventory_${_today()}.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (path == null) return null;

    final buf = StringBuffer();
    buf.writeln(_row(['SKU', 'Name', 'Category', 'Unit', 'Stock Qty',
        'Reorder Level', 'Unit Cost (TZS)', 'Supplier', 'Low Stock']));
    for (final p in items) {
      buf.writeln(_row([
        p.sku, p.name, p.category, p.unitOfMeasure,
        p.stockQty.toString(), p.reorderLevel.toString(),
        p.unitCost.toStringAsFixed(0), p.supplier,
        p.isLowStock ? 'Yes' : 'No',
      ]));
    }
    await File(path).writeAsString(buf.toString(), flush: true);
    return path;
  }

  static Future<String?> contacts(List<Contact> items) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Contacts',
      fileName: 'contacts_${_today()}.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (path == null) return null;

    final buf = StringBuffer();
    buf.writeln(_row(['First Name', 'Last Name', 'Job Title', 'Department',
        'Hospital', 'Phone', 'Email', 'WhatsApp', 'Tags',
        'Last Contacted', 'Next Follow-up']));
    for (final c in items) {
      buf.writeln(_row([
        c.firstName, c.lastName, c.jobTitle ?? '', c.department ?? '',
        c.hospitalName, c.phone ?? '', c.email ?? '', c.whatsapp ?? '',
        c.tags.join('; '), c.lastContactedAt ?? '', c.nextFollowupAt ?? '',
      ]));
    }
    await File(path).writeAsString(buf.toString(), flush: true);
    return path;
  }

  static Future<String?> tasks(List<TaskItem> items, {String? staffName}) async {
    final label = staffName != null ? staffName.replaceAll(' ', '_') : 'all';
    final path  = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Task Report',
      fileName: 'tasks_${label}_${_today()}.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (path == null) return null;

    final buf = StringBuffer();
    buf.writeln(_row(['Title', 'Category', 'Task Type', 'Priority', 'Status',
        'Assigned To', 'Due Date', 'Started At', 'Completed At', 'Created At', 'Description']));
    for (final t in items) {
      buf.writeln(_row([
        t.title, t.category, t.taskType, t.priority, t.status,
        t.assigneeName ?? '', t.dueDate ?? '', t.startedAt ?? '',
        t.completedAt ?? '', t.createdAt, t.description ?? '',
      ]));
    }
    await File(path).writeAsString(buf.toString(), flush: true);
    return path;
  }

  static String _today() => DateTime.now().toIso8601String().substring(0, 10);
  static String _q(String s) => '"${s.replaceAll('"', '""')}"';
  static String _row(List<String> cells) => cells.map(_q).join(',');
}
