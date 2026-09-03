import 'package:flutter/material.dart';
import '../services/download_manager.dart';
import 'api_error.dart';

/// Fetches PDF bytes and saves them straight to `<Downloads>/Hypermed/`
/// instead of opening a browser tab — the shared behaviour behind every
/// "Download PDF" action (invoices, quotations, ...).
Future<void> downloadPdf(BuildContext context, Future<List<int>> Function() fetchBytes, String filename) async {
  try {
    final bytes = await fetchBytes();
    final file = await DownloadManager.instance.save(bytes, filename);
    if (context.mounted) showSuccessToast(context, 'Saved to ${file.path}');
  } catch (e) {
    if (context.mounted) showErrorToast(context, e);
  }
}
