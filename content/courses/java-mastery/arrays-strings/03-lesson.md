---
kind: lesson
id_key: java-mastery/arrays-strings/string-methods
course: java-mastery
section: arrays-strings
section_title: "Arrays & Strings"
section_position: 5
title: "String Immutability & Common Methods"
position: 2
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
You've been using `String` since the first lesson without a formal introduction. It's time for one — because one property of `String` shapes almost every method it has: **Strings are immutable**. Once created, a `String`'s characters never change.

## Immutability: every "modification" makes a new String

```java
public class Main {
    public static void main(String[] args) {
        String taskName = "design database schema";
        String capitalized = taskName.toUpperCase();

        System.out.println("Original: " + taskName);       // unchanged!
        System.out.println("Capitalized: " + capitalized); // the new String
    }
}
```

`taskName.toUpperCase()` does not modify `taskName` in place — `String` has no method that could, because its internal character data can never change after construction. Instead, it **returns a brand-new `String`** with the transformed content. This trips up beginners constantly: `taskName.toUpperCase();` on its own line, with the result discarded, does nothing observable at all. You must capture the return value, as `capitalized` does above.

## Core inspection methods

```java
public class Main {
    public static void main(String[] args) {
        String taskName = "Build REST API";

        System.out.println("Length: " + taskName.length());               // 15
        System.out.println("Substring(0,5): " + taskName.substring(0, 5)); // "Build"
        System.out.println("Substring(6): " + taskName.substring(6));     // "REST API"
        System.out.println("Index of 'REST': " + taskName.indexOf("REST")); // 6
        System.out.println("Index of 'xyz': " + taskName.indexOf("xyz"));   // -1, not found
        System.out.println("Contains 'API': " + taskName.contains("API"));  // true
    }
}
```

`length()` is a **method** here (unlike an array's `.length` field — a common early mix-up). `substring(start, end)` returns characters from `start` up to but *not including* `end`; `substring(start)` alone runs to the end of the string. `indexOf` returns the character position of the first match, or `-1` if the substring isn't present — always check for `-1` before trusting the result as a real index.

## `equals()` vs. `==` for Strings

```java
public class Main {
    public static void main(String[] args) {
        String a = "Deploy to prod";
        String b = "Deploy to prod";
        String c = new String("Deploy to prod");

        System.out.println("a == b: " + (a == b));           // true (string pool)
        System.out.println("a == c: " + (a == c));           // false! different objects
        System.out.println("a.equals(c): " + a.equals(c));   // true — compares content
    }
}
```

`==` on `String` compares **object references** (are these the same object in memory?), not content. Two string literals with the same text often *do* end up `==` equal, because Java pools literal strings for reuse — but that's an implementation detail you should never rely on, especially once strings come from `new String(...)`, user input, file reads, or concatenation at runtime, where pooling doesn't apply. **Always use `.equals()` to compare String content.** This is one of the most common real-world Java bugs.

## Changing case, and splitting a tag string

```java
public class Main {
    public static void main(String[] args) {
        String tags = "backend,urgent,api";

        System.out.println("Upper: " + tags.toUpperCase());
        System.out.println("Lower: " + tags.toLowerCase());

        String[] tagList = tags.split(",");
        System.out.println("Tag count: " + tagList.length);
        for (String tag : tagList) {
            System.out.println("- " + tag);
        }
    }
}
```

`split(",")` cuts a `String` into a `String[]` wherever the given regex-delimiter appears — here, a comma-separated tag list becomes an array of individual tags, ready to loop over. This is exactly how TaskFlow would parse a raw `"backend,urgent,api"` field pulled from a form or a file into structured data.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "arrays-strings-string-methods-q1",
      "type": "mcq",
      "prompt": "After String s = \"hello\"; s.toUpperCase();, what is s?",
      "options": [
        { "id": "a", "text": "\"HELLO\" — toUpperCase() modifies s in place" },
        { "id": "b", "text": "\"hello\" — unchanged, because Strings are immutable and the return value was discarded" },
        { "id": "c", "text": "A compile error" },
        { "id": "d", "text": "null" }
      ],
      "correct": "b",
      "explanation": "String methods never mutate the original — they return a new String. Since the result of toUpperCase() wasn't assigned to anything here, s is still \"hello\"."
    },
    {
      "id": "arrays-strings-string-methods-q2",
      "type": "mcq",
      "prompt": "Why should you use .equals() instead of == to compare String content?",
      "options": [
        { "id": "a", "text": "== always throws an exception on Strings" },
        { "id": "b", "text": "== compares object references, and two Strings with equal content aren't always the same object (e.g. one built with new String(...))" },
        { "id": "c", "text": ".equals() is faster than ==" },
        { "id": "d", "text": "There's no difference; both check content identically" }
      ],
      "correct": "b",
      "explanation": "== checks whether two references point at the same object. String literals may be pooled and share a reference, but strings built at runtime (new String(...), concatenation, input) typically are not, so relying on == is unreliable — .equals() checks actual character content."
    },
    {
      "id": "arrays-strings-string-methods-q3",
      "type": "mcq",
      "prompt": "What does \"Build REST API\".indexOf(\"xyz\") return?",
      "options": [
        { "id": "a", "text": "0" },
        { "id": "b", "text": "-1" },
        { "id": "c", "text": "Throws an exception" },
        { "id": "d", "text": "null" }
      ],
      "correct": "b",
      "explanation": "indexOf returns -1, not an exception or null, when the substring isn't found. Code that calls indexOf must check for -1 before treating the result as a valid position."
    }
  ]
}
```

## What's next

`+`-concatenating Strings works fine for a line or two, but doing it repeatedly in a loop is quietly wasteful. The next lesson covers `StringBuilder` and proper string formatting for building up TaskFlow reports.
