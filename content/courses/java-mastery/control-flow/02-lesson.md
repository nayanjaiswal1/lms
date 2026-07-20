---
kind: lesson
id_key: java-mastery/control-flow/switch
course: java-mastery
section: control-flow
section_title: "Control Flow"
section_position: 2
title: "switch: Classic and Arrow Form"
position: 1
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
`switch` picks a branch based on matching a single value against a list of candidates. It has two forms in modern Java: the original **classic** form (fall-through, `break`), and the **arrow** form added in Java 14, which is safer by default and can produce a value directly.

## Classic switch

```java
public class Main {
    public static void main(String[] args) {
        String status = "REVIEW";
        String label;

        switch (status) {
            case "TODO":
            case "REVIEW":
                label = "Not started work";
                break;
            case "IN_PROGRESS":
                label = "Active work";
                break;
            case "DONE":
                label = "Complete";
                break;
            default:
                label = "Unknown status";
        }

        System.out.println(label);
    }
}
```

Stacking `case "TODO":` directly above `case "REVIEW":` with no code between them is a deliberate idiom: both labels fall into the same body. `break` exits the `switch` once a matching case has run — without it, execution **falls through** into the next case's code, regardless of whether that case's label matches.

## Fall-through, on purpose and by accident

```java
public class Main {
    public static void main(String[] args) {
        int priority = 3; // 1 = low, 2 = medium, 3 = high

        switch (priority) {
            case 3:
                System.out.println("Notify team lead");
                // intentional fall-through: a high-priority task also gets
                // the normal assignee notification below
            case 2:
                System.out.println("Notify assignee");
                break;
            case 1:
                System.out.println("Add to backlog digest");
                break;
            default:
                System.out.println("Unknown priority");
        }
    }
}
```

For `priority = 3`, this prints **both** "Notify team lead" and "Notify assignee" — execution enters `case 3`, finds no `break`, and keeps running straight into `case 2`'s body. That's a real, occasionally useful pattern (as here), but it's also the single most common `switch` bug: forgetting a `break` and silently running code you didn't mean to run. This is exactly the footgun the arrow form was designed to eliminate.

## The arrow form

```java
public class Main {
    public static void main(String[] args) {
        String status = "IN_PROGRESS";

        String label = switch (status) {
            case "TODO" -> "Not started";
            case "IN_PROGRESS" -> "Active";
            case "DONE" -> "Complete";
            default -> "Unknown";
        };

        System.out.println(label);
    }
}
```

`switch` as an **expression** (note the trailing `;` after the closing `}`) evaluates to a value directly — no `label` variable declared-then-assigned across branches, no `break` needed, and no accidental fall-through: each arrow branch runs only its own single expression and nothing else. Multiple labels can share one branch with a comma:

```java
public class Main {
    public static void main(String[] args) {
        int priority = 4;

        String bucket = switch (priority) {
            case 1, 2 -> "LOW";
            case 3, 4 -> "MEDIUM";
            case 5 -> "HIGH";
            default -> "INVALID";
        };

        System.out.println("Priority bucket: " + bucket);
    }
}
```

## Which one should you use?

Prefer the **arrow form** for new code: it can't fall through by accident, it works naturally as an expression, and the compiler checks exhaustiveness more strictly. Reach for the **classic form** when you deliberately need fall-through behavior (rare but real, as in the notification example above), or when maintaining existing code that already uses it. Both forms support `String`, primitives like `int`, `char`, and `enum` values as the switched-on type.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "control-flow-switch-q1",
      "type": "mcq",
      "prompt": "In a classic switch, what happens if a matching case has no break statement?",
      "options": [
        { "id": "a", "text": "The switch exits immediately after that case, same as with break" },
        { "id": "b", "text": "A compile error occurs — break is mandatory" },
        { "id": "c", "text": "Execution falls through and keeps running the code in the next case, regardless of whether its label matches" },
        { "id": "d", "text": "Java automatically inserts an implicit break" }
      ],
      "correct": "c",
      "explanation": "Classic switch has no implicit break — once a case matches, execution runs every statement below it until it hits a break or the end of the switch block, even if the next case's label doesn't match the switched value."
    },
    {
      "id": "control-flow-switch-q2",
      "type": "mcq",
      "prompt": "What is a key advantage of the arrow form (case X -> ...) over the classic form?",
      "options": [
        { "id": "a", "text": "It runs faster at execution time" },
        { "id": "b", "text": "Each branch is isolated — no accidental fall-through into the next case" },
        { "id": "c", "text": "It can switch on types that classic switch cannot, such as int" },
        { "id": "d", "text": "It does not require a default case ever" }
      ],
      "correct": "b",
      "explanation": "Arrow-form branches only execute their own expression or block — there's no shared fall-through path between cases, which removes the most common classic-switch bug entirely."
    },
    {
      "id": "control-flow-switch-q3",
      "type": "mcq",
      "prompt": "What does `case 1, 2 -> \"LOW\";` mean in an arrow-form switch?",
      "options": [
        { "id": "a", "text": "It's a syntax error — only one value per case is allowed" },
        { "id": "b", "text": "Both 1 and 2 map to the same branch, producing \"LOW\" for either" },
        { "id": "c", "text": "It matches only when the switched value equals both 1 and 2" },
        { "id": "d", "text": "It creates a range from 1 to 2" }
      ],
      "correct": "b",
      "explanation": "A comma-separated list of labels lets multiple values share one arrow branch — equivalent to stacking case labels in classic switch, but in a single line."
    }
  ]
}
```

## What's next

Next up: loops. `for`, `while`, `do-while`, and the enhanced for-each — the tools for repeating work across TaskFlow's tasks instead of writing out each one by hand.
