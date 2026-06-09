import { serve } from '@hono/node-server'
import { Hono } from 'hono'
import { cors } from 'hono/cors'

const app = new Hono()

// CORS for local development
app.use('/*', cors())

// Health check
app.get('/health', (c) => c.json({ status: 'ok' }))

// POST /anki - proxy to AnkiConnect
app.post('/anki', async (c) => {
  const body = await c.req.json()
  const { action, params = {} } = body

  try {
    const response = await fetch('http://localhost:8765', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action, version: 6, params }),
    })
    const data = await response.json()
    return c.json(data)
  } catch (err) {
    return c.json({ error: String(err) }, 500)
  }
})

const port = parseInt(process.env.PORT || '8766')
console.log(`Starting proxy on http://localhost:${port}`)

serve({
  fetch: app.fetch,
  port,
})
