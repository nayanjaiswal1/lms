---
kind: lesson
id_key: java-mastery/jdbc/connection-pooling-and-injection-recap
course: java-mastery
section: jdbc
section_title: "JDBC"
section_position: 13
title: "Connection Pooling & Why These Practices Are Non-Negotiable"
position: 2
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
The previous two lessons covered the mechanics: `Connection` → `PreparedStatement` → `ResultSet`, and why parameterized queries prevent SQL injection. This lesson ties them together with the one piece still missing — what happens when TaskFlow needs to serve *many* concurrent requests, each needing a database connection — and makes the case for why none of this is optional polish.

**Note:** like the previous two JDBC lessons, the code in this lesson describes the pattern you'd write in a real application connected to a real database. It isn't runnable in this course's sandboxed code boxes, which don't have a live database attached.

## Why `DriverManager.getConnection` per request doesn't scale

Opening a raw TCP connection to a database, authenticating, and negotiating a session is *expensive* — tens of milliseconds, sometimes more. If TaskFlow's web server opens a brand-new `Connection` for every incoming HTTP request and closes it when the request finishes, every single request pays that setup cost:

```java
// Naive — opens and tears down a full DB connection on every call.
// Fine for a one-off script, disastrous under real concurrent load.
public Task findTask(String taskId) throws SQLException {
    try (Connection conn = DriverManager.getConnection(DB_URL, USER, PASS);
         PreparedStatement stmt = conn.prepareStatement(
             "SELECT id, name, estimate_hours FROM tasks WHERE id = ?")) {
        stmt.setString(1, taskId);
        try (ResultSet rs = stmt.executeQuery()) {
            if (rs.next()) {
                return new Task(rs.getString("id"), rs.getString("name"), rs.getInt("estimate_hours"));
            }
            return null;
        }
    }
}
```

Under light load this "works." Under real traffic — dozens of concurrent TaskFlow users hitting the API — the connection-setup overhead alone can dominate response time, and most databases also cap the number of simultaneous connections they'll accept, so a burst of traffic can simply start failing to connect at all.

## Connection pooling

A **connection pool** (HikariCP is the de facto standard in the Java ecosystem) opens a fixed number of connections once, up front, and hands them out to application code on request — "borrow a connection, use it, give it back" instead of "open a connection, use it, close it forever." The pool keeps connections warm and reuses them:

```java
// Shape of pooled access — HikariCP is configured once at application startup:
//
// HikariConfig config = new HikariConfig();
// config.setJdbcUrl(DB_URL);
// config.setUsername(USER);
// config.setPassword(PASS);
// config.setMaximumPoolSize(10);
// HikariDataSource dataSource = new HikariDataSource(config);
//
// Application code then borrows a Connection from the pool instead of
// DriverManager — everything downstream (PreparedStatement, ResultSet,
// try-with-resources) looks identical to before:
public Task findTask(DataSource dataSource, String taskId) throws SQLException {
    try (Connection conn = dataSource.getConnection(); // borrowed from the pool, not freshly opened
         PreparedStatement stmt = conn.prepareStatement(
             "SELECT id, name, estimate_hours FROM tasks WHERE id = ?")) {
        stmt.setString(1, taskId);
        try (ResultSet rs = stmt.executeQuery()) {
            return rs.next()
                ? new Task(rs.getString("id"), rs.getString("name"), rs.getInt("estimate_hours"))
                : null;
        }
    }
}
```

The crucial detail: **`conn.close()` inside a pooled `try-with-resources` doesn't actually close the underlying TCP connection** — the pool intercepts it and returns the connection to the pool for reuse. Application code doesn't need to know or care that pooling is happening; it still opens and "closes" a `Connection` per unit of work, exactly like the unpooled version. The pool is configured once, centrally, at application startup.

## Sizing a pool

A pool's `maximumPoolSize` isn't "as high as possible" — each pooled connection holds real resources on both the application and database side, and a database has its own hard connection limit shared across every application instance talking to it. A common starting formula (from HikariCP's own guidance) is roughly `connections = ((core_count * 2) + effective_spindle_count)` for the database server, then dividing that budget across however many application instances connect to it — the exact number matters less here than the principle: **pool size is a deliberately tuned, finite resource, not an unlimited convenience**.

## Why PreparedStatement + pooling are both "day one," not later

It's tempting to treat parameterized queries and connection pooling as things you "add later once the app needs to scale." Both are cheap to do correctly from the start and expensive to retrofit:

- **PreparedStatement** costs nothing extra to use over string-concatenated SQL — the syntax is barely different — but retrofitting it into a codebase already full of string-built queries means re-auditing every single query for injection risk, one at a time, under time pressure, usually only after a security review flags it.
- **Connection pooling** is a few lines of setup at application startup. Retrofitting it into a codebase full of scattered `DriverManager.getConnection()` calls means finding and rewriting every one of them, plus debugging whatever connection-exhaustion incidents happened before someone noticed the pattern didn't scale.

Both are the same shape of decision: cheap now, expensive later, and neither one is "premature optimization" — they're baseline correctness and baseline scalability for anything beyond a throwaway script.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "jdbc-connection-pooling-and-injection-recap-q1",
      "type": "mcq",
      "prompt": "Why is calling DriverManager.getConnection() for every incoming request a problem under real traffic?",
      "options": [
        { "id": "a", "text": "It's actually fine at any scale — this is a myth" },
        { "id": "b", "text": "Opening a fresh database connection is expensive (setup + auth), and most databases also cap total simultaneous connections" },
        { "id": "c", "text": "DriverManager can only be called once per application" },
        { "id": "d", "text": "It causes a compile error under concurrent load" }
      ],
      "correct": "b",
      "explanation": "Each new connection pays real setup cost, and databases enforce a maximum connection count — under concurrent traffic, per-request connections both slow every request down and risk hitting that cap."
    },
    {
      "id": "jdbc-connection-pooling-and-injection-recap-q2",
      "type": "mcq",
      "prompt": "When code using a pooled DataSource calls conn.close() inside a try-with-resources block, what actually happens?",
      "options": [
        { "id": "a", "text": "The underlying TCP connection is torn down immediately, same as an unpooled connection" },
        { "id": "b", "text": "Nothing — close() is silently ignored for pooled connections" },
        { "id": "c", "text": "The pool intercepts the call and returns the connection to the pool for reuse, rather than closing it" },
        { "id": "d", "text": "It throws an exception, since pooled connections cannot be closed" }
      ],
      "correct": "c",
      "explanation": "Pooled connections implement close() to mean \"return to the pool,\" not \"disconnect.\" Application code keeps using the same try-with-resources pattern; the pooling behavior is transparent to it."
    },
    {
      "id": "jdbc-connection-pooling-and-injection-recap-q3",
      "type": "mcq",
      "prompt": "Why are PreparedStatement and connection pooling both described as 'day one' practices rather than later optimizations?",
      "options": [
        { "id": "a", "text": "Because Java requires them by law for any database code to compile" },
        { "id": "b", "text": "Because both are cheap to adopt from the start but expensive to retrofit across an entire existing codebase later" },
        { "id": "c", "text": "Because they only matter for applications with more than one million users" },
        { "id": "d", "text": "Neither actually matters in practice — this is overcaution" }
      ],
      "correct": "b",
      "explanation": "Both cost almost nothing to build in from the start. Retrofitting them means auditing or rewriting every existing call site later, usually under pressure after an incident — the same class of tradeoff as most 'do it right the first time' engineering advice."
    }
  ]
}
```

## What's next

That closes out JDBC and database access. The next module, **Design Patterns**, moves from data access back to structuring the code itself — recurring, named solutions to recurring design problems, several of which you've already used informally earlier in this course without naming them.
