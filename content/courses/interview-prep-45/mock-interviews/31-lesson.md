---
kind: lesson
id_key: interview-prep-45/day-31
course: interview-prep-45
section: mock-interviews
section_title: "Mock Interviews"
section_position: 7
title: "Mock Interviews 4–6: Graphs, Twitter, Todo App"
position: 31
estimated_minutes: 240
source:
    - 45-day-interview-roadmap.md
---

Three mocks, run cold, one after another, timers running the whole way. Say your reasoning out loud even when it feels obvious — an interviewer can't grade a silent thought. No reference solutions until you've submitted or the clock hits zero.

## Run of show

| Time | Segment |
|---|---|
| 0:00–0:30 | Mock 4: DSA — Number of Islands, BFS + DFS (30 min) |
| 0:30–0:40 | Break |
| 0:40–1:20 | Mock 5: System Design — Design Twitter (40 min) |
| 1:20–1:30 | Break |
| 1:30–2:00 | Mock 6: Frontend — Todo App with CRUD + persistence (30 min) |
| 2:00–2:20 | Score against rubric, write debrief |
| 2:20–2:50 | Extra practice: Clone Graph, Pacific Atlantic Water Flow, Walls and Gates (pick one, 30 min) |
| 2:50–4:00 | Buffer — re-run your weakest segment cold |

## Mock Interview 4: DSA — Number of Islands (30 minutes)

**Problem:** [Number of Islands (LeetCode 200)](https://leetcode.com/problems/number-of-islands/). Given an `m x n` 2D binary grid representing `'1'` (land) and `'0'` (water), return the number of islands — an island is surrounded by water and formed by connecting adjacent lands horizontally or vertically.

```
Input:
[["1","1","0","0","0"],
 ["1","1","0","0","0"],
 ["0","0","1","0","0"],
 ["0","0","0","1","1"]]
Output: 3
```

**Instructions:** solve it with BFS first, then again with DFS, and compare the two out loud — this is the whole point of the exercise, not just getting one answer.

**Clarifying hints:**
- "Diagonal adjacency counts?" — No, only up/down/left/right.
- "Can the grid be empty?" — Yes, return 0.
- "Can we mutate the input grid?" — Ask; if not, you need a separate `visited` set.

#### Reference solution

```python
from collections import deque

def num_islands_dfs(grid: list[list[str]]) -> int:
    if not grid:
        return 0
    rows, cols = len(grid), len(grid[0])

    def dfs(r: int, c: int) -> None:
        if r < 0 or r >= rows or c < 0 or c >= cols or grid[r][c] != "1":
            return
        grid[r][c] = "0"  # mark visited by sinking the island
        dfs(r + 1, c)
        dfs(r - 1, c)
        dfs(r, c + 1)
        dfs(r, c - 1)

    count = 0
    for r in range(rows):
        for c in range(cols):
            if grid[r][c] == "1":
                count += 1
                dfs(r, c)
    return count


def num_islands_bfs(grid: list[list[str]]) -> int:
    if not grid:
        return 0
    rows, cols = len(grid), len(grid[0])
    count = 0
    for r in range(rows):
        for c in range(cols):
            if grid[r][c] != "1":
                continue
            count += 1
            queue = deque([(r, c)])
            grid[r][c] = "0"
            while queue:
                cr, cc = queue.popleft()
                for nr, nc in ((cr + 1, cc), (cr - 1, cc), (cr, cc + 1), (cr, cc - 1)):
                    if 0 <= nr < rows and 0 <= nc < cols and grid[nr][nc] == "1":
                        grid[nr][nc] = "0"
                        queue.append((nr, nc))
    return count


if __name__ == "__main__":
    g1 = [list(r) for r in ["11000", "11000", "00100", "00011"]]
    g2 = [list(r) for r in ["11000", "11000", "00100", "00011"]]
    assert num_islands_dfs(g1) == 3
    assert num_islands_bfs(g2) == 3
    print("ok")
```

**BFS vs DFS comparison to state out loud:** both are O(rows × cols) time and O(rows × cols) worst-case space (grid of all land). DFS is simpler to write (fewer lines, natural recursion) but risks a stack overflow on huge grids since Python's recursion limit is finite — mention you'd convert to an explicit stack for production code on unbounded input. BFS avoids that risk and its space is bounded by the frontier size rather than the call stack, at the cost of slightly more bookkeeping (the queue). In an interview, leading with DFS for speed of writing, then noting BFS as the safer choice for large/unbounded grids, is the strongest answer.

**Extra practice — Clone Graph, Pacific Atlantic Water Flow, Walls and Gates.** All three are BFS/DFS-on-a-graph variants; treat them as reps for pattern recognition rather than full mocks. Pick one for the buffer block at the end of today, solve it cold in 25 minutes, and check the pattern: Clone Graph is DFS/BFS with a visited-map to avoid infinite recursion on cycles; Pacific Atlantic is multi-source BFS/DFS starting from both ocean borders inward; Walls and Gates is multi-source BFS starting from every gate simultaneously.

## Mock Interview 5: System Design — Design Twitter (40 minutes)

**Prompt:** "Design a system like Twitter — users post short messages, follow other users, and see a feed of posts from people they follow."

**Instructions:** set a 40-minute timer. Focus specifically on feed generation — that's where the interesting trade-offs live — and discuss trade-offs between approaches rather than settling on the first idea.

**Clarifying questions to ask:**
- Feed = strictly reverse-chronological from people you follow, or ranked/algorithmic?
- Typical follower count distribution — mostly small, or do celebrities with millions of followers exist?
- Read vs write ratio for the timeline?
- Do we need to support retweets/likes/replies, or just the core post+follow+feed loop?

### Reference solution

**Functional requirements:** post a tweet, follow/unfollow, view home timeline (posts from followed users, reverse chronological).
**Non-functional requirements:** low read latency on timeline load, high write throughput at peak, eventual consistency acceptable (a tweet appearing a few seconds late in a follower's feed is fine).

**The core design question — fan-out on write vs fan-out on read:**

*Fan-out on write (push):* when a user posts, immediately write that post into the precomputed timeline (a list/cache) of every follower. Reading a timeline is then just "read my precomputed list" — O(1) fast reads. Problem: a celebrity with 50M followers triggers 50M writes for a single tweet — the "celebrity problem."

*Fan-out on read (pull):* store each user's own posts only. To build a timeline, query the posts of everyone you follow at read time and merge-sort by timestamp. Cheap writes, expensive reads (fan-in across potentially hundreds of followed accounts every time you open the app).

**The real-world hybrid (state this explicitly, it's the expected answer):** fan-out on write for regular users (few followers, so cheap), fan-out on read for celebrity accounts (too many followers to push to). When building a timeline, merge the precomputed feed (from push) with a live query against the small number of celebrities you follow (pull), combined and sorted at read time.

**High-level architecture:**
```
Client -> API layer -> Post service -> Post store (tweets, by author)
                     -> Fan-out service -> Timeline cache (Redis, per-user list of post IDs)
                     -> Timeline read service -> merges cached feed + live celebrity posts
                     -> Follow graph service -> Follow store (who follows whom)
```

**Data model:**
```sql
CREATE TABLE tweets (
    id BIGINT PRIMARY KEY,           -- Snowflake ID, sortable by time
    author_id BIGINT NOT NULL,
    body VARCHAR(280) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);
CREATE TABLE follows (
    follower_id BIGINT NOT NULL,
    followee_id BIGINT NOT NULL,
    PRIMARY KEY (follower_id, followee_id)
);
```
Timeline cache: Redis sorted set per user, `ZADD timeline:{user_id} {timestamp} {tweet_id}`, capped to the most recent ~800 entries (nobody scrolls past that in one session; trim on write to keep memory bounded).

**Write path (regular user posts):** write tweet to `tweets` table → fan-out service looks up followers from the follow graph → for each follower, `ZADD` the tweet ID into their Redis timeline. Do this asynchronously via a queue (Kafka), not synchronously in the request path, so posting doesn't block on however many followers the user has.

**Write path (celebrity posts, >some threshold like 1M followers):** skip fan-out entirely. Just write to `tweets`. Mark the account as "celebrity" so the read path knows to pull it live.

**Read path:** fetch the user's precomputed Redis timeline (fast), separately fetch recent posts from any celebrities they follow (small list, cheap live query), merge-sort the two by timestamp, return top N.

**Scaling notes:** the follow graph itself needs to scale — a celebrity's follower list (50M rows) must support fast "get all followers" for fan-out; shard by `followee_id`. The fan-out queue needs backpressure handling — if fan-out falls behind during a viral moment, followers just see the tweet a bit later, which is an acceptable degradation given the non-functional requirement of eventual consistency.

**Trade-off to name explicitly when asked "why not just always pull":** pure pull is simpler to build and has no celebrity problem, but it means every timeline load does a fan-in query across potentially hundreds of followed users — that's the latency cost regular Twitter's read-heavy traffic pattern can't tolerate at scale, which is why the hybrid exists.

## Mock Interview 6: Frontend — Todo App (30 minutes)

**Prompt:** "Build a Todo application: add, edit, delete, and toggle-complete tasks, with data that survives a page refresh."

**Instructions:** 30-minute timer. Include all CRUD operations, add persistence, and style it properly — don't ship an unstyled list of `<li>` tags.

**Clarifying hints:**
- "Persistence — backend API or client-side only?" — For this mock, client-side (localStorage) is acceptable and faster to demonstrate the full loop in 30 minutes; say you'd swap it for a REST API + optimistic updates given more time.
- "Should completed todos be distinguishable?" — Yes, visually (strikethrough/dimmed) and filterable.

### Reference solution

```tsx
import { useState, useEffect, useCallback } from "react";

interface Todo {
  id: string;
  text: string;
  completed: boolean;
}

const STORAGE_KEY = "todos";

function loadTodos(): Todo[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? (JSON.parse(raw) as Todo[]) : [];
  } catch {
    return [];
  }
}

export function TodoApp() {
  const [todos, setTodos] = useState<Todo[]>(loadTodos);
  const [draft, setDraft] = useState("");
  const [filter, setFilter] = useState<"all" | "active" | "completed">("all");

  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(todos));
  }, [todos]);

  const addTodo = useCallback(() => {
    const text = draft.trim();
    if (!text) return;
    setTodos((prev) => [...prev, { id: crypto.randomUUID(), text, completed: false }]);
    setDraft("");
  }, [draft]);

  const toggleTodo = useCallback((id: string) => {
    setTodos((prev) => prev.map((t) => (t.id === id ? { ...t, completed: !t.completed } : t)));
  }, []);

  const deleteTodo = useCallback((id: string) => {
    setTodos((prev) => prev.filter((t) => t.id !== id));
  }, []);

  const editTodo = useCallback((id: string, text: string) => {
    setTodos((prev) => prev.map((t) => (t.id === id ? { ...t, text } : t)));
  }, []);

  const visible = todos.filter((t) =>
    filter === "all" ? true : filter === "active" ? !t.completed : t.completed
  );

  return (
    <div className="todo-app">
      <h1>Todos</h1>
      <div className="todo-input-row">
        <input
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && addTodo()}
          placeholder="What needs doing?"
          aria-label="New todo"
        />
        <button onClick={addTodo}>Add</button>
      </div>

      <div className="todo-filters" role="tablist">
        {(["all", "active", "completed"] as const).map((f) => (
          <button
            key={f}
            role="tab"
            aria-selected={filter === f}
            onClick={() => setFilter(f)}
            className={filter === f ? "active" : ""}
          >
            {f}
          </button>
        ))}
      </div>

      <ul className="todo-list">
        {visible.map((todo) => (
          <TodoRow
            key={todo.id}
            todo={todo}
            onToggle={() => toggleTodo(todo.id)}
            onDelete={() => deleteTodo(todo.id)}
            onEdit={(text) => editTodo(todo.id, text)}
          />
        ))}
        {visible.length === 0 && <li className="empty">Nothing here.</li>}
      </ul>
    </div>
  );
}

function TodoRow({
  todo,
  onToggle,
  onDelete,
  onEdit,
}: {
  todo: Todo;
  onToggle: () => void;
  onDelete: () => void;
  onEdit: (text: string) => void;
}) {
  const [editing, setEditing] = useState(false);
  const [text, setText] = useState(todo.text);

  const commit = () => {
    const trimmed = text.trim();
    if (trimmed) onEdit(trimmed);
    setEditing(false);
  };

  return (
    <li className={todo.completed ? "completed" : ""}>
      <input type="checkbox" checked={todo.completed} onChange={onToggle} aria-label={`Mark ${todo.text} complete`} />
      {editing ? (
        <input
          value={text}
          autoFocus
          onChange={(e) => setText(e.target.value)}
          onBlur={commit}
          onKeyDown={(e) => e.key === "Enter" && commit()}
        />
      ) : (
        <span onDoubleClick={() => setEditing(true)}>{todo.text}</span>
      )}
      <button onClick={onDelete} aria-label={`Delete ${todo.text}`}>
        ×
      </button>
    </li>
  );
}
```

```css
.todo-app { max-width: 480px; margin: 2rem auto; font-family: system-ui, sans-serif; }
.todo-input-row { display: flex; gap: 0.5rem; margin-bottom: 1rem; }
.todo-input-row input { flex: 1; padding: 0.5rem; border: 1px solid #ccc; border-radius: 4px; }
.todo-filters { display: flex; gap: 0.5rem; margin-bottom: 1rem; }
.todo-filters button.active { font-weight: 600; text-decoration: underline; }
.todo-list { list-style: none; padding: 0; }
.todo-list li { display: flex; align-items: center; gap: 0.5rem; padding: 0.5rem 0; border-bottom: 1px solid #eee; }
.todo-list li.completed span { text-decoration: line-through; color: #999; }
.empty { color: #999; font-style: italic; }
```

**Why these choices:** state lives in one `todos` array (single source of truth) rather than scattered per-row state, which keeps persistence trivial — one `useEffect` on `todos` syncing to `localStorage` covers every mutation. `crypto.randomUUID()` avoids array-index keys, which break identity when items are deleted or reordered. Inline editing toggles a local `editing` flag per row rather than lifting edit-mode into the parent, keeping the parent's re-render surface small. This is a CRUD demo, not production: given more time, swap `localStorage` for a REST API with optimistic updates and rollback-on-error, and add debounced autosave for the edit field instead of committing only on blur/Enter.

## Scoring rubric

**Mock 4 — DSA (Number of Islands)**
- Solved correctly with both BFS and DFS: /5
- Compared the two approaches' trade-offs (recursion depth risk, space characteristics) unprompted: /5
- Handled edge cases (empty grid, all water, all land): /5
- Code was clean in both versions: /5

**Mock 5 — System Design (Twitter)**
- Focused the design on feed generation as instructed, not just generic CRUD: /5
- Identified and explained the celebrity/fan-out problem: /5
- Proposed and justified the hybrid push/pull approach with real trade-offs: /5
- Data model and caching strategy were concrete, not hand-wavy: /5

**Mock 6 — Frontend (Todo App)**
- All CRUD operations implemented and working (add, edit, delete, toggle): /5
- Persistence survives a refresh: /5
- Component was styled properly, not bare HTML: /5
- Used correct React patterns (single source of truth, stable keys, no unnecessary state duplication): /5

## Debrief

After each mock, log the biggest gap immediately: what broke down, why (missed pattern recognition, ran out of time, didn't know the trade-off), and the specific fix. For the DSA extra-practice problem, note explicitly which pattern it was testing (multi-source BFS, cycle-safe DFS, etc.) so you can recognize the shape faster next time instead of re-deriving it from scratch. Anything scored 3/5 or below goes on tomorrow's warm-up.
