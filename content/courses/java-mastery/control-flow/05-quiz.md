---
kind: quiz
id_key: java-mastery/control-flow/quiz
course: java-mastery
section: control-flow
section_title: "Control Flow"
section_position: 2
title: "Module Assessment: Control Flow"
position: 4
estimated_minutes: 20
source: [java-mastery-curriculum.md]
pass_percentage: 70
duration_minutes: 20
questions:
  - id_key: string-equals-vs-double-equals
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "TaskFlow code compares two task status Strings with `status == \"DONE\"` instead of `status.equals(\"DONE\")`. What's the risk?"
    multiple: false
    options:
      - { text: "No risk — == and .equals() always behave identically for String", correct: false }
      - { text: "== may return false for Strings with identical content if they aren't the same object in memory", correct: true }
      - { text: "== throws a NullPointerException whenever used on a String", correct: false }
      - { text: "It's a compile error to use == on String values", correct: false }
    explanation: "== compares object references, not content. Two String variables can hold the same text but be different objects, so == can return false when .equals() would correctly return true."
  - id_key: ternary-is-expression
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "Why can `String label = score >= 5 ? \"HIGH\" : \"LOW\";` be written on one line, unlike an equivalent if/else?"
    multiple: false
    options:
      - { text: "The ternary operator is a statement, just like if/else", correct: false }
      - { text: "The ternary operator is an expression that evaluates to a value, so it can appear on the right side of an assignment", correct: true }
      - { text: "String assignments always require a single line in Java", correct: false }
      - { text: "It only works because both branches return the same literal length", correct: false }
    explanation: "condition ? a : b evaluates to a value in place, which is why it fits directly into an assignment. if/else is a statement — it controls flow but doesn't produce a value itself."
  - id_key: switch-fallthrough-behavior
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A classic switch case has code but no break, and its condition matches. What happens next?"
    multiple: false
    options:
      - { text: "The switch exits immediately, identical to having a break", correct: false }
      - { text: "Execution falls through into the following case's code, regardless of whether that case's label matches", correct: true }
      - { text: "A runtime exception is thrown", correct: false }
      - { text: "The switch skips to the default case", correct: false }
    explanation: "Classic switch has no implicit break. Without one, execution keeps running straight into the next case's statements — this is fall-through, and it's the single most common classic-switch bug."
  - id_key: labeled-break-purpose
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "While scanning tasks nested inside projects with two for loops, a plain (unlabeled) break inside the inner loop only stops the inner loop — the outer loop keeps going. What fixes this?"
    multiple: false
    options:
      - { text: "Using continue instead of break", correct: false }
      - { text: "Labeling the outer loop and using break with that label from inside the inner loop", correct: true }
      - { text: "Nothing — break always exits every enclosing loop", correct: false }
      - { text: "Switching the inner loop to a while loop", correct: false }
    explanation: "An unlabeled break only exits the loop it's directly written inside. A label on the outer loop, combined with `break label;`, lets you exit both loops at once from deep inside the nested search."
  - id_key: priority-bucket-coding
    type: coding
    difficulty: beginner
    points: 3
    prompt: >-
      TaskFlow needs to classify a task's priority. Read a single integer from stdin
      (1 through 5). Print exactly one word: "LOW" for 1 or 2, "MEDIUM" for 3 or 4,
      and "HIGH" for 5. No extra text.
    languages: [java]
    starter_code:
      java: |
        import java.util.Scanner;

        public class Main {
            public static void main(String[] args) {
                Scanner scanner = new Scanner(System.in);
                int priority = scanner.nextInt();
                // TODO: print LOW for 1-2, MEDIUM for 3-4, HIGH for 5

            }
        }
    test_cases:
      - { stdin: "1", expected: "LOW", hidden: false, weight: 1 }
      - { stdin: "2", expected: "LOW", hidden: false, weight: 1 }
      - { stdin: "3", expected: "MEDIUM", hidden: true, weight: 1 }
      - { stdin: "4", expected: "MEDIUM", hidden: true, weight: 1 }
      - { stdin: "5", expected: "HIGH", hidden: true, weight: 1 }
    explanation: "An if/else chain or an arrow switch on priority, grouping 1-2 into LOW, 3-4 into MEDIUM, and 5 into HIGH, then printing the single resulting word with println, satisfies every case."
  - id_key: control-flow-reflection
    type: subjective
    difficulty: beginner
    points: 2
    prompt: >-
      In your own words: which single concept from this module (if/else and the
      ternary operator, classic vs. arrow switch, the four loop forms, or
      break/continue/labeled loops) felt least intuitive to you, and why? Be
      specific about what confused you — this answer feeds directly into what
      gets flagged for extra review.
    multiple: false
    options: []
    explanation: "Graded for genuine, specific reflection rather than a single correct answer — the goal is to surface which topic you're actually shakiest on, not to test recall."
---
