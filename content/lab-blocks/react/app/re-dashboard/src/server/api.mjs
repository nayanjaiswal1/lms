// Mock API for the Ops Console (node server/api.mjs, port 8001). State is kept
// in memory and resets when the process restarts.
import { createServer } from 'node:http';
import { customers, notes, orders } from './data.mjs';

const PORT = Number(process.env.API_PORT ?? 8001);
const PER_PAGE = 10;
const DAY_MS = 24 * 60 * 60 * 1000;

function send(res, status, body) {
  if (body === undefined) {
    res.writeHead(status);
    res.end();
    return;
  }
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (chunk) => chunks.push(chunk));
    req.on('end', () => {
      try {
        resolve(chunks.length ? JSON.parse(Buffer.concat(chunks).toString('utf8')) : {});
      } catch (error) {
        reject(error);
      }
    });
    req.on('error', reject);
  });
}

function revenueByDay(days) {
  const last = Date.UTC(2025, 2, 10);
  const rows = [];
  for (let i = days - 1; i >= 0; i -= 1) {
    const date = new Date(last - i * DAY_MS).toISOString().slice(0, 10);
    const placed = orders.filter((o) => o.status !== 'pending' && o.placed_at.startsWith(date));
    rows.push({ date, orders: placed.length, revenue_cents: placed.reduce((sum, o) => sum + o.total_cents, 0) });
  }
  return rows;
}

async function route(req, res, url) {
  const { pathname, searchParams } = url;
  const method = req.method ?? 'GET';
  let match;

  if (pathname === '/api/health') return send(res, 200, { ok: true });

  if (pathname === '/api/orders' && method === 'GET') {
    const status = searchParams.get('status') ?? 'all';
    const page = Math.max(1, Number(searchParams.get('page') ?? 1));
    const filtered = status === 'all' ? orders : orders.filter((o) => o.status === status);
    const pages = Math.max(1, Math.ceil(filtered.length / PER_PAGE));
    const items = filtered.slice((page - 1) * PER_PAGE, page * PER_PAGE);
    return send(res, 200, { items, page, pages, total: filtered.length });
  }

  if ((match = pathname.match(/^\/api\/orders\/(\d+)\/flag$/)) && method === 'POST') {
    const order = orders.find((o) => o.id === Number(match[1]));
    if (!order) return send(res, 404, { error: 'order not found' });
    order.flagged = Boolean((await readBody(req)).flagged);
    return send(res, 200, { id: order.id, flagged: order.flagged });
  }

  if ((match = pathname.match(/^\/api\/orders\/(\d+)\/notes$/))) {
    const orderId = Number(match[1]);
    if (method === 'GET') return send(res, 200, notes.filter((n) => n.order_id === orderId));
    if (method === 'POST') {
      const { text } = await readBody(req);
      if (!text || !String(text).trim()) return send(res, 422, { error: 'text is required' });
      const note = { id: Math.max(0, ...notes.map((n) => n.id)) + 1, order_id: orderId, text: String(text) };
      notes.push(note);
      return send(res, 201, note);
    }
  }

  if ((match = pathname.match(/^\/api\/notes\/(\d+)$/))) {
    const index = notes.findIndex((n) => n.id === Number(match[1]));
    if (index === -1) return send(res, 404, { error: 'note not found' });
    if (method === 'PUT') {
      const { text } = await readBody(req);
      if (!text || !String(text).trim()) return send(res, 422, { error: 'text is required' });
      notes[index].text = String(text);
      return send(res, 200, notes[index]);
    }
    if (method === 'DELETE') {
      notes.splice(index, 1);
      return send(res, 204);
    }
  }

  if (pathname === '/api/customers' && method === 'GET') {
    const q = (searchParams.get('q') ?? '').trim().toLowerCase();
    const found = customers.filter((c) => c.name.toLowerCase().includes(q) || c.email.includes(q));
    return send(res, 200, found.slice(0, 8));
  }

  if ((match = pathname.match(/^\/api\/customers\/(\d+)$/))) {
    const customer = customers.find((c) => c.id === Number(match[1]));
    if (!customer) return send(res, 404, { error: 'customer not found' });
    if (method === 'GET') return send(res, 200, customer);
    if (method === 'PUT') {
      const { name, email } = await readBody(req);
      if (!name || !String(email).includes('@')) return send(res, 422, { error: 'name and a valid email are required' });
      Object.assign(customer, { name: String(name), email: String(email) });
      return send(res, 200, customer);
    }
  }

  if (pathname === '/api/reports/revenue' && method === 'GET') {
    const days = Math.min(90, Math.max(1, Number(searchParams.get('days') ?? 30)));
    return send(res, 200, { days: revenueByDay(days) });
  }

  return send(res, 404, { error: 'not found' });
}

createServer((req, res) => {
  const url = new URL(req.url ?? '/', 'http://localhost');
  route(req, res, url).catch((error) => {
    console.error(`${req.method} ${req.url} failed:`, error);
    send(res, 500, { error: 'internal error' });
  });
}).listen(PORT, '127.0.0.1', () => {
  console.log(`mock api listening on http://127.0.0.1:${PORT}`);
});
