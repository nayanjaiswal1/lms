# System Design Canvas

Everything about the drag-and-drop system architecture diagram tool: canvas, palette, interactions, versioning, embed, and course integration.

---

## Overview

A native drag-and-drop canvas for building system architecture diagrams. No external tool, no vendor account — full org ownership. Built on React Flow (`@xyflow/react` v12, MIT).

### Where It Lives

```
Standalone     /design           list all designs (mine + org-visible)
               /design/:id       open canvas (view or edit)

Embedded       wiki page         type /design → picker → read-only embed
               course module     type=system_design → student views or submits design
```

---

## Canvas UI

```
┌────────────────────────────────────────────────────────────────────────┐
│  [← Back]  System Design: URL Shortener   [Share ▾]  [Export PNG]     │
├───────────────┬────────────────────────────────────┬───────────────────┤
│  PALETTE      │         CANVAS (React Flow)        │  PROPERTIES       │
│               │                                    │  (selected node)  │
│  Clients      │   [Browser] ──REST──► [LB]         │                   │
│  ■ Browser    │                          │         │  Label: API Server │
│  ■ Mobile     │                          ▼         │  Sublabel: Go      │
│               │                     [API Server]   │  Color: [blue  ▾] │
│  Network      │                       /    \       │  Icon:  [server ▾] │
│  ■ Load Bal.  │              [Cache]      [DB]     │                   │
│  ■ CDN        │              Redis        Postgres │  [Duplicate]      │
│  ■ API GW     │                                    │  [Delete]         │
│               │                                    │                   │
│  Storage      │   [+ drag any component here]      │                   │
│  ■ SQL DB     │                                    │                   │
│  ■ Cache      ├────────────────────────────────────┤                   │
│  ■ Object S.  │  [Undo] [Redo]  [Fit] [100% ▾]    │                   │
│               │                                    │                   │
│  Messaging    │                                    │                   │
│  ■ Queue      │                                    │                   │
│  ■ Kafka      │                                    │                   │
│               │                                    │                   │
│  Compute      │                                    │                   │
│  ■ Server     │                                    │                   │
│  ■ Function   │                                    │                   │
│               │                                    │                   │
│  Boundary     │                                    │                   │
│  ■ VPC        │                                    │                   │
│  ■ Region     │                                    │                   │
│  ■ AZ         │                                    │                   │
└───────────────┴────────────────────────────────────┴───────────────────┘
```

---

## Component Palette

| Category | Components |
|---|---|
| Clients | Browser, Mobile App, Desktop App |
| Network | Internet, Load Balancer, CDN, DNS, API Gateway, Firewall, Reverse Proxy |
| Compute | Server, Microservice, Serverless Function, Container, Monolith |
| Storage | SQL Database, NoSQL Database, Cache (Redis), Object Storage, File Storage, Data Warehouse, Search Engine (Elasticsearch) |
| Messaging | Message Queue, Event Bus, Pub/Sub, Stream (Kafka), Webhook |
| Boundary | VPC, Region, Availability Zone, Cluster |
| Misc | User/Actor, Note/Annotation, Custom (blank node) |

Boundary nodes use React Flow group node feature — child nodes snap inside the boundary box.

---

## Canvas Interactions

| Action | How |
|---|---|
| Add component | Drag from palette onto canvas |
| Move node | Drag node |
| Connect nodes | Hover node edge → drag handle → drop on target |
| Label connection | Double-click edge → type label ("REST", "gRPC", "async") |
| Edge style | Select edge → Properties → Arrow / Bidirectional / Dashed |
| Select multiple | Shift-click or drag selection box |
| Group into boundary | Select nodes → right-click → "Group in VPC / Region / AZ" |
| Undo / Redo | Ctrl+Z / Ctrl+Y |
| Zoom | Scroll wheel or zoom controls |
| Fit to screen | Ctrl+Shift+F |
| Delete | Select → Delete key |
| Duplicate | Select → Ctrl+D |

---

## Data Format (JSONB)

```json
{
  "nodes": [
    {
      "id": "n1",
      "type": "server",
      "position": { "x": 300, "y": 200 },
      "data": { "label": "API Server", "sublabel": "Go", "color": "#3b82f6" }
    }
  ],
  "edges": [
    {
      "id": "e1",
      "source": "n1",
      "target": "n2",
      "label": "SQL",
      "style": "arrow",
      "animated": false
    }
  ]
}
```

---

## Versioning

Every save appends a `system_design_versions` row. History panel lists versions with timestamps. Any version can be restored (same pattern as wiki pages).

---

## Sharing & Embedding

- Visibility: `private` (default) | `org` (all org members) | `public` (anyone with link)
- Export: PNG download via React Flow `toBlob`, or JSON export
- Wiki embed: type `/design` in TipTap → search designs → inserts read-only embed
- Course module `type=system_design`: instructor pins a design for students to study, or leaves blank for students to submit their own

---

## API Endpoints

```
GET    /api/designs                          (org context) list mine + org-visible designs
POST   /api/designs                          body: {title, description?, visibility}
GET    /api/designs/:id                      full design (nodes, edges, viewport, version)
PATCH  /api/designs/:id                      body: {title?, description?, nodes?, edges?, viewport?, visibility?}
                                             autosaves version row on every content change
DELETE /api/designs/:id                      (creator | org_admin)

GET    /api/designs/:id/versions             [{version, saved_by, saved_at}]
GET    /api/designs/:id/versions/:v          full snapshot for that version
POST   /api/designs/:id/versions/:v/restore  restore snapshot; bumps version counter

GET    /api/designs/:id/embed                read-only response (public if visibility=public)
```

---

## Database Schema

```sql
system_designs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id      UUID REFERENCES organizations(id) ON DELETE CASCADE,
  created_by  UUID NOT NULL REFERENCES users(id),
  title       TEXT NOT NULL,
  description TEXT,
  nodes       JSONB NOT NULL DEFAULT '[]',
  edges       JSONB NOT NULL DEFAULT '[]',
  viewport    JSONB NOT NULL DEFAULT '{"x":0,"y":0,"zoom":1}',
  version     INT NOT NULL DEFAULT 1,
  visibility  TEXT NOT NULL DEFAULT 'private',  -- 'private' | 'org' | 'public'
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
)

system_design_versions (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  design_id UUID NOT NULL REFERENCES system_designs(id) ON DELETE CASCADE,
  version   INT NOT NULL,
  nodes     JSONB NOT NULL,
  edges     JSONB NOT NULL,
  saved_by  UUID NOT NULL REFERENCES users(id),
  saved_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (design_id, version)
)
```
