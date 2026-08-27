import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class SearchResult {
  final String type;
  final int id;
  final String title;
  final String? subtitle;

  const SearchResult({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle,
  });

  factory SearchResult.fromJson(Map<String, dynamic> j) => SearchResult(
    type:     j['type'] as String,
    id:       (j['id'] as num).toInt(),
    title:    j['title'] as String? ?? '',
    subtitle: j['subtitle'] as String?,
  );
}

extension SearchResultTypeX on String {
  String get searchCategoryLabel => switch (this) {
    'machine'        => 'Machine',
    'hospital'       => 'Hospital',
    'service_ticket' => 'Service Ticket',
    'inventory_item' => 'Inventory',
    'supplier'       => 'Supplier',
    'location'       => 'Location',
    'staff'          => 'Staff',
    'sales_lead'     => 'Sales Lead',
    'quotation'      => 'Quotation',
    'sales_order'    => 'Sales Order',
    'invoice'        => 'Invoice',
    'contact'        => 'Contact',
    'vendor_bill'    => 'Vendor Bill',
    'expense'        => 'Expense',
    _                => 'Result',
  };

  IconData get searchIcon => switch (this) {
    'machine'        => Symbols.precision_manufacturing,
    'hospital'       => Symbols.local_hospital,
    'service_ticket' => Symbols.confirmation_number,
    'inventory_item' => Symbols.inventory_2,
    'supplier'       => Symbols.local_shipping,
    'location'       => Symbols.warehouse,
    'staff'          => Symbols.person,
    'sales_lead'     => Symbols.trending_up,
    'quotation'      => Symbols.request_quote,
    'sales_order'    => Symbols.shopping_cart,
    'invoice'        => Symbols.receipt_long,
    'contact'        => Symbols.contacts,
    'vendor_bill'    => Symbols.receipt,
    'expense'        => Symbols.payments,
    _                => Symbols.search,
  };
}
