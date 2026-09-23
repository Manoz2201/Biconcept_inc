import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../agent/document_reader.dart';
import 'json_disk.dart';

class AgentAttachment {
  AgentAttachment({
    required this.id,
    required this.name,
    required this.kind,
    required this.text,
    this.path = '',
    this.summary = '',
    DateTime? attachedAt,
  }) : attachedAt = attachedAt ?? DateTime.now();

  final String id;
  final String name;
  final String kind;
  String text;
  String path;
  String summary;
  final DateTime attachedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind,
        'text': text,
        'path': path,
        'summary': summary,
        'attachedAt': attachedAt.toIso8601String(),
      };

  factory AgentAttachment.fromJson(Map<String, dynamic> json) {
    return AgentAttachment(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      attachedAt: DateTime.tryParse(json['attachedAt']?.toString() ?? ''),
    );
  }
}

class AgentChatTurn {
  AgentChatTurn({
    required this.text,
    required this.user,
    List<AgentAttachment>? attachments,
    DateTime? at,
  })  : attachments = attachments ?? <AgentAttachment>[],
        at = at ?? DateTime.now();

  final String text;
  final bool user;
  final List<AgentAttachment> attachments;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'text': text,
        'user': user,
        'at': at.toIso8601String(),
        'attachments': [for (final item in attachments) item.toJson()],
      };

  factory AgentChatTurn.fromJson(Map<String, dynamic> json) {
    return AgentChatTurn(
      text: json['text']?.toString() ?? '',
      user: json['user'] == true,
      at: DateTime.tryParse(json['at']?.toString() ?? ''),
      attachments: [
        for (final item in json['attachments'] as List? ?? const [])
          if (item is Map) AgentAttachment.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }
}

/// Local session cache for Manoj: chat turns + extracted attachments.
class AgentSessionStore extends ChangeNotifier {
  AgentSessionStore._();

  static final instance = AgentSessionStore._();

  static const _maxTurns = 80;
  static const _maxDocuments = 16;
  static const _historyTurns = 12;
  static const _historyChars = 8000;
  static const _documentChars = 20000;

  Directory? overrideDirectory;
  final _disk = JsonDisk(
    relativePath: 'biconcept/cache/agent_session',
    prefsPrefix: 'biconcept.session.',
    useSupport: true,
  );
  String sessionId = '';
  DateTime? startedAt;
  DateTime? updatedAt;
  final messages = <AgentChatTurn>[];
  final documents = <AgentAttachment>[];
  final pending = <AgentAttachment>[];
  bool loaded = false;
  Timer? _persistTimer;

  void _bind() => _disk.overrideDataDir = overrideDirectory;

  Future<Directory?> _root() async {
    _bind();
    return _disk.folder();
  }

  Future<Directory?> _filesDir() async {
    final root = await _root();
    if (root == null) return null;
    final dir = Directory('${root.path}/files');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> ensureLoaded() async {
    if (loaded) return;
    loaded = true;
    try {
      _bind();
      final decoded = await _disk.readJson('session.json');
      if (decoded == null) {
        _newIdentity();
        return;
      }
      sessionId = decoded['id']?.toString() ?? '';
      startedAt = DateTime.tryParse(decoded['startedAt']?.toString() ?? '');
      updatedAt = DateTime.tryParse(decoded['updatedAt']?.toString() ?? '');
      messages
        ..clear()
        ..addAll([
          for (final item in decoded['messages'] as List? ?? const [])
            if (item is Map) AgentChatTurn.fromJson(Map<String, dynamic>.from(item)),
        ]);
      documents
        ..clear()
        ..addAll([
          for (final item in decoded['documents'] as List? ?? const [])
            if (item is Map) AgentAttachment.fromJson(Map<String, dynamic>.from(item)),
        ]);
      if (sessionId.isEmpty) _newIdentity();
    } catch (_) {
      _newIdentity();
    }
    notifyListeners();
  }

  void _newIdentity() {
    sessionId = DateTime.now().microsecondsSinceEpoch.toString();
    startedAt = DateTime.now();
    updatedAt = startedAt;
    messages.clear();
    documents.clear();
    pending.clear();
  }

  Future<void> clear() async {
    _persistTimer?.cancel();
    messages.clear();
    documents.clear();
    pending.clear();
    _newIdentity();
    try {
      final files = await _filesDir();
      if (files != null && await files.exists()) await files.delete(recursive: true);
      _bind();
      await _disk.delete('session.json');
    } catch (_) {}
    notifyListeners();
    await _writeNow();
  }

  Future<AgentAttachment> attachExtract(DocumentExtract extract, {List<int>? copyBytes}) async {
    await ensureLoaded();
    final attachment = AgentAttachment(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: extract.name.split(RegExp(r'[\\/]')).last,
      kind: extract.kind,
      text: extract.text,
    );
    if (copyBytes != null && copyBytes.isNotEmpty) {
      try {
        final dir = await _filesDir();
        if (dir == null) throw UnsupportedError('no files dir');
        final safe = attachment.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
        final file = File('${dir.path}/${attachment.id}_$safe');
        await file.writeAsBytes(copyBytes, flush: true);
        attachment.path = file.path;
      } catch (_) {}
    }
    pending.add(attachment);
    documents.removeWhere((item) => item.name.toLowerCase() == attachment.name.toLowerCase());
    documents.insert(0, attachment);
    if (documents.length > _maxDocuments) {
      documents.removeRange(_maxDocuments, documents.length);
    }
    notifyListeners();
    _schedulePersist();
    return attachment;
  }

  void removePending(String id) {
    pending.removeWhere((item) => item.id == id);
    notifyListeners();
    _schedulePersist();
  }

  List<AgentAttachment> takePending() {
    final taken = [...pending];
    pending.clear();
    notifyListeners();
    return taken;
  }

  Future<void> addTurn(AgentChatTurn turn) async {
    await ensureLoaded();
    messages.add(turn);
    if (messages.length > _maxTurns) {
      messages.removeRange(0, messages.length - _maxTurns);
    }
    updatedAt = DateTime.now();
    notifyListeners();
    _schedulePersist();
  }

  void saveSummary(String id, String summary) {
    for (final item in documents) {
      if (item.id == id) item.summary = summary;
    }
    notifyListeners();
    _schedulePersist();
  }

  List<Map<String, String>> llmHistory() {
    final prior = messages.length <= 1 ? const <AgentChatTurn>[] : messages.sublist(0, messages.length - 1);
    return [
      for (final turn in historyForModelSource(prior))
        {'role': turn.user ? 'user' : 'assistant', 'content': turn.text},
    ];
  }

  List<AgentChatTurn> historyForModelSource(List<AgentChatTurn> source) {
    final recent = source.length > _historyTurns
        ? source.sublist(source.length - _historyTurns)
        : source;
    var budget = _historyChars;
    final kept = <AgentChatTurn>[];
    for (final turn in recent.reversed) {
      final slice = turn.text.length > 1200 ? '${turn.text.substring(0, 1200)}…' : turn.text;
      if (slice.length > budget && kept.isNotEmpty) break;
      budget -= slice.length;
      kept.add(
        AgentChatTurn(text: slice, user: turn.user, at: turn.at, attachments: turn.attachments),
      );
    }
    return kept.reversed.toList();
  }

  String documentsContext() {
    if (documents.isEmpty) return '';
    final parts = <String>[];
    var budget = _documentChars;
    for (final doc in documents) {
      if (budget <= 0) break;
      final body = doc.text.length > budget ? '${doc.text.substring(0, budget)}…' : doc.text;
      budget -= body.length;
      final summary = doc.summary.trim().isEmpty ? '' : '\nSaved summary: ${doc.summary}';
      parts.add('File: ${doc.name} (${doc.kind})$summary\n$body');
    }
    return parts.join('\n\n---\n\n');
  }

  AgentAttachment? findDocument({String? id, String? name}) {
    final idNeedle = id?.trim() ?? '';
    if (idNeedle.isNotEmpty) {
      for (final item in documents) {
        if (item.id == idNeedle) return item;
      }
    }
    final nameNeedle = name?.trim().toLowerCase() ?? '';
    if (nameNeedle.isNotEmpty) {
      for (final item in documents) {
        if (item.name.toLowerCase() == nameNeedle) return item;
      }
      for (final item in documents) {
        if (item.name.toLowerCase().contains(nameNeedle)) return item;
      }
    }
    return null;
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 250), () {
      unawaited(_writeNow());
    });
  }

  Future<void> _writeNow() async {
    updatedAt = DateTime.now();
    final payload = {
      'id': sessionId,
      'startedAt': (startedAt ?? DateTime.now()).toIso8601String(),
      'updatedAt': updatedAt!.toIso8601String(),
      'messages': [for (final item in messages) item.toJson()],
      'documents': [for (final item in documents) item.toJson()],
    };
    try {
      _bind();
      await _disk.writeJson('session.json', payload);
    } catch (_) {}
  }
}
