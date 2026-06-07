import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../theme/app_colors.dart';

/// Converts a caught exception into a short, user-readable string.
String friendlyError(Object e) {
  if (e is DioException) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout =>
        'Cannot connect to the server. Check your network.',
      DioExceptionType.receiveTimeout =>
        'The server is taking too long to respond. Please try again.',
      DioExceptionType.sendTimeout =>
        'Request timed out sending data. Please try again.',
      DioExceptionType.connectionError =>
        'Cannot reach the server. Make sure the API is running.',
      DioExceptionType.badResponse => () {
        final status = e.response?.statusCode;
        if (status == 401) return 'Session expired. Please log in again.';
        if (status == 403) return 'You don\'t have permission to access this.';
        if (status == 404) return 'Resource not found on the server.';
        if (status != null && status >= 500) return 'Server error ($status). Contact support.';
        return 'Unexpected server response ($status).';
      }(),
      DioExceptionType.cancel => 'Request was cancelled.',
      _ => 'Something went wrong. Please try again.',
    };
  }
  return e.toString().replaceAll('Exception: ', '');
}

/// Show a SnackBar error toast. Use instead of inline error text.
void showErrorToast(BuildContext context, Object error) {
  final msg = friendlyError(error);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.error_outline, color: Colors.white, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
    ]),
    backgroundColor: AppColors.coral,
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 4),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ));
}

/// Show a success toast.
void showSuccessToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
    ]),
    backgroundColor: AppColors.teal,
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 3),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ));
}
