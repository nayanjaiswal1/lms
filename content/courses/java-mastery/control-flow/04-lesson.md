---
kind: lesson
id_key: java-mastery/control-flow/break-continue-labels
course: java-mastery
section: control-flow
section_title: "Control Flow"
section_position: 2
title: "break, continue, and Labeled Loops"
position: 3
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
`break` and `continue` change a loop's normal flow: `break` exits the loop entirely, `continue` skips straight to the next iteration. Both work on the loop they're written inside — but sometimes you need to control an **outer** loop from inside a **nested** one, which is what labels are for.

## continue: skip this iteration

```java
public class Main {
    public static void main(String[] args) {
        String[] statuses = { "DONE", "IN_PROGRESS", "DONE", "TODO" };

        for (String status : statuses) {
            if (status.equals("DONE")) {
                continue; // skip completed tasks, nothing to report
            }
            System.out.println("Needs attention: " + status);
        }
    }
}
```

`continue` jumps immediately to the next iteration — for a `for` loop, that means running the update step (`i++`) and re-checking the condition, skipping everything below `continue` for the current pass. Here, `DONE` tasks are skipped entirely; only `IN_PROGRESS` and `TODO` get printed.

## break: exit the loop entirely

```java
public class Main {
    public static void main(String[] args) {
        int[] priorities = { 2, 3, 5, 4, 1 };

        for (int priority : priorities) {
            if (priority == 5) {
                System.out.println("Found urgent task, stopping scan");
                break;
            }
            System.out.println("Checked priority " + priority + ", not urgent");
        }
    }
}
```

`break` stops the loop immediately — no more iterations run, even though `priorities` still has elements left (`4` and `1` are never checked). This is the standard pattern for "search until found, then stop."

## Labeled loops: breaking out of nested loops

A plain `break` only exits the **innermost** loop it's written in. When you're scanning a nested structure — TaskFlow's projects, each holding a list of tasks — and need to stop the *entire* search the moment you find what you're after, a **label** on the outer loop lets `break` (or `continue`) target it directly:

```java
public class Main {
    public static void main(String[] args) {
        String[] projectNames = { "Website Revamp", "Mobile App", "Internal Tools" };
        String[][] tasksByProject = {
            { "Wireframes", "Homepage build" },
            { "Login screen", "Push notifications", "URGENT: Crash on launch" },
            { "Cleanup scripts" }
        };

        searchProjects:
        for (int p = 0; p < projectNames.length; p++) {
            for (int t = 0; t < tasksByProject[p].length; t++) {
                String taskName = tasksByProject[p][t];
                if (taskName.startsWith("URGENT")) {
                    System.out.println("Found \"" + taskName + "\" in " + projectNames[p]);
                    break searchProjects;
                }
            }
        }
    }
}
```

`searchProjects:` labels the outer loop. `break searchProjects;` exits **that** loop directly, skipping the rest of both the inner loop and any remaining outer iterations — without a label, a plain `break` here would only stop the inner loop over `tasksByProject[p]`, and the outer loop would move on to check the next project unnecessarily. `continue searchProjects;` follows the same idea: it would skip to the outer loop's next iteration instead of the inner one's.

Labeled breaks are a niche tool — reach for them only when a genuinely nested search needs to abort completely from deep inside, which is rarer than it sounds. For most nested-loop logic, restructuring into a separate method that simply `return`s once it finds what it's looking for reads more clearly than a label.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "control-flow-break-continue-labels-q1",
      "type": "mcq",
      "prompt": "What does continue do inside a loop?",
      "options": [
        { "id": "a", "text": "Exits the loop entirely" },
        { "id": "b", "text": "Skips the rest of the current iteration and moves to the next one" },
        { "id": "c", "text": "Restarts the loop from its first iteration" },
        { "id": "d", "text": "Pauses the loop until a condition changes" }
      ],
      "correct": "b",
      "explanation": "continue jumps straight to the next iteration — for a for loop, that means running the update step and re-checking the condition — skipping any code below it for the current pass only."
    },
    {
      "id": "control-flow-break-continue-labels-q2",
      "type": "mcq",
      "prompt": "Inside a nested loop, what does a plain (unlabeled) break do?",
      "options": [
        { "id": "a", "text": "Exits every enclosing loop, inner and outer" },
        { "id": "b", "text": "Exits only the innermost loop it's written in" },
        { "id": "c", "text": "Exits only the outermost loop" },
        { "id": "d", "text": "It's a compile error inside nested loops" }
      ],
      "correct": "b",
      "explanation": "An unlabeled break only ever affects the loop it's directly written inside — the innermost one. To exit an outer loop from inside a nested one, you need a label."
    },
    {
      "id": "control-flow-break-continue-labels-q3",
      "type": "mcq",
      "prompt": "What does `break searchProjects;` do when searchProjects labels the outer of two nested loops?",
      "options": [
        { "id": "a", "text": "Exits only the inner loop, same as a plain break" },
        { "id": "b", "text": "Exits the outer loop directly, skipping any remaining inner and outer iterations" },
        { "id": "c", "text": "Throws a runtime exception" },
        { "id": "d", "text": "Restarts the outer loop from its beginning" }
      ],
      "correct": "b",
      "explanation": "A labeled break targets the labeled loop specifically — execution jumps past that loop entirely, which is exactly what's needed to abort a nested search the moment a match is found."
    }
  ]
}
```

## What's next

The module quiz below covers all four control-flow topics together — branching, switch, loops, and break/continue/labels — before you move on to **object-oriented basics**, where TaskFlow's tasks become real classes.
