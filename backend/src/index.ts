import { serve } from '@hono/node-server'
import { Hono } from 'hono'
import { cors } from 'hono/cors'
import {
  getAllCards,
  upsertCard,
  getDailySelection,
  getRandomCardsForToday,
  getSettings,
  updateSettings,
  Card,
} from './db.js'

const app = new Hono()

// CORS for local development
app.use('/*', cors())

// Health check
app.get('/health', (c) => c.json({ status: 'ok' }))

// GET /cards - all cards, optionally filter by deck
app.get('/cards', (c) => {
  const deck = c.req.query('deck')
  const cards = deck ? getAllCards().filter((c) => c.deck_name === deck) : getAllCards()
  return c.json({ cards })
})

// GET /decks - list decks with card counts
app.get('/decks', (c) => {
  const cards = getAllCards()
  const deckCounts: Record<string, number> = {}
  for (const card of cards) {
    deckCounts[card.deck_name] = (deckCounts[card.deck_name] || 0) + 1
  }
  const decks = Object.entries(deckCounts)
    .map(([name, count]) => ({ name, count }))
    .sort((a, b) => a.name.localeCompare(b.name))
  return c.json({ decks })
})

// GET /daily - today's selections
app.get('/daily', (c) => {
  const today = new Date().toISOString().split('T')[0]
  let selection = getDailySelection(today)

  // Regenerate if no selection or empty (cards may have been added since last generation)
  if (!selection || selection.card_ids.length === 0) {
    const cardIds = getRandomCardsForToday(today)
    selection = { date: today, card_ids: cardIds }
  }

  const allCards = getAllCards()
  const cards = selection.card_ids
    .map((id) => allCards.find((c) => c.id === id))
    .filter((c): c is Card => c !== undefined)

  return c.json({ date: today, cards })
})

// POST /sync - upsert cards
app.post('/sync', async (c) => {
  const body = await c.req.json()
  const cards = body.cards as Omit<Card, 'updated_at'>[]

  if (!Array.isArray(cards)) {
    return c.json({ error: 'Expected { cards: [...] }' }, 400)
  }

  for (const card of cards) {
    if (!card.id || !card.japanese || !card.english || !card.deck_name) {
      console.error('Bad card:', JSON.stringify(card))
      return c.json(
        {
          error: 'Card missing required fields (id, japanese, english, deck_name)',
        },
        400
      )
    }
    upsertCard(card)
  }

  return c.json({ synced: cards.length })
})

// GET /settings
app.get('/settings', (c) => {
  return c.json(getSettings())
})

// PUT /settings
app.put('/settings', async (c) => {
  const body = await c.req.json()
  const updated = updateSettings(body)
  return c.json(updated)
})

const port = parseInt(process.env.PORT || '8766')
console.log(`Starting server on http://localhost:${port}`)

serve({
  fetch: app.fetch,
  port,
})

export default app
