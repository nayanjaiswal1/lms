---
kind: lesson
id_key: java-mastery/jdbc/jdbc-basics-and-connection
course: java-mastery
section: jdbc
section_title: "JDBC"
section_position: 13
title: "JDBC Basics and Connection"
position: 0
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
Everything TaskFlow does eventually needs to persist somewhere — tasks, users, projects, teams all live in a relational database, not in memory. **JDBC** (Java Database Connectivity) is the standard Java API for talking to a relational database, and it's worth understanding even if you later use a higher-level tool on top of it, because those tools are almost always built on JDBC underneath.

A note before diving in: **this lesson's code examples describe the JDBC pattern rather than being runnable against a real database in this sandbox.** Every other module in this course runs your code for real against a live JDK — this module is the one exception, because connecting to an actual PostgreSQL or MySQL instance isn't available here. Read these as accurate, realistic Java you'd write in a real TaskFlow backend, not as something to hit Run on and expect output from.

## JDBC is a standard API, not a database

JDBC itself is just a set of interfaces (`Connection`, `Statement`, `ResultSet`, and so on) defined in `java.sql`. Every actual database vendor (PostgreSQL, MySQL, Oracle, SQLite...) ships a **driver** — a concrete implementation of those interfaces that knows how to speak that specific database's wire protocol. Your application code is written against the JDBC interfaces, not against any particular driver, so swapping databases in theory means swapping the driver dependency, not rewriting your data-access code.

## The core flow: DriverManager → Connection → Statement → ResultSet → close

```java
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

public class Main {
    public static void main(String[] args) {
        // Illustrative only — requires a real database URL, username, and password to run.
        String url = "jdbc:postgresql://localhost:5432/taskflow";
        String username = "taskflow_app";
        String password = System.getenv("DB_PASSWORD");

        try (Connection connection = DriverManager.getConnection(url, username, password);
             Statement statement = connection.createStatement();
             ResultSet resultSet = statement.executeQuery(
                 "SELECT id, name, estimate_hours FROM tasks WHERE status = 'TODO'")) {

            while (resultSet.next()) {
                int id = resultSet.getInt("id");
                String name = resultSet.getString("name");
                int estimateHours = resultSet.getInt("estimate_hours");
                System.out.println(id + ": " + name + " (" + estimateHours + "h)");
            }
        } catch (SQLException e) {
            throw new RuntimeException("Failed to load TODO tasks", e);
        }
    }
}
```

Walking the flow that every JDBC program follows:

1. **`DriverManager.getConnection(url, username, password)`** opens a `Connection` — a live, stateful session with the database, identified by a JDBC URL (`jdbc:<database-type>://<host>:<port>/<database-name>`). Opening a connection is relatively expensive: it involves a real network handshake and authentication, which matters a lot once you get to connection pooling later in this module.
2. **`connection.createStatement()`** creates a `Statement`, the object you use to actually send SQL to the database.
3. **`statement.executeQuery(sql)`** runs a `SELECT` and returns a `ResultSet` — a cursor over the rows the query matched, not the rows themselves all loaded into memory at once.
4. **`while (resultSet.next())`** advances the cursor one row at a time; `resultSet.next()` returns `false` once there are no more rows, which is what ends the loop. Each `getXxx("column_name")` call reads one column's value from the *current* row.
5. **`try (...)`** — `Connection`, `Statement`, and `ResultSet` are all `AutoCloseable`, and try-with-resources (from the previous module) closes all three, in reverse order, whether the block finishes normally or throws. Every one of them holds a real, finite resource (a network connection, database-side cursor state) that must be released.

## Reading the username/password out of environment variables

Notice `password` in the example comes from `System.getenv("DB_PASSWORD")`, not a literal string in the source. Database credentials hardcoded into source code are both a security risk (anyone with source access has production credentials) and an operational headache (changing a password means redeploying code) — production JDBC code always reads connection details from configuration or environment variables, never from a string literal.

## Statement vs. PreparedStatement — a preview

The example above used a plain `Statement` with a fixed query string containing no user input, which is fine for a static query like this. The moment a query needs to include a value that came from outside your program — a task ID from a request, a search term a user typed — string-concatenating that value into SQL is a serious security hole. The next lesson covers `PreparedStatement`, which is what you should reach for whenever a query needs a parameter, and exactly why it closes that hole.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "jdbc-jdbc-basics-and-connection-q1",
      "type": "mcq",
      "prompt": "What is JDBC, precisely?",
      "options": [
        { "id": "a", "text": "A specific database product bundled with the JDK" },
        { "id": "b", "text": "A standard set of Java interfaces for relational database access, implemented by vendor-specific drivers for each actual database" },
        { "id": "c", "text": "A build tool for compiling database schemas" },
        { "id": "d", "text": "A replacement for SQL that doesn't require writing queries" }
      ],
      "correct": "b",
      "explanation": "JDBC defines interfaces like Connection, Statement, and ResultSet in java.sql. Each database vendor ships a driver implementing those interfaces against its own wire protocol, so application code targets the standard interfaces rather than a specific database."
    },
    {
      "id": "jdbc-jdbc-basics-and-connection-q2",
      "type": "mcq",
      "prompt": "What does resultSet.next() do inside a while loop reading query results?",
      "options": [
        { "id": "a", "text": "Loads the entire result set into a List and returns it" },
        { "id": "b", "text": "Advances the cursor to the next row, returning true if a row exists there and false once rows are exhausted, which is what ends the loop" },
        { "id": "c", "text": "Executes the next SQL statement in the file" },
        { "id": "d", "text": "Closes the ResultSet after reading the current row" }
      ],
      "correct": "b",
      "explanation": "ResultSet is a cursor, not a pre-loaded collection. next() moves it forward one row and returns whether a row is there; the getXxx(...) calls then read columns from whichever row the cursor currently points at."
    },
    {
      "id": "jdbc-jdbc-basics-and-connection-q3",
      "type": "mcq",
      "prompt": "Why does the example read the database password from System.getenv(\"DB_PASSWORD\") instead of a string literal?",
      "options": [
        { "id": "a", "text": "String literals cannot hold passwords in Java" },
        { "id": "b", "text": "Hardcoded credentials in source code are a security risk and force a redeploy any time the password changes; reading from the environment keeps secrets out of source and configurable per environment" },
        { "id": "c", "text": "getenv() is required by the JDBC specification" },
        { "id": "d", "text": "It has no real benefit over a literal, it's just convention" }
      ],
      "correct": "b",
      "explanation": "Credentials committed to source code are visible to anyone with repo access and can't be rotated without a code change. Reading them from environment variables or a secrets manager is standard production practice."
    }
  ]
}
```

## What's next

The next lesson covers `PreparedStatement` — parameterized queries that are both safer and, for repeated queries, more efficient than building SQL strings by hand.
