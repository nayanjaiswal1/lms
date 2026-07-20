---
kind: lesson
id_key: java-mastery/control-flow/loops
course: java-mastery
section: control-flow
section_title: "Control Flow"
section_position: 2
title: "Loops: for, while, do-while, and for-each"
position: 2
estimated_minutes: 25
source: [java-mastery-curriculum.md]
---
Loops repeat a block of code without you writing it out N times. Java has four loop forms, each suited to a different shape of problem: counting through indices, repeating while a condition holds, guaranteeing at least one run, and walking every element of a collection.

## The classic for loop

```java
public class Main {
    public static void main(String[] args) {
        String[] taskNames = { "Design schema", "Build API", "Write tests", "Deploy" };

        for (int i = 0; i < taskNames.length; i++) {
            System.out.println((i + 1) + ". " + taskNames[i]);
        }
    }
}
```

A `for` loop has three parts separated by `;`: **initialization** (`int i = 0`, runs once), **condition** (`i < taskNames.length`, checked before every iteration), and **update** (`i++`, runs after every iteration). It's the natural choice when you need the index itself — here, to number each task — not just each value. `taskNames.length` is a field (no parentheses) on the array, giving its size.

## while: repeat until a condition fails

```java
public class Main {
    public static void main(String[] args) {
        int tasksRemaining = 5;

        while (tasksRemaining > 0) {
            System.out.println("Processing task, " + tasksRemaining + " remaining");
            tasksRemaining--;
        }

        System.out.println("Queue empty");
    }
}
```

`while` checks its condition **before** each iteration, including the first — if `tasksRemaining` started at `0`, the loop body would never run at all. Use `while` when the number of iterations isn't known up front and depends on something changing inside the loop, like draining a queue.

## do-while: guaranteed at least one run

```java
public class Main {
    public static void main(String[] args) {
        int attempt = 1;
        boolean connected = false;

        do {
            System.out.println("Connection attempt " + attempt);
            connected = attempt >= 3; // simulate success on the 3rd try
            attempt++;
        } while (!connected);

        System.out.println("Connected after " + (attempt - 1) + " attempt(s)");
    }
}
```

`do-while` checks its condition **after** the body runs, so the body always executes at least once — exactly right for "try something, then keep retrying until it succeeds," like a connection attempt where you need to try before you have anything to check.

## Enhanced for-each

```java
public class Main {
    public static void main(String[] args) {
        String[] taskNames = { "Design schema", "Build API", "Write tests" };

        for (String taskName : taskNames) {
            System.out.println("Task: " + taskName);
        }
    }
}
```

The for-each loop (`for (Type element : collection)`) reads "for each `taskName` in `taskNames`" and hands you each element directly — no index bookkeeping, no risk of an off-by-one `ArrayIndexOutOfBoundsException`. Use it whenever you need every element and don't need the index; fall back to the classic `for` when you do need the index (to number items, skip every other one, or walk backwards).

## Choosing between them

| Loop | Use when |
|---|---|
| `for` | You need an index, or a known number of iterations |
| `while` | The stopping condition depends on something checked *before* each run, iteration count unknown |
| `do-while` | The body must run at least once no matter what |
| for-each | You just need every element, in order, and don't need the index |

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "control-flow-loops-q1",
      "type": "mcq",
      "prompt": "If tasksRemaining starts at 0, how many times does `while (tasksRemaining > 0) { ... }` run its body?",
      "options": [
        { "id": "a", "text": "Exactly once" },
        { "id": "b", "text": "Zero times — while checks the condition before the first iteration" },
        { "id": "c", "text": "It causes a compile error" },
        { "id": "d", "text": "It runs forever" }
      ],
      "correct": "b",
      "explanation": "while evaluates its condition before every iteration, including the first. If the condition is already false, the body never runs at all — this is the key difference from do-while."
    },
    {
      "id": "control-flow-loops-q2",
      "type": "mcq",
      "prompt": "What guarantee does a do-while loop provide that a while loop does not?",
      "options": [
        { "id": "a", "text": "It runs faster" },
        { "id": "b", "text": "The loop body executes at least once, since the condition is checked after the body runs" },
        { "id": "c", "text": "It can only be used with arrays" },
        { "id": "d", "text": "It never needs a stopping condition" }
      ],
      "correct": "b",
      "explanation": "do-while runs the body first and checks the condition afterward, so the body is guaranteed to run at least one time regardless of the condition's initial value."
    },
    {
      "id": "control-flow-loops-q3",
      "type": "mcq",
      "prompt": "Why might you choose a classic for loop over a for-each loop when iterating an array of task names?",
      "options": [
        { "id": "a", "text": "for-each cannot iterate arrays, only collections" },
        { "id": "b", "text": "You need the index — for example, to number each task in the output" },
        { "id": "c", "text": "Classic for loops are always faster" },
        { "id": "d", "text": "for-each requires the array to be sorted first" }
      ],
      "correct": "b",
      "explanation": "for-each gives you each element but not its position. When you need the index — numbering items, skipping alternating entries, iterating backwards — the classic for loop's explicit index is what you need."
    }
  ]
}
```

## What's next

The last lesson in this module covers `break`, `continue`, and **labeled** loops — how to exit early, skip an iteration, and control nested loops precisely when scanning through TaskFlow's tasks grouped by project.
