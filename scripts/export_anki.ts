/**
 * AnkiConnect sync script.
 * Reads cards from Anki via AnkiConnect plugin and syncs to local backend.
 * Run with: npx tsx scripts/export_anki.ts [--dry-run]
 */

import { readFileSync } from 'fs'
import { resolve } from 'path'

const ANKI_CONNECT_URL = 'http://localhost:8765'
const DEFAULT_API_URL = 'http://localhost:8766'

interface DeckFieldMapping {
  japanese: string
  reading: string
  english: string
}

interface Config {
  decks: Record<string, DeckFieldMapping>
}

interface AnkiConnectRequest {
  action: string
  version: number
  params?: Record<string, unknown>
}

interface AnkiConnectResponse<T> {
  error: string | null
  result: T
}

interface CardInfo {
  cardId: number
  fields: Record<string, { value: string }>
  interval: number
  due: number
  note: number
  queue: number // -1 = suspended, -2 = buried, >= 0 = normal
  reps: number // number of reviews (0 = never seen)
  lapses: number
}

async function invoke<T>(action: string, params?: Record<string, unknown>): Promise<T> {
  const body: AnkiConnectRequest = { action, version: 6, params }
  const resp = await fetch(ANKI_CONNECT_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  const result = (await resp.json()) as AnkiConnectResponse<T>
  if (result.error) {
    throw new Error(`AnkiConnect error: ${result.error}`)
  }
  return result.result
}

async function getDeckNames(): Promise<string[]> {
  return invoke<string[]>('deckNames')
}

async function getCardsFromDeck(
  deckName: string,
  mapping: DeckFieldMapping
): Promise<Omit<import('../backend/src/db.js').Card, 'updated_at'>[]> {
  const cardIds = await invoke<number[]>('findCards', {
    query: `deck:"${deckName}"`,
  })
  if (!cardIds.length) return []

  // Use cardsInfo since findCards returns card IDs, not note IDs
  const cardsInfo = await invoke<CardInfo[]>('cardsInfo', { cards: cardIds })

  // Filter out suspended (queue === -1) and buried (queue === -2) cards
  // Also filter cards with empty required fields
  // Only include cards that have been seen (reps > 0)
  const activeCards = cardsInfo.filter(
    (c) =>
      c.queue >= 0 &&
      c.reps > 0 &&
      c.fields[mapping.japanese]?.value &&
      c.fields[mapping.english]?.value
  )

  return activeCards.map((card) => ({
    id: String(card.note), // Use note ID as card ID for deduplication
    deck_name: deckName,
    japanese: card.fields[mapping.japanese]?.value ?? '',
    reading: mapping.reading ? (card.fields[mapping.reading]?.value ?? '') : '',
    english: card.fields[mapping.english]?.value ?? '',
    anki_interval: card.interval,
    anki_due_date: card.due > 0 ? new Date(card.due * 1000).toISOString() : null,
    anki_last_reviewed: null,
    anki_ease_factor: null,
  }))
}

async function syncToApi(
  apiUrl: string,
  cards: Omit<import('../backend/src/db.js').Card, 'updated_at'>[]
): Promise<{ synced?: number; error?: string }> {
  const resp = await fetch(`${apiUrl}/sync`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ cards }),
  })
  return resp.json()
}

async function main() {
  const args = process.argv.slice(2)
  const dryRun = args.includes('--dry-run')
  let apiUrl = DEFAULT_API_URL

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--api-url') {
      apiUrl = args[++i]
    }
  }

  // Load config
  const configPath = resolve(import.meta.dirname, 'config.json')
  const config: Config = JSON.parse(readFileSync(configPath, 'utf-8'))

  try {
    const deckNames = await getDeckNames()
    console.log(`Found ${deckNames.length} decks in Anki`)

    const allCards: Omit<import('../backend/src/db.js').Card, 'updated_at'>[] = []

    for (const [deckName, mapping] of Object.entries(config.decks)) {
      if (!deckNames.includes(deckName)) {
        console.log(`Warning: Deck "${deckName}" not found in Anki, skipping`)
        continue
      }
      const cards = await getCardsFromDeck(deckName, mapping)
      console.log(`  ${deckName}: ${cards.length} cards`)
      allCards.push(...cards)
    }

    console.log(`\nTotal cards: ${allCards.length}`)

    if (allCards.length > 0) {
      const sample = allCards[0]
      console.log(`\nSample card:`)
      console.log(`  Japanese: ${sample.japanese}`)
      console.log(`  Reading: ${sample.reading}`)
      console.log(`  English: ${sample.english}`)
      console.log(`  Deck: ${sample.deck_name}`)
    }

    if (dryRun) {
      console.log('\n--- DRY RUN ---')
      console.log(JSON.stringify(allCards, null, 2))
      return
    }

    console.log(`\nSyncing to ${apiUrl}...`)
    const result = await syncToApi(apiUrl, allCards)
    if (result.error) {
      console.error(`Sync error: ${result.error}`)
    } else {
      console.log(`Synced ${result.synced ?? allCards.length} cards to database`)
    }
  } catch (err) {
    if (err instanceof TypeError && err.message.includes('fetch')) {
      console.log('Error: Could not connect to AnkiConnect')
      console.log('Make sure Anki is running with the AnkiConnect plugin installed.')
    } else {
      console.error('Error:', err)
    }
    process.exit(1)
  }
}

main()
