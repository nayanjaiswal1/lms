---
kind: lesson
id_key: java-mastery/getting-started/operators
course: java-mastery
section: getting-started
section_title: "Getting Started"
section_position: 1
title: "Operators & Expressions"
position: 2
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
Operators combine variables and values into expressions. Java groups them into a few families you'll use constantly.

## Arithmetic operators

```java
public class Main {
    public static void main(String[] args) {
        int totalTasks = 17;
        int completedTasks = 5;

        int remaining = totalTasks - completedTasks;
        int doubledLoad = totalTasks * 2;
        int perDay = totalTasks / 3;      // integer division: truncates
        int leftover = totalTasks % 3;    // modulo: the remainder

        System.out.println("Remaining: " + remaining);
        System.out.println("Per day (int division): " + perDay);
        System.out.println("Leftover (modulo): " + leftover);
    }
}
```

**Integer division truncates** — `17 / 3` is `5`, not `5.666...`. If either operand is a `double`, the result is a `double`: `17.0 / 3` gives `5.666666666666667`. This is one of the most common early Java bugs — dividing two `int`s when you wanted a decimal result.

## Increment, decrement, and compound assignment

```java
public class Main {
    public static void main(String[] args) {
        int taskCount = 10;
        taskCount++;        // post-increment: taskCount is now 11
        taskCount += 5;      // compound assignment: taskCount is now 16
        taskCount -= 2;      // now 14

        int index = 0;
        int first = index++; // first = 0, then index becomes 1 (post-increment)
        int second = ++index; // index becomes 2, then second = 2 (pre-increment)

        System.out.println("taskCount: " + taskCount);
        System.out.println("first: " + first + ", second: " + second);
    }
}
```

`x++` (post) returns the value *before* incrementing; `++x` (pre) increments first, then returns the new value. When the result isn't used in the same expression — `taskCount++;` on its own line — the two behave identically.

## Comparison and logical operators

```java
public class Main {
    public static void main(String[] args) {
        int priority = 8;
        boolean isUrgent = priority >= 7;
        boolean isAssigned = true;

        boolean needsAttention = isUrgent && !isAssigned; // AND + NOT
        boolean showInDigest = isUrgent || priority == 10; // OR

        System.out.println("Needs attention: " + needsAttention);
        System.out.println("Show in digest: " + showInDigest);
    }
}
```

`==` compares primitive values directly. `&&` and `||` **short-circuit**: in `a && b`, if `a` is `false`, `b` is never evaluated at all — useful (and sometimes necessary) when `b` would otherwise throw, like `list != null && list.size() > 0`.

## String concatenation with `+`

```java
public class Main {
    public static void main(String[] args) {
        String taskName = "Deploy to prod";
        int hoursSpent = 3;

        // + concatenates when either operand is a String
        String summary = taskName + " took " + hoursSpent + " hours";
        System.out.println(summary);

        // Order matters! Left-to-right evaluation:
        System.out.println("Total: " + 1 + 2);   // "Total: 12" — string concat both times
        System.out.println("Total: " + (1 + 2)); // "Total: 3"  — parens force numeric addition first
    }
}
```

Once `+` sees a `String` on either side, everything to its right is concatenated as text, left to right — `1 + 2` inside `"Total: " + 1 + 2` never gets a chance to run as arithmetic, because `"Total: " + 1` already produced a `String`.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "getting-started-operators-q1",
      "type": "mcq",
      "prompt": "What does 17 / 3 evaluate to when both operands are int?",
      "options": [
        { "id": "a", "text": "5.67" },
        { "id": "b", "text": "5" },
        { "id": "c", "text": "6" },
        { "id": "d", "text": "A compile error" }
      ],
      "correct": "b",
      "explanation": "Integer division truncates toward zero and discards the remainder — 17 / 3 is 5. Use 17.0 / 3 or cast an operand to double to get a decimal result."
    },
    {
      "id": "getting-started-operators-q2",
      "type": "mcq",
      "prompt": "What does \"Total: \" + 1 + 2 print?",
      "options": [
        { "id": "a", "text": "Total: 3" },
        { "id": "b", "text": "Total: 12" },
        { "id": "c", "text": "3Total: " },
        { "id": "d", "text": "A compile error" }
      ],
      "correct": "b",
      "explanation": "+ is evaluated left to right. \"Total: \" + 1 produces the String \"Total: 1\" first, and appending 2 to a String concatenates rather than adds, giving \"Total: 12\"."
    },
    {
      "id": "getting-started-operators-q3",
      "type": "mcq",
      "prompt": "In `a && b`, if a evaluates to false, what happens to b?",
      "options": [
        { "id": "a", "text": "b is always evaluated regardless" },
        { "id": "b", "text": "b is never evaluated — && short-circuits" },
        { "id": "c", "text": "It causes a compile error" },
        { "id": "d", "text": "b is evaluated but its result is discarded" }
      ],
      "correct": "b",
      "explanation": "&& and || short-circuit: once the overall result is determined by the left operand, the right operand is skipped entirely — this is why `list != null && list.size() > 0` is safe."
    }
  ]
}
```

## What's next

The last lesson in this module puts everything together: reading input from the user with `Scanner`, so TaskFlow can respond to something other than hardcoded values.
