import Database from 'better-sqlite3'
import { join } from 'path'

const DB_PATH = process.env.DB_PATH || join(process.env.HOME!, 'studylist', 'data.db')

// Ensure directory exists
import { mkdirSync } from 'fs'
mkdirSync(join(process.env.HOME!, 'studylist'), { recursive: true })

const db = new Database(DB_PATH)

// Enable WAL mode for better concurrency
db.pragma('journal_mode = WAL')

// Initialize schema
db.exec(`
  CREATE TABLE IF NOT EXISTS cards (
    id TEXT PRIMARY KEY,
    japanese TEXT NOT NULL,
    reading TEXT,
    english TEXT NOT NULL,
    deck_name TEXT NOT NULL,
    anki_interval INTEGER,
    anki_due_date TEXT,
    anki_last_reviewed TEXT,
    anki_ease_factor REAL,
    updated_at INTEGER DEFAULT (strftime('%s', 'now'))
  );

  CREATE TABLE IF NOT EXISTS daily_selections (
    date TEXT PRIMARY KEY,
    card_ids TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS user_settings (
    id INTEGER PRIMARY KEY DEFAULT 1,
    daily_count INTEGER DEFAULT 15,
    notification_times TEXT DEFAULT '["09:00","13:00","18:00","21:00"]'
  );

  INSERT OR IGNORE INTO user_settings (id) VALUES (1);
`)

export interface Card {
  id: string
  japanese: string
  reading: string | null
  english: string
  deck_name: string
  anki_interval: number | null
  anki_due_date: string | null
  anki_last_reviewed: string | null
  anki_ease_factor: number | null
  updated_at: number
}

export interface DailySelection {
  date: string
  card_ids: string[]
}

export interface UserSettings {
  id: number
  daily_count: number
  notification_times: string[]
}

export function getAllCards(): Card[] {
  const stmt = db.prepare('SELECT * FROM cards ORDER BY updated_at DESC')
  return stmt.all() as Card[]
}

export function getCardsByDeck(deckName: string): Card[] {
  const stmt = db.prepare('SELECT * FROM cards WHERE deck_name = ?')
  return stmt.all(deckName) as Card[]
}

export function upsertCard(card: Omit<Card, 'updated_at'>): void {
  const stmt = db.prepare(`
    INSERT INTO cards (id, japanese, reading, english, deck_name,
                       anki_interval, anki_due_date, anki_last_reviewed, anki_ease_factor, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, strftime('%s', 'now'))
    ON CONFLICT(id) DO UPDATE SET
      japanese = excluded.japanese,
      reading = excluded.reading,
      english = excluded.english,
      deck_name = excluded.deck_name,
      anki_interval = excluded.anki_interval,
      anki_due_date = excluded.anki_due_date,
      anki_last_reviewed = excluded.anki_last_reviewed,
      anki_ease_factor = excluded.anki_ease_factor,
      updated_at = strftime('%s', 'now')
  `)
  stmt.run(
    card.id,
    card.japanese,
    card.reading,
    card.english,
    card.deck_name,
    card.anki_interval,
    card.anki_due_date,
    card.anki_last_reviewed,
    card.anki_ease_factor
  )
}

export function getDailySelection(date: string): DailySelection | null {
  const stmt = db.prepare('SELECT * FROM daily_selections WHERE date = ?')
  const row = stmt.get(date) as { date: string; card_ids: string } | undefined
  if (!row) return null
  return { date: row.date, card_ids: JSON.parse(row.card_ids) }
}

export function setDailySelection(date: string, cardIds: string[]): void {
  const stmt = db.prepare(`
    INSERT INTO daily_selections (date, card_ids)
    VALUES (?, ?)
    ON CONFLICT(date) DO UPDATE SET card_ids = excluded.card_ids
  `)
  stmt.run(date, JSON.stringify(cardIds))
}

export function getRandomCardsForToday(date: string): string[] {
  const settings = getSettings()
  const selectedIds = db
    .prepare('SELECT id FROM cards ORDER BY RANDOM() LIMIT ?')
    .all(settings.daily_count) as { id: string }[]

  const ids = selectedIds.map((r) => r.id)
  setDailySelection(date, ids)
  return ids
}

export function getSettings(): UserSettings {
  const stmt = db.prepare('SELECT * FROM user_settings WHERE id = 1')
  const row = stmt.get() as Record<string, unknown>
  return {
    ...row,
    notification_times: JSON.parse(row.notification_times as string),
  } as UserSettings
}

export function updateSettings(settings: Partial<Omit<UserSettings, 'id'>>): UserSettings {
  const current = getSettings()
  const updated = { ...current, ...settings }
  const stmt = db.prepare(`
    UPDATE user_settings SET 
      daily_count = ?,
      notification_times = ?
    WHERE id = 1
  `)
  stmt.run(updated.daily_count, JSON.stringify(updated.notification_times))
  return updated
}

export { db }
