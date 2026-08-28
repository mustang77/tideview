import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thrown for any JMAP/network problem; [message] is safe to show in the UI.
class JmapException implements Exception {
  final String message;
  JmapException(this.message);
  @override
  String toString() => message;
}

const _kCore = 'urn:ietf:params:jmap:core';
const _kMail = 'urn:ietf:params:jmap:mail';
const _kSubmission = 'urn:ietf:params:jmap:submission';

class JmapMailbox {
  final String id;
  final String name;
  final String? parentId;
  final String? role;
  final int totalEmails;
  final int unreadEmails;
  final int sortOrder;

  JmapMailbox.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = (j['name'] ?? '') as String,
        parentId = j['parentId'] as String?,
        role = j['role'] as String?,
        totalEmails = (j['totalEmails'] ?? 0) as int,
        unreadEmails = (j['unreadEmails'] ?? 0) as int,
        sortOrder = (j['sortOrder'] ?? 0) as int;
}

class EmailAddress {
  final String? name;
  final String? email;
  const EmailAddress({this.name, this.email});

  factory EmailAddress.fromJson(Map<String, dynamic> j) =>
      EmailAddress(name: j['name'] as String?, email: j['email'] as String?);

  String get display =>
      (name != null && name!.trim().isNotEmpty) ? name! : (email ?? '?');
  String get full => (name != null && name!.trim().isNotEmpty)
      ? '$name <${email ?? ''}>'
      : (email ?? '?');
}

List<EmailAddress> _addresses(dynamic v) => (v is List)
    ? v
        .whereType<Map<String, dynamic>>()
        .map(EmailAddress.fromJson)
        .toList(growable: false)
    : const [];

class EmailHeader {
  final String id;
  final String? threadId;
  final List<EmailAddress> from;
  final String subject;
  final String preview;
  final DateTime? receivedAt;
  Map<String, dynamic> keywords;
  final Map<String, dynamic> mailboxIds;
  final bool hasAttachment;

  EmailHeader.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        threadId = j['threadId'] as String?,
        from = _addresses(j['from']),
        subject = (j['subject'] ?? '(tanpa subjek)') as String,
        preview = (j['preview'] ?? '') as String,
        receivedAt = j['receivedAt'] != null
            ? DateTime.tryParse(j['receivedAt'] as String)?.toLocal()
            : null,
        keywords = Map<String, dynamic>.from(j['keywords'] ?? const {}),
        mailboxIds = Map<String, dynamic>.from(j['mailboxIds'] ?? const {}),
        hasAttachment = (j['hasAttachment'] ?? false) as bool;

  bool get seen => keywords[r'$seen'] == true;
  set seen(bool v) {
    if (v) {
      keywords[r'$seen'] = true;
    } else {
      keywords.remove(r'$seen');
    }
  }
}

class EmailAttachment {
  final String? blobId;
  final String name;
  final String type;
  final int size;

  EmailAttachment.fromJson(Map<String, dynamic> j)
      : blobId = j['blobId'] as String?,
        name = (j['name'] ?? 'attachment') as String,
        type = (j['type'] ?? 'application/octet-stream') as String,
        size = (j['size'] ?? 0) as int;
}

class EmailDetail {
  final EmailHeader header;
  final List<EmailAddress> to;
  final List<EmailAddress> cc;
  final String? html;
  final String? text;
  final List<EmailAttachment> attachments;

  EmailDetail({
    required this.header,
    required this.to,
    required this.cc,
    required this.html,
    required this.text,
    required this.attachments,
  });
}

class EmailPage {
  final List<EmailHeader> emails;
  final int total;
  final int position;
  EmailPage({required this.emails, required this.total, required this.position});
}

/// Minimal JMAP client for Stalwart (Basic auth over HTTPS).
class JmapClient {
  final String server; // e.g. mail.h2olaundry.com
  final String username; // full email address
  final String password;

  late String _apiUrl;
  late String _downloadTemplate;
  late String accountId;
  String? identityId;

  JmapClient({
    required this.server,
    required this.username,
    required this.password,
  });

  Map<String, String> get _headers => {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$username:$password'))}',
        'Content-Type': 'application/json',
      };

  /// Fetches the JMAP session and the sending identity. Must be called first.
  Future<void> connect() async {
    final http.Response res;
    try {
      res = await http.get(Uri.parse('https://$server/.well-known/jmap'),
          headers: _headers);
    } catch (e) {
      throw JmapException(
          'Tidak bisa terhubung ke $server. Cek koneksi/CORS server. ($e)');
    }
    if (res.statusCode == 401) {
      throw JmapException('Login gagal: email atau password salah.');
    }
    if (res.statusCode != 200) {
      throw JmapException('Server menjawab ${res.statusCode}. Coba lagi.');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    _apiUrl = j['apiUrl'] as String;
    _downloadTemplate = j['downloadUrl'] as String;
    final primary = j['primaryAccounts'] as Map<String, dynamic>? ?? const {};
    accountId = (primary[_kMail] ??
        (j['accounts'] as Map<String, dynamic>).keys.first) as String;

    try {
      final resp = await call([
        ['Identity/get', {'accountId': accountId}, 'i'],
      ]);
      final list = (resp[0][1]['list'] as List?) ?? const [];
      if (list.isNotEmpty) {
        final match = list.cast<Map<String, dynamic>>().where(
            (i) => (i['email'] as String?)?.toLowerCase() ==
                username.toLowerCase());
        identityId =
            (match.isNotEmpty ? match.first : list.first)['id'] as String?;
      }
    } catch (_) {
      identityId = null; // sending disabled, reading still works
    }
  }

  Future<List<dynamic>> call(List<List<dynamic>> methodCalls) async {
    final http.Response res;
    try {
      res = await http.post(Uri.parse(_apiUrl),
          headers: _headers,
          body: jsonEncode({
            'using': [_kCore, _kMail, _kSubmission],
            'methodCalls': methodCalls,
          }));
    } catch (e) {
      throw JmapException('Koneksi ke server terputus. ($e)');
    }
    if (res.statusCode != 200) {
      throw JmapException('JMAP error ${res.statusCode}.');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final responses = j['methodResponses'] as List;
    for (final r in responses) {
      if (r[0] == 'error') {
        throw JmapException('JMAP: ${r[1]['type'] ?? 'unknown error'}');
      }
    }
    return responses;
  }

  Future<List<JmapMailbox>> getMailboxes() async {
    final resp = await call([
      ['Mailbox/get', {'accountId': accountId, 'ids': null}, 'm'],
    ]);
    final list = (resp[0][1]['list'] as List).cast<Map<String, dynamic>>();
    final boxes = list.map(JmapMailbox.fromJson).toList();
    const roleOrder = [
      'inbox', 'drafts', 'sent', 'archive', 'junk', 'trash'
    ];
    boxes.sort((a, b) {
      final ra = a.role != null ? roleOrder.indexOf(a.role!) : -1;
      final rb = b.role != null ? roleOrder.indexOf(b.role!) : -1;
      final ka = ra >= 0 ? ra : 100 + a.sortOrder;
      final kb = rb >= 0 ? rb : 100 + b.sortOrder;
      final c = ka.compareTo(kb);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
    return boxes;
  }

  static const _listProperties = [
    'id', 'threadId', 'mailboxIds', 'keywords', 'hasAttachment',
    'from', 'subject', 'receivedAt', 'preview',
  ];

  Future<EmailPage> queryEmails(String mailboxId,
      {int position = 0, int limit = 50}) async {
    final resp = await call([
      [
        'Email/query',
        {
          'accountId': accountId,
          'filter': {'inMailbox': mailboxId},
          'sort': [
            {'property': 'receivedAt', 'isAscending': false}
          ],
          'position': position,
          'limit': limit,
          'calculateTotal': true,
        },
        'q'
      ],
      [
        'Email/get',
        {
          'accountId': accountId,
          '#ids': {'resultOf': 'q', 'name': 'Email/query', 'path': '/ids'},
          'properties': _listProperties,
        },
        'g'
      ],
    ]);
    final total = (resp[0][1]['total'] ?? 0) as int;
    final list = (resp[1][1]['list'] as List).cast<Map<String, dynamic>>();
    final emails = list.map(EmailHeader.fromJson).toList();
    emails.sort((a, b) {
      final da = a.receivedAt, db = b.receivedAt;
      if (da == null || db == null) return 0;
      return db.compareTo(da);
    });
    return EmailPage(emails: emails, total: total, position: position);
  }

  Future<List<EmailHeader>> searchEmails(String text, {int limit = 50}) async {
    final resp = await call([
      [
        'Email/query',
        {
          'accountId': accountId,
          'filter': {'text': text},
          'sort': [
            {'property': 'receivedAt', 'isAscending': false}
          ],
          'limit': limit,
        },
        'q'
      ],
      [
        'Email/get',
        {
          'accountId': accountId,
          '#ids': {'resultOf': 'q', 'name': 'Email/query', 'path': '/ids'},
          'properties': _listProperties,
        },
        'g'
      ],
    ]);
    final list = (resp[1][1]['list'] as List).cast<Map<String, dynamic>>();
    final emails = list.map(EmailHeader.fromJson).toList();
    emails.sort((a, b) {
      final da = a.receivedAt, db = b.receivedAt;
      if (da == null || db == null) return 0;
      return db.compareTo(da);
    });
    return emails;
  }

  Future<EmailDetail> getEmail(String id) async {
    final resp = await call([
      [
        'Email/get',
        {
          'accountId': accountId,
          'ids': [id],
          'properties': [
            ..._listProperties,
            'to', 'cc', 'replyTo', 'htmlBody', 'textBody', 'bodyValues',
            'attachments',
          ],
          'fetchAllBodyValues': true,
          'maxBodyValueBytes': 1048576,
        },
        'd'
      ],
    ]);
    final list = (resp[0][1]['list'] as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) throw JmapException('Email tidak ditemukan.');
    final j = list.first;
    final bodyValues =
        Map<String, dynamic>.from(j['bodyValues'] ?? const {});

    String? collect(dynamic parts) {
      if (parts is! List || parts.isEmpty) return null;
      final buf = StringBuffer();
      for (final p in parts.cast<Map<String, dynamic>>()) {
        final v = bodyValues[p['partId']];
        if (v is Map<String, dynamic>) buf.write(v['value'] ?? '');
      }
      final s = buf.toString();
      return s.trim().isEmpty ? null : s;
    }

    return EmailDetail(
      header: EmailHeader.fromJson(j),
      to: _addresses(j['to']),
      cc: _addresses(j['cc']),
      html: collect(j['htmlBody']),
      text: collect(j['textBody']),
      attachments: ((j['attachments'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(EmailAttachment.fromJson)
          .toList(),
    );
  }

  Future<void> setSeen(String id, bool seen) async {
    await call([
      [
        'Email/set',
        {
          'accountId': accountId,
          'update': {
            id: {r'keywords/$seen': seen ? true : null}
          },
        },
        's'
      ],
    ]);
  }

  Future<void> moveToMailbox(String id, String targetMailboxId) async {
    await call([
      [
        'Email/set',
        {
          'accountId': accountId,
          'update': {
            id: {
              'mailboxIds': {targetMailboxId: true}
            }
          },
        },
        'mv'
      ],
    ]);
  }

  Future<void> destroyEmail(String id) async {
    await call([
      [
        'Email/set',
        {
          'accountId': accountId,
          'destroy': [id],
        },
        'del'
      ],
    ]);
  }

  /// Creates the message in [sentMailboxId] and submits it for delivery.
  Future<void> sendEmail({
    required String sentMailboxId,
    required List<String> to,
    List<String> cc = const [],
    required String subject,
    required String textBody,
  }) async {
    if (identityId == null) {
      throw JmapException(
          'Akun ini tidak punya identitas pengirim (Identity). Hubungi admin.');
    }
    final create = {
      'draft': {
        'mailboxIds': {sentMailboxId: true},
        'keywords': {r'$seen': true},
        'from': [
          {'email': username}
        ],
        'to': [
          for (final a in to) {'email': a}
        ],
        if (cc.isNotEmpty)
          'cc': [
            for (final a in cc) {'email': a}
          ],
        'subject': subject,
        'bodyStructure': {'type': 'text/plain', 'partId': 'p1'},
        'bodyValues': {
          'p1': {'value': textBody}
        },
      }
    };
    final resp = await call([
      ['Email/set', {'accountId': accountId, 'create': create}, 'c'],
      [
        'EmailSubmission/set',
        {
          'accountId': accountId,
          'create': {
            'sub': {'emailId': '#draft', 'identityId': identityId}
          },
        },
        'sub'
      ],
    ]);
    final created = resp[0][1]['created'] as Map<String, dynamic>?;
    if (created == null || !created.containsKey('draft')) {
      final notCreated = resp[0][1]['notCreated'];
      throw JmapException('Gagal membuat email: $notCreated');
    }
    final subCreated = resp[1][1]['created'] as Map<String, dynamic>?;
    if (subCreated == null || subCreated.isEmpty) {
      final notCreated = resp[1][1]['notCreated'];
      throw JmapException('Gagal mengirim: $notCreated');
    }
  }

  String downloadUrl(EmailAttachment a) => _downloadTemplate
      .replaceAll('{accountId}', Uri.encodeComponent(accountId))
      .replaceAll('{blobId}', Uri.encodeComponent(a.blobId ?? ''))
      .replaceAll('{name}', Uri.encodeComponent(a.name))
      .replaceAll('{type}', Uri.encodeComponent(a.type));
}
