---
kind: lesson
id_key: java-mastery/jdbc/preparedstatement-and-resultset
course: java-mastery
section: jdbc
section_title: "JDBC"
section_position: 13
title: "PreparedStatement and ResultSet"
position: 1
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
As with the previous lesson, **these examples describe the JDBC pattern and would need a real database connection to actually execute** — treat them as accurate reference code, not something to run here.

The moment a query needs a value from outside your program — a task name a user typed, an ID from a request — how you build that query stops being a style choice and becomes a security decision. This lesson shows both ways side by side.

## The vulnerable version: string concatenation

```java
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

public class Main {
    // VULNERABLE — never write JDBC code like this.
    static void findTaskByNameUnsafe(Connection connection, String userSuppliedName) throws SQLException {
        String sql = "SELECT id, status FROM tasks WHERE name = '" + userSuppliedName + "'";

        try (Statement statement = connection.createStatement();
             ResultSet resultSet = statement.executeQuery(sql)) {
            while (resultSet.next()) {
                System.out.println(resultSet.getInt("id") + ": " + resultSet.getString("status"));
            }
        }
    }
}
```

If `userSuppliedName` is a normal task name like `"Design database schema"`, this works fine. But it's built by pasting *unvalidated, untrusted text* directly into a SQL string. A malicious value like:

```
' OR '1'='1
```

turns the query into `SELECT id, status FROM tasks WHERE name = '' OR '1'='1'` — a condition that's always true, returning every row in the table instead of matching a specific name. A more damaging payload could chain a second statement or extract data the caller was never supposed to see. This is **SQL injection**, and string-concatenated queries are exactly how it happens — the database has no way to tell "this is part of the SQL structure" apart from "this is a piece of untrusted data" once they've been mashed into one string.

## The safe version: PreparedStatement with `?` placeholders

```java
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

public class Main {
    // SAFE — the standard way to write any query that includes a variable value.
    static void findTaskByNameSafe(Connection connection, String userSuppliedName) throws SQLException {
        String sql = "SELECT id, status FROM tasks WHERE name = ?";

        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, userSuppliedName); // 1-indexed, not 0-indexed

            try (ResultSet resultSet = statement.executeQuery()) {
                while (resultSet.next()) {
                    System.out.println(resultSet.getInt("id") + ": " + resultSet.getString("status"));
                }
            }
        }
    }
}
```

The `?` is a **placeholder**, not text substitution. `connection.prepareStatement(sql)` sends the query's fixed structure to the database *first*, separately from any values; `statement.setString(1, userSuppliedName)` then binds a value into that placeholder as pure data, never as SQL syntax. Even a malicious value like `' OR '1'='1` gets treated as a literal string to search for — the database looks for a task literally named `' OR '1'='1`, finds nothing, and returns zero rows. There's no way for bound parameter data to alter the query's structure, because the structure was already fixed before any data was attached. Note the parameter index is **1-based**: `setString(1, ...)` sets the first `?` in the SQL, not the second.

## Multiple parameters, and the other setXxx methods

```java
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

public class Main {
    static void findTasksByStatusAndMinHours(
            Connection connection, String status, int minHours) throws SQLException {
        String sql = "SELECT id, name, estimate_hours FROM tasks WHERE status = ? AND estimate_hours >= ?";

        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, status);   // first ? — a String
            statement.setInt(2, minHours);    // second ? — an int

            try (ResultSet resultSet = statement.executeQuery()) {
                while (resultSet.next()) {
                    System.out.println(
                        resultSet.getString("name") + " — " + resultSet.getInt("estimate_hours") + "h");
                }
            }
        }
    }
}
```

Each `setXxx` method (`setString`, `setInt`, `setBoolean`, `setDate`, and so on) matches a Java type to the correct JDBC/SQL type binding for that placeholder position — using the right one matters both for correctness and so the driver sends the value in the format the database expects. `?` placeholders are numbered left to right through the SQL string, independent of which method is used to set each one.

## Inserts and updates with PreparedStatement

`PreparedStatement` isn't just for `SELECT` — the same parameterized approach applies to `INSERT` and `UPDATE`, using `executeUpdate()` instead of `executeQuery()` since those statements don't return a `ResultSet`:

```java
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;

public class Main {
    static int insertTask(Connection connection, String name, int estimateHours, String status) throws SQLException {
        String sql = "INSERT INTO tasks (name, estimate_hours, status) VALUES (?, ?, ?)";

        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, name);
            statement.setInt(2, estimateHours);
            statement.setString(3, status);
            return statement.executeUpdate(); // returns the number of rows affected
        }
    }
}
```

`executeUpdate()` returns the number of rows the statement affected (here, `1` for a successful single-row insert) rather than a `ResultSet` — a useful sanity check that the write actually happened as expected.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "jdbc-preparedstatement-and-resultset-q1",
      "type": "mcq",
      "prompt": "Why does building a query with string concatenation like \"... WHERE name = '\" + userInput + \"'\" allow SQL injection?",
      "options": [
        { "id": "a", "text": "It doesn't — this is only a risk with executeUpdate(), not executeQuery()" },
        { "id": "b", "text": "Once user-supplied text is pasted directly into the SQL string, the database can no longer distinguish the query's intended structure from attacker-controlled data — malicious input can alter the query's logic" },
        { "id": "c", "text": "String concatenation in Java always throws a SecurityException" },
        { "id": "d", "text": "It's only a risk if the value contains a semicolon" }
      ],
      "correct": "b",
      "explanation": "Concatenation merges structure and data into one string before the database ever sees it. A value like ' OR '1'='1 becomes part of the query's logic rather than a literal value to search for, which is exactly what SQL injection exploits."
    },
    {
      "id": "jdbc-preparedstatement-and-resultset-q2",
      "type": "mcq",
      "prompt": "How does PreparedStatement prevent the same kind of injection?",
      "options": [
        { "id": "a", "text": "It escapes single quotes in the SQL string before sending it" },
        { "id": "b", "text": "The query's fixed structure is sent to the database separately from bound parameter values, so a value like ' OR '1'='1 is always treated as literal data to search for, never as SQL syntax" },
        { "id": "c", "text": "It disallows any special characters in input, throwing an exception if found" },
        { "id": "d", "text": "It runs the query twice and compares results for tampering" }
      ],
      "correct": "b",
      "explanation": "prepareStatement sends the SQL shape first; setString/setInt then bind values into placeholders as pure data. Because the structure was already fixed before any value arrived, bound data can never change what the query does."
    },
    {
      "id": "jdbc-preparedstatement-and-resultset-q3",
      "type": "mcq",
      "prompt": "In statement.setString(1, value), what does the 1 refer to?",
      "options": [
        { "id": "a", "text": "The zero-based index of the first ? placeholder, so 1 actually refers to the second placeholder" },
        { "id": "b", "text": "The 1-based position of the ? placeholder in the SQL string being bound — the first ? is 1, not 0" },
        { "id": "c", "text": "The database connection number" },
        { "id": "d", "text": "The row number being updated" }
      ],
      "correct": "b",
      "explanation": "JDBC parameter indices are 1-based, not 0-based like most Java array/list indexing — a common source of off-by-one bugs for anyone used to 0-based indexing elsewhere in the language."
    }
  ]
}
```

## What's next

The final lesson in this module covers connection pooling and ties PreparedStatement's injection prevention together with why both are considered non-negotiable, day-one production practices.
