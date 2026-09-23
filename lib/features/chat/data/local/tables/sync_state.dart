/// Drift-style SQLite table `sync_state`.
class SyncStateTable {
  static const name = 'sync_state';

  static const createSql = '''
CREATE TABLE IF NOT EXISTS sync_state (
  key TEXT PRIMARY KEY NOT NULL,
  last_cursor TEXT,
  last_error TEXT,
  is_syncing INTEGER NOT NULL DEFAULT 0
)
''';
}
