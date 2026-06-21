# Wiki

Everything about the org wiki: spaces, pages, rich text editor, version history, comments, templates, and search.

---

## Overview

A Confluence-style collaborative knowledge base built into every org. Each org has multiple **spaces** (topic containers); each space holds a tree of nested **pages** with rich text, version history, comments, and templates.

```
Org-wide spaces      — "Engineering Docs", "Onboarding", "Company Handbook"
Course-linked spaces — auto-created when instructor enables wiki for a course;
                       scoped to enrolled students; accessible as "Course Docs" tab
```

---

## UI Layout

```
┌──────────────────────────────────────────────────────────────────┐
│  MindForge / Acme Corp / Engineering Docs / System Design        │  breadcrumb
├─────────────────────┬────────────────────────────────────────────┤
│  SIDEBAR (tree)     │  CONTENT AREA                              │
│                     │                                            │
│  📘 Engineering     │  ## System Design Overview                 │
│   ├─ 📄 Overview   │                                            │
│   ├─ 📄 API Guide  │  Rich text: headings, code, tables, images  │
│   └─ 📁 Backend    │                                            │
│       ├─ 📄 Auth   │  [Edit]  [History]  [Comments (3)]         │
│       └─ 📄 DB     │                                            │
│                     │  ──────────────────────────────────────── │
│  [+ New Page]       │  💬 Comments                              │
│  [+ New Space]      │  Alice: Great explanation of CAP...        │
│                     │    └ Bob: Agreed, but what about...        │
└─────────────────────┴────────────────────────────────────────────┘
```

---

## Spaces

- Unlimited spaces per org
- Each space: name, slug, icon (emoji), visibility (`members` = org only, `public` = anyone)
- Only `org_admin` can delete a space; creator can edit

---

## Page Tree

- Pages nest to any depth via `parent_id`
- Drag-and-drop reordering within siblings (updates `order_index`)
- Drag onto another page to reparent (`POST /wiki/pages/:id/move`)
- Deleting a parent re-parents its children to the grandparent (no orphans)
- Soft delete: `deleted_at` set, excluded from all queries unless explicitly included

---

## Rich Text Editor (TipTap)

Content stored as TipTap/ProseMirror JSON in `content` JSONB. Never raw HTML.

| Block | Detail |
|---|---|
| Headings | H1–H3 |
| Paragraph | bold, italic, underline, strikethrough, inline code |
| Code block | syntax-highlighted, language selector |
| Table | resizable columns, add/remove rows + cols |
| Lists | ordered, unordered, nested |
| Checklist | interactive checkboxes stored in JSONB |
| Image | upload via `POST /api/uploads` → URL embedded in content |
| Callout | info / warning / danger colored blocks |
| Internal page link | type `[[` to search and link another wiki page |
| Course module embed | type `/module` → picker → embeds module title + link |
| Divider | horizontal rule |

**Autosave:** debounces 2s after last keystroke → `PATCH /api/wiki/pages/:id`. Each save appends a version row.

---

## Version History

- Every `PATCH` that changes `title` or `content` appends a `wiki_page_versions` row
- History panel: version number, saved by, saved at
- Click any version to preview (read-only overlay)
- "Restore this version" copies content to current page and bumps `version` counter

---

## Comments

- Threaded (one level of replies)
- Author can edit own comment
- Author or `org_admin` can delete (soft delete — shown as "[deleted]" in thread)

---

## Templates

- Platform built-ins: Meeting Notes, SOP, Course Outline, Bug Report
- Org admins and instructors can create org-specific templates
- Creating a page: pick template → content pre-populated

---

## Full-Text Search

- Postgres `tsvector` index on `title` + extracted text from `content` JSONB
- Scoped to active org; optional space filter
- Results: page title, space name, matching excerpt, last updated

---

## Permissions

```
org_admin     → full control: create/edit/delete spaces and pages
instructor    → create spaces, create/edit/delete own pages
mentor        → create/edit own pages; read all published pages
student       → read published pages; can comment
```

---

## API Endpoints

```
-- Spaces
GET    /api/wiki/spaces                          (org context) list all spaces
POST   /api/wiki/spaces                          (org_admin | instructor)
                                                 body: {name, slug, description, icon?, visibility, course_id?}
GET    /api/wiki/spaces/:slug                    space metadata + root page tree
PATCH  /api/wiki/spaces/:id                      (space creator | org_admin)
DELETE /api/wiki/spaces/:id                      (org_admin) cascades to all pages

-- Page tree
GET    /api/wiki/spaces/:spaceId/pages           full nested tree (no content; metadata only)

-- Pages
POST   /api/wiki/spaces/:spaceId/pages           body: {title, parent_id?, emoji?, template_id?}
GET    /api/wiki/pages/:id                       page content + metadata + breadcrumb
PATCH  /api/wiki/pages/:id                       body: {title?, content?, status?, emoji?, order_index?, parent_id?}
DELETE /api/wiki/pages/:id                       soft delete; children re-parented
POST   /api/wiki/pages/:id/move                  body: {parent_id, order_index}

-- Version history
GET    /api/wiki/pages/:id/versions              list [{version, title, saved_by, saved_at}]
GET    /api/wiki/pages/:id/versions/:v           full content of that version
POST   /api/wiki/pages/:id/versions/:v/restore   restore; bumps version counter

-- Comments
GET    /api/wiki/pages/:id/comments              threaded [{comment, replies:[...]}]
POST   /api/wiki/pages/:id/comments              body: {content, parent_id?}
PATCH  /api/wiki/comments/:id                    (author only) body: {content}
DELETE /api/wiki/comments/:id                    (author | org_admin) soft delete

-- Templates
GET    /api/wiki/templates                       platform templates + org templates
POST   /api/wiki/templates                       (org_admin | instructor) body: {name, description, content}
DELETE /api/wiki/templates/:id                   (creator | org_admin)

-- Search
GET    /api/wiki/search?q=:query&space=:slug     scoped to active org; optional space filter
```

---

## Database Schema

```sql
wiki_spaces (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id      UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  course_id   UUID REFERENCES courses(id) ON DELETE CASCADE,  -- NULL = org-wide
  name        TEXT NOT NULL,
  slug        TEXT NOT NULL,
  description TEXT,
  icon        TEXT,
  visibility  TEXT NOT NULL DEFAULT 'members',  -- 'members' | 'public'
  created_by  UUID NOT NULL REFERENCES users(id),
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (org_id, slug)
)

wiki_pages (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  space_id    UUID NOT NULL REFERENCES wiki_spaces(id) ON DELETE CASCADE,
  parent_id   UUID REFERENCES wiki_pages(id) ON DELETE SET NULL,
  title       TEXT NOT NULL,
  slug        TEXT NOT NULL,
  content     JSONB NOT NULL DEFAULT '{}',
  order_index INT NOT NULL DEFAULT 0,
  status      TEXT NOT NULL DEFAULT 'draft',  -- 'draft' | 'published'
  emoji       TEXT,
  version     INT NOT NULL DEFAULT 1,
  created_by  UUID NOT NULL REFERENCES users(id),
  updated_by  UUID REFERENCES users(id),
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now(),
  deleted_at  TIMESTAMPTZ,
  UNIQUE (space_id, parent_id, slug)
)

wiki_page_versions (
  id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  page_id  UUID NOT NULL REFERENCES wiki_pages(id) ON DELETE CASCADE,
  version  INT NOT NULL,
  title    TEXT NOT NULL,
  content  JSONB NOT NULL,
  saved_by UUID NOT NULL REFERENCES users(id),
  saved_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (page_id, version)
)

wiki_comments (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  page_id    UUID NOT NULL REFERENCES wiki_pages(id) ON DELETE CASCADE,
  parent_id  UUID REFERENCES wiki_comments(id) ON DELETE CASCADE,
  author_id  UUID NOT NULL REFERENCES users(id),
  content    TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  deleted_at TIMESTAMPTZ
)

wiki_templates (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id      UUID REFERENCES organizations(id) ON DELETE CASCADE,  -- NULL = platform-wide
  name        TEXT NOT NULL,
  description TEXT,
  content     JSONB NOT NULL,
  created_by  UUID REFERENCES users(id),
  created_at  TIMESTAMPTZ DEFAULT now()
)
```
