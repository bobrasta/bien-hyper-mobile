class Email {
  final int     id;
  final String  from;
  final String  fromEmail;
  final String  to;
  final String? cc;
  final String? bcc;
  final String  subject;
  final String  body;     // always plain text
  final String  preview;
  final String  folder;
  final String? label;
  final bool    isRead;
  final bool    isFlagged;
  final DateTime createdAt;

  const Email({
    required this.id,
    required this.from,
    required this.fromEmail,
    required this.to,
    this.cc,
    this.bcc,
    required this.subject,
    required this.body,
    required this.preview,
    required this.folder,
    this.label,
    required this.isRead,
    required this.isFlagged,
    required this.createdAt,
  });

  String get initials {
    final parts = from.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return from.isNotEmpty ? from[0].toUpperCase() : '?';
  }

  String get timeLabel {
    final now  = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 60 && diff.inMinutes >= 0) return '${diff.inMinutes}m';
    if (createdAt.day == now.day) {
      final h = createdAt.hour.toString().padLeft(2, '0');
      final m = createdAt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (createdAt.day == yesterday.day && createdAt.month == yesterday.month) {
      return 'Yesterday';
    }
    if (diff.inDays < 7) {
      const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      return days[createdAt.weekday - 1];
    }
    return '${createdAt.day}/${createdAt.month}';
  }

  factory Email.fromJson(Map<String, dynamic> j) {
    final rawHtml  = _str(j['body_html']);
    final rawText  = _str(j['body_text']) ?? _str(j['body']) ?? _str(j['content']);
    final body     = rawHtml != null ? _htmlToText(rawHtml) : (rawText ?? '');
    final preview  = _str(j['preview']) ?? _makePreview(body);
    final ccStr    = _addrList(j['cc']);
    final bccStr   = _addrList(j['bcc']);
    return Email(
      id:        (j['id'] as num).toInt(),
      from:      _addr(j['from_name'])  ?? _addr(j['from'])  ?? '—',
      fromEmail: _addrEmail(j['from_email']) ?? _addrEmail(j['from']) ?? '',
      to:        _addrList(j['to']),
      cc:        ccStr.isNotEmpty  ? ccStr  : null,
      bcc:       bccStr.isNotEmpty ? bccStr : null,
      subject:   _str(j['subject'])  ?? '(no subject)',
      body:      body,
      preview:   preview,
      folder:    _str(j['folder'])   ?? 'inbox',
      label:     _str(j['label'])    ?? _str(j['tag']),
      isRead:    j['is_read']    is bool ? j['is_read']    as bool
                                        : j['read']    is bool ? j['read']    as bool : false,
      isFlagged: j['is_flagged'] is bool ? j['is_flagged'] as bool
                                        : j['flagged'] is bool ? j['flagged'] as bool : false,
      createdAt: DateTime.tryParse(_str(j['date']) ?? _str(j['created_at']) ?? '') ?? DateTime.now(),
    );
  }

  // ── HTML → plain text ────────────────────────────────────────────────────────

  static String _htmlToText(String html) {
    var s = html;

    // 1. Drop entire <head> block (styles, meta, link tags)
    s = s.replaceAll(RegExp(r'<head\b[^>]*>[\s\S]*?</head>', caseSensitive: false), '');

    // 2. Drop <style> and <script> blocks wherever they appear
    s = s.replaceAll(RegExp(r'<style\b[^>]*>[\s\S]*?</style>', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'<script\b[^>]*>[\s\S]*?</script>', caseSensitive: false), '');

    // 3. Drop known antivirus / mailer footers by element id
    s = s.replaceAll(RegExp(
      r'<[a-z]+[^>]*\bid="DAB4FAD8[^"]*"[^>]*>[\s\S]*?</[a-z]+>',
      caseSensitive: false), '');

    // 4. Drop HubSpot "Create Your Own Free Signature" table and everything after
    final hubIdx = s.indexOf('Create Your Own Free Signature');
    if (hubIdx != -1) {
      // Walk back to the opening <table before it
      final tableOpen = s.lastIndexOf(RegExp(r'<table', caseSensitive: false), hubIdx);
      if (tableOpen != -1) s = s.substring(0, tableOpen);
    }

    // 5. Drop Quectel / Outlook signature block (div with id="Signature")
    s = s.replaceAll(RegExp(
      r'<div\b[^>]*\bid="Signature"[^>]*>[\s\S]*?</div>',
      caseSensitive: false), '');

    // 6. Collapse block-level tags → newlines
    s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'</(p|div|tr|li|h[1-6]|blockquote)>', caseSensitive: false), '\n');

    // 7. Strip all remaining tags
    s = s.replaceAll(RegExp(r'<[^>]+>'), '');

    // 8. Decode HTML entities
    s = s
      .replaceAll('&nbsp;',  ' ')
      .replaceAll('&amp;',   '&')
      .replaceAll('&lt;',    '<')
      .replaceAll('&gt;',    '>')
      .replaceAll('&quot;',  '"')
      .replaceAll('&#39;',   "'")
      .replaceAll('&apos;',  "'");

    // 9. Normalise whitespace
    s = s.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
    s = s.replaceAll(RegExp(r' *\n *'), '\n');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return s.trim();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static String? _str(dynamic v) {
    if (v == null)   return null;
    if (v is String) return v.isEmpty ? null : v;
    if (v is Map) {
      final t = v['text'], h = v['html'];
      return (t is String && t.isNotEmpty) ? t : (h is String && h.isNotEmpty) ? h : null;
    }
    return null;
  }

  static String? _addr(dynamic v) {
    if (v == null)   return null;
    if (v is String) return v.isEmpty ? null : v;
    if (v is Map) {
      final n = v['name'], e = v['email'];
      return (n is String && n.isNotEmpty) ? n : (e is String && e.isNotEmpty) ? e : null;
    }
    if (v is List)   return v.isNotEmpty ? _addr(v.first) : null;
    return null;
  }

  static String? _addrEmail(dynamic v) {
    if (v == null)   return null;
    if (v is String) return v.isEmpty ? null : v;
    if (v is Map) {
      final e = v['email'], a = v['address'];
      return (e is String && e.isNotEmpty) ? e : (a is String && a.isNotEmpty) ? a : null;
    }
    if (v is List)   return v.isNotEmpty ? _addrEmail(v.first) : null;
    return null;
  }

  static String _addrList(dynamic v) {
    if (v == null)   return '';
    if (v is String) return v;
    if (v is Map)    return _addr(v) ?? _addrEmail(v) ?? '';
    if (v is List) {
      return v
          .map((e) => _addr(e) ?? _addrEmail(e) ?? '')
          .where((s) => s.isNotEmpty)
          .join(', ');
    }
    return v.toString();
  }

  static String _makePreview(String plainText) {
    final clean = plainText.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean.length > 120 ? '${clean.substring(0, 120)}…' : clean;
  }

  Email copyWith({bool? isRead, bool? isFlagged}) => Email(
    id: id, from: from, fromEmail: fromEmail, to: to, cc: cc, bcc: bcc,
    subject: subject, body: body, preview: preview, folder: folder, label: label,
    isRead:    isRead    ?? this.isRead,
    isFlagged: isFlagged ?? this.isFlagged,
    createdAt: createdAt,
  );
}
