/// Drift-style SQLite table `conversations`.
class ConversationsTable {
  static const name = 'conversations';

  static const createSql = '''
CREATE TABLE IF NOT EXISTS conversations (
  id TEXT PRIMARY KEY NOT NULL,
  peer_id TEXT NOT NULL,
  peer_name TEXT NOT NULL,
  last_message TEXT NOT NULL DEFAULT '',
  last_at INTEGER,
  unread_count INTEGER NOT NULL DEFAULT 0
)
''';

  static const indexes = [
    'CREATE INDEX IF NOT EXISTS conversations_last_at_idx ON conversations (last_at)',
  ];
}
