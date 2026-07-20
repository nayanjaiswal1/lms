---
kind: quiz
id_key: java-mastery/exceptions/quiz
course: java-mastery
section: exceptions
section_title: "Exceptions"
section_position: 6
title: "Module Assessment: Exceptions"
position: 4
estimated_minutes: 25
source: [java-mastery-curriculum.md]
pass_percentage: 70
duration_minutes: 25
questions:
  - id_key: checked-vs-unchecked-base-class
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "What determines whether an exception is checked or unchecked?"
    multiple: false
    options:
      - { text: "Whether it extends Exception (checked) vs. RuntimeException (unchecked)", correct: true }
      - { text: "Whether it has a message string", correct: false }
      - { text: "Whether it's thrown inside a try block", correct: false }
      - { text: "Whether it's a custom exception or a built-in one", correct: false }
    explanation: "Extending RuntimeException (directly or transitively) makes an exception unchecked, meaning the compiler does not require it to be caught or declared. Extending Exception directly makes it checked."
  - id_key: finally-guarantee
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "A try block throws an exception that is NOT caught by any matching catch block. Does the finally block still run?"
    multiple: false
    options:
      - { text: "No, finally is skipped entirely if nothing catches the exception", correct: false }
      - { text: "Yes, finally always runs before the uncaught exception continues propagating up the call stack", correct: true }
      - { text: "Only if the exception is a checked exception", correct: false }
      - { text: "Only if System.exit() has not been called", correct: false }
    explanation: "finally runs in every case: normal completion, a caught exception, or an exception that propagates uncaught. It's the one block guaranteed to execute regardless of how the try block exits (short of the JVM itself terminating abruptly)."
  - id_key: try-with-resources-interface
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: "What must a class implement to be used inside try-with-resources parentheses?"
    multiple: false
    options:
      - { text: "Serializable", correct: false }
      - { text: "AutoCloseable", correct: true }
      - { text: "Comparable", correct: false }
      - { text: "Cloneable", correct: false }
    explanation: "Try-with-resources works with any type implementing AutoCloseable (which declares close()). The compiler guarantees close() is invoked automatically when the try block exits, normally or via an exception."
  - id_key: catch-order-compile-error
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A method has catch (RuntimeException e) followed by catch (NumberFormatException e) for the same try block. What happens?"
    multiple: false
    options:
      - { text: "It compiles and works fine — order never matters", correct: false }
      - { text: "It's a compile error: NumberFormatException is a subtype of RuntimeException, so the second catch is unreachable", correct: true }
      - { text: "The NumberFormatException catch silently takes priority at runtime", correct: false }
      - { text: "It throws a runtime exception the first time a NumberFormatException occurs", correct: false }
    explanation: "Catch blocks are evaluated top to bottom. Since NumberFormatException IS-A RuntimeException, placing the broader RuntimeException catch first means the more specific catch below it can never be reached — Java rejects this at compile time."
  - id_key: exception-chaining-cause
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A TaskNotFoundException is constructed as new TaskNotFoundException(\"task missing\", originalDbError), with originalDbError passed through to super(message, cause). What is the benefit?"
    multiple: false
    options:
      - { text: "It makes the exception checked instead of unchecked", correct: false }
      - { text: "It preserves the original low-level failure as the cause, retrievable later via getCause(), so debugging can trace the full failure chain", correct: true }
      - { text: "It suppresses the original exception so it never appears in logs", correct: false }
      - { text: "It has no functional effect, only cosmetic" }
    explanation: "Exception chaining preserves the original cause instead of discarding it when translating a low-level failure into a higher-level, more meaningful exception type. getCause() and full chained stack traces make root-causing far easier."
  - id_key: exceptions-hours-validator
    type: coding
    difficulty: intermediate
    points: 3
    prompt: >-
      TaskFlow needs to validate an hours estimate coming from user input. Read a single
      integer from stdin representing estimated hours. If the value is negative, catch or
      detect that condition and print exactly INVALID (no other text). Otherwise, print
      exactly OK: <hours> where <hours> is the integer value, e.g. "OK: 5".
    languages: [java]
    starter_code:
      java: |
        import java.util.Scanner;

        public class Main {
            public static void main(String[] args) {
                Scanner scanner = new Scanner(System.in);
                // Read one integer (hours). If it's negative, print INVALID.
                // Otherwise print "OK: " followed by the hours value.

            }
        }
    test_cases:
      - { stdin: "5", expected: "OK: 5", hidden: false, weight: 1 }
      - { stdin: "-3", expected: "INVALID", hidden: false, weight: 1 }
      - { stdin: "0", expected: "OK: 0", hidden: true, weight: 1 }
      - { stdin: "100", expected: "OK: 100", hidden: true, weight: 1 }
      - { stdin: "-1", expected: "INVALID", hidden: true, weight: 1 }
    explanation: "A straightforward if/else on hours < 0 covers this directly, or the negative case could be raised as an IllegalArgumentException and caught around the check — either way, print exactly INVALID or exactly \"OK: \" + hours with nothing else, since output is compared exactly."
  - id_key: exceptions-reflection
    type: subjective
    difficulty: beginner
    points: 2
    prompt: >-
      In your own words: which single concept from this module (checked vs. unchecked
      exceptions, try-with-resources, custom exceptions and chaining, or exception-handling
      best practices) felt least intuitive to you, and why? Be specific about what confused
      you — this answer feeds directly into what gets flagged for extra review.
    multiple: false
    options: []
    explanation: "Graded for genuine, specific reflection rather than a single correct answer — the goal is to surface which topic you're actually shakiest on, not to test recall."
---
