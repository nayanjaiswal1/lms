---
kind: quiz
id_key: java-mastery/getting-started/quiz
course: java-mastery
section: getting-started
section_title: "Getting Started"
section_position: 1
title: "Module Assessment: Java Fundamentals"
position: 4
estimated_minutes: 20
source: [java-mastery-curriculum.md]
pass_percentage: 70
duration_minutes: 20
questions:
  - id_key: jvm-vs-jdk-vs-jre
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "Which of these do you need installed to compile Java source code, not just run already-compiled programs?"
    multiple: false
    options:
      - { text: "JRE only", correct: false }
      - { text: "JVM only", correct: false }
      - { text: "JDK", correct: true }
      - { text: "None — any text editor is sufficient", correct: false }
    explanation: "The JDK includes javac (the compiler) plus everything in the JRE. The JRE alone can run compiled bytecode but cannot compile source."
  - id_key: static-typing-catch
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "What does it mean that Java is statically typed?"
    multiple: false
    options:
      - { text: "Variable types are checked and fixed at compile time, not decided at runtime", correct: true }
      - { text: "Variables cannot change their value once set", correct: false }
      - { text: "Every variable must be declared final", correct: false }
      - { text: "Types are only enforced when the program crashes", correct: false }
    explanation: "Static typing means the compiler knows and enforces every variable's type before the program ever runs — a type mismatch is a compile error, not a runtime surprise."
  - id_key: division-truncation
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A TaskFlow report divides totalMinutes (int) by 60 to get hours, using totalMinutes / 60. For totalMinutes = 150, what's the risk?"
    multiple: false
    options:
      - { text: "No risk — this correctly gives 2.5 hours", correct: false }
      - { text: "Integer division truncates to 2, silently discarding the remaining 30 minutes' worth of decimal precision", correct: true }
      - { text: "It throws an ArithmeticException", correct: false }
      - { text: "It's a compile error because int can't be divided", correct: false }
    explanation: "150 / 60 with two ints is integer division: it truncates to 2, not 2.5. Getting a decimal result requires making at least one operand a double, e.g. totalMinutes / 60.0."
  - id_key: var-inference
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: "Which declaration is invalid?"
    multiple: false
    options:
      - { text: "var taskCount = 5;", correct: false }
      - { text: "var taskName = \"Deploy\";", correct: false }
      - { text: "var pending;", correct: true }
      - { text: "final var MAX = 100;", correct: false }
    explanation: "var requires an initializer on the same line so the compiler has something to infer the type from — var pending; alone is a compile error."
  - id_key: scanner-mixing-bug
    type: mcq
    difficulty: advanced
    points: 2
    prompt: "Code calls scanner.nextInt() to read a priority number, then immediately scanner.nextLine() expecting the task description on the next line — but it gets an empty string. Why?"
    multiple: false
    options:
      - { text: "nextInt() left the trailing newline character in the buffer, which the following nextLine() immediately consumed as an empty line", correct: true }
      - { text: "Scanner can only be used once per program", correct: false }
      - { text: "nextLine() always returns an empty string after any numeric read", correct: false }
      - { text: "The Scanner needs to be re-created between reads", correct: false }
    explanation: "nextInt() stops at the numeric token and doesn't consume the newline after it. The next nextLine() call reads up to that leftover newline, returning an empty string — a very common real-world Scanner bug."
  - id_key: taskflow-person-hours
    type: coding
    difficulty: beginner
    points: 3
    prompt: >-
      TaskFlow needs a quick utility. Read two integers from a single line of input,
      separated by a space: the estimated hours for a task, and the number of team
      members assigned. Print a single integer: hours multiplied by members (the total
      person-hours), with no extra text.
    languages: [java]
    starter_code:
      java: |
        import java.util.Scanner;

        public class Main {
            public static void main(String[] args) {
                Scanner scanner = new Scanner(System.in);
                // Read two space-separated integers from one line and print their product.

            }
        }
    test_cases:
      - { stdin: "6 3", expected: "18", hidden: false, weight: 1 }
      - { stdin: "10 2", expected: "20", hidden: true, weight: 1 }
      - { stdin: "0 5", expected: "0", hidden: true, weight: 1 }
      - { stdin: "7 1", expected: "7", hidden: true, weight: 1 }
    explanation: "scanner.nextInt() twice reads both values off one line; System.out.println(hours * members) prints the product with a trailing newline, matching the expected output."
  - id_key: getting-started-reflection
    type: subjective
    difficulty: beginner
    points: 2
    prompt: >-
      In your own words: which single concept from this module (JVM/JDK/JRE, primitive
      types and casting, operators, or Scanner input) felt least intuitive to you, and
      why? Be specific about what confused you — this answer feeds directly into what
      gets flagged for extra review.
    multiple: false
    options: []
    explanation: "Graded for genuine, specific reflection rather than a single correct answer — the goal is to surface which topic you're actually shakiest on, not to test recall."
---
