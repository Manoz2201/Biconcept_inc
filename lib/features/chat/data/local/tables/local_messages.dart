/// Drift-style SQLite table `local_messages`.
class LocalMessagesTable {
  static const name = 'local_messages';

  static const createSql = '''
CREATE TABLE IF NOT EXISTS local_messages (
  local_id TEXT PRIMARY KEY NOT NULL,
  remote_id TEXT,
  conversation_id TEXT NOT NULL,
  sender_id TEXT NOT NULL,
  receiver_id TEXT NOT NULL,
  body TEXT NOT NULL,
  attachments TEXT NOT NULL DEFAULT '[]',
  status TEXT NOT NULL,
  retry_count INTEGER NOT NULL DEFAULT 0,
  next_retry_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''';

  static const indexes = [
    'CREATE INDEX IF NOT EXISTS local_messages_conversation_idx ON local_messages (conversation_id, created_at)',
    'CREATE INDEX IF NOT EXISTS local_messages_status_idx ON local_messages (status, next_retry_at)',
  ];
}
