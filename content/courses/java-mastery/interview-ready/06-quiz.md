---
kind: quiz
id_key: java-mastery/interview-ready/quiz
course: java-mastery
section: interview-ready
section_title: "Interview Ready"
section_position: 18
title: "Capstone Assessment: Java Mastery"
position: 5
estimated_minutes: 45
source: [java-mastery-curriculum.md]
pass_percentage: 75
duration_minutes: 45
questions:
  - id_key: capstone-equals-hashcode
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Why does overriding equals() without also overriding hashCode() break HashSet/HashMap behavior?"
    multiple: false
    options:
      - { text: "It doesn't — equals() alone is sufficient", correct: false }
      - { text: "Two objects considered equal by equals() can still land in different hash buckets if hashCode() wasn't overridden to match, so a HashSet can silently store 'duplicate' entries", correct: true }
      - { text: "hashCode() is deprecated and should never be overridden", correct: false }
      - { text: "Java throws a compile error if hashCode() is missing", correct: false }
    explanation: "The equals/hashCode contract requires equal objects to produce equal hash codes. Breaking that contract means hash-based collections can't reliably detect that two 'equal' objects are the same entry."
  - id_key: capstone-abstract-vs-interface
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "What can an abstract class provide that a plain interface (pre-Java 8, no default methods) could not?"
    multiple: false
    options:
      - { text: "Shared instance state (fields) and partially-implemented behavior subclasses inherit directly", correct: true }
      - { text: "The ability to be instantiated directly with new" , correct: false }
      - { text: "Multiple inheritance of implementation from unrelated types", correct: false }
      - { text: "There was never any difference between the two", correct: false }
    explanation: "Abstract classes can hold real fields and concrete method bodies that subclasses inherit outright — the core distinction from interfaces, even now that interfaces support default methods for shared behavior."
  - id_key: capstone-hashmap-resize
    type: mcq
    difficulty: advanced
    points: 3
    prompt: "What triggers a HashMap to resize (rehash) its internal bucket array?"
    multiple: false
    options:
      - { text: "It never resizes — the initial capacity is fixed for the object's lifetime", correct: false }
      - { text: "The number of entries exceeds capacity * loadFactor (default load factor 0.75), triggering a resize (typically doubling) and a full rehash of existing entries", correct: true }
      - { text: "Resizing happens on every single put() call", correct: false }
      - { text: "Only calling clear() can change the internal capacity", correct: false }
    explanation: "HashMap grows once its entry count crosses capacity times the load factor, to keep the average bucket chain short — this rehash is also why HashMap iteration order can appear to shift as entries are added."
  - id_key: capstone-deadlock-conditions
    type: mcq
    difficulty: advanced
    points: 2
    prompt: "Which of these is NOT one of the four necessary conditions for deadlock?"
    multiple: false
    options:
      - { text: "Mutual exclusion" , correct: false }
      - { text: "Hold and wait" , correct: false }
      - { text: "Garbage collection pause" , correct: true }
      - { text: "Circular wait" , correct: false }
    explanation: "The four classic necessary conditions are mutual exclusion, hold-and-wait, no preemption, and circular wait. Garbage collection is unrelated to deadlock formation."
  - id_key: capstone-generics-erasure
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Why can't you write `if (list instanceof List<String>)` in Java?"
    multiple: false
    options:
      - { text: "instanceof cannot be used with any collection type" , correct: false }
      - { text: "Generic type information is erased at runtime (type erasure), so the JVM only knows list is a List, not what it's a List of", correct: true }
      - { text: "It's valid syntax and works exactly as expected", correct: false }
      - { text: "List<String> is not a real type" , correct: false }
    explanation: "Type erasure removes generic type parameters at compile time — at runtime, all List<T> instances are just List. This is why unchecked wildcard casts and raw-type warnings exist in Java's generics."
  - id_key: capstone-optional-purpose
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "What problem does Optional primarily address?"
    multiple: false
    options:
      - { text: "Making a method run faster", correct: false }
      - { text: "Making the possibility of \"no value\" explicit in a method's return type, instead of relying on a possibly-null reference the caller might forget to check", correct: true }
      - { text: "Replacing all collections in Java", correct: false }
      - { text: "Enforcing thread safety", correct: false }
    explanation: "Optional<T> makes 'this might not have a value' part of the type signature, nudging callers to explicitly handle absence instead of silently risking a NullPointerException."
  - id_key: capstone-string-immutability-security
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Beyond thread-safety, why does String immutability matter for the string constant pool?"
    multiple: false
    options:
      - { text: "It doesn't relate to the pool at all", correct: false }
      - { text: "Because Strings can't change after creation, the JVM can safely let multiple references share one pooled instance without any reference's mutation affecting another", correct: true }
      - { text: "The pool only exists for numeric wrapper types", correct: false }
      - { text: "Immutability makes string concatenation faster in all cases", correct: false }
    explanation: "String pooling relies entirely on immutability — sharing one object across many references would be unsafe if any one of them could mutate it out from under the others."
  - id_key: capstone-executorservice-vs-thread
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Why prefer an ExecutorService thread pool over manually creating a new Thread per task?"
    multiple: false
    options:
      - { text: "Thread pools reuse a bounded set of worker threads instead of paying thread-creation cost per task and risking unbounded resource usage under load", correct: true }
      - { text: "new Thread() is deprecated and no longer compiles", correct: false }
      - { text: "ExecutorService tasks run synchronously, unlike raw threads", correct: false }
      - { text: "There is no real difference between the two approaches", correct: false }
    explanation: "Unbounded thread creation under load can exhaust memory and CPU scheduling overhead. A pool caps concurrency and reuses threads, which is why it's the production-standard approach over raw Thread management."
  - id_key: capstone-collections-coding
    type: coding
    difficulty: intermediate
    points: 4
    prompt: >-
      Read a single line of space-separated integers (task priority scores) from stdin. Using a Stream
      pipeline, print the count of scores strictly greater than 5, followed by a space, followed by the sum
      of exactly those scores — on one line, e.g. "3 27" (no other text).
    languages: [java]
    starter_code:
      java: |
        import java.util.Arrays;
        import java.util.Scanner;
        import java.util.stream.Collectors;

        public class Main {
            public static void main(String[] args) {
                Scanner scanner = new Scanner(System.in);
                String line = scanner.nextLine();
                int[] scores = Arrays.stream(line.trim().split("\\s+")).mapToInt(Integer::parseInt).toArray();
                // Using a stream, count how many scores are > 5, and sum exactly those scores.
                // Print: "<count> <sum>"

            }
        }
    test_cases:
      - { stdin: "1 6 8 3 9 2", expected: "3 23", hidden: false, weight: 1 }
      - { stdin: "10 10 10", expected: "3 30", hidden: true, weight: 1 }
      - { stdin: "1 2 3 4 5", expected: "0 0", hidden: true, weight: 1 }
      - { stdin: "6", expected: "1 6", hidden: true, weight: 1 }
    explanation: "Arrays.stream(scores).filter(s -> s > 5) narrows to the qualifying scores; .count() and a second filtered .sum() (or collecting once into an IntSummaryStatistics) produce the two numbers — the Stream API's filter/reduce idiom from the streams-lambdas module."
  - id_key: capstone-oop-coding
    type: coding
    difficulty: intermediate
    points: 4
    prompt: >-
      Complete the Task class below so hoursRemaining() returns estimateHours minus hoursLogged, but never a
      negative number (clamp at 0). Read three integers from one line of stdin — estimateHours, hoursLogged,
      and a third value ignored — and print only the result of calling hoursRemaining() on a Task built from
      the first two values.
    languages: [java]
    starter_code:
      java: |
        import java.util.Scanner;

        public class Main {
            static class Task {
                private final int estimateHours;
                private final int hoursLogged;

                Task(int estimateHours, int hoursLogged) {
                    this.estimateHours = estimateHours;
                    this.hoursLogged = hoursLogged;
                }

                int hoursRemaining() {
                    // Return estimateHours - hoursLogged, but never less than 0.

                    return 0;
                }
            }

            public static void main(String[] args) {
                Scanner scanner = new Scanner(System.in);
                int estimateHours = scanner.nextInt();
                int hoursLogged = scanner.nextInt();
                scanner.nextInt(); // ignored third value
                Task task = new Task(estimateHours, hoursLogged);
                System.out.println(task.hoursRemaining());
            }
        }
    test_cases:
      - { stdin: "10 4 99", expected: "6", hidden: false, weight: 1 }
      - { stdin: "5 5 0", expected: "0", hidden: true, weight: 1 }
      - { stdin: "3 9 1", expected: "0", hidden: true, weight: 1 }
      - { stdin: "20 1 5", expected: "19", hidden: true, weight: 1 }
    explanation: "Math.max(0, estimateHours - hoursLogged) is the clamp — the same defensive-encapsulation instinct as the OOP module's validated setters: never let a public method return a value that violates a basic domain invariant like 'hours remaining can't be negative.'"
  - id_key: capstone-reflection
    type: subjective
    difficulty: beginner
    points: 3
    prompt: >-
      Looking back across the whole course, which module or concept are you least confident you could explain
      correctly in a live interview right now? Be specific — this is the strongest signal for what should show
      up in your revision plan.
    multiple: false
    options: []
    explanation: "Graded for genuine, specific self-assessment rather than a single correct answer — the single richest signal this course collects for what deserves focused review."
---
