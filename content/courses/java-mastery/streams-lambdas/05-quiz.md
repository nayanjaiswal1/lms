---
kind: quiz
id_key: java-mastery/streams-lambdas/quiz
course: java-mastery
section: streams-lambdas
section_title: "Lambdas & the Stream API"
section_position: 10
title: "Module Assessment: Lambdas & the Stream API"
position: 4
estimated_minutes: 25
source: [java-mastery-curriculum.md]
pass_percentage: 70
duration_minutes: 25
questions:
  - id_key: functional-interface-definition
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "What defines a functional interface in Java?"
    multiple: false
    options:
      - { text: "It has exactly one abstract method", correct: true }
      - { text: "It has no methods at all", correct: false }
      - { text: "It is annotated @FunctionalInterface, and that annotation alone is what makes it one", correct: false }
      - { text: "It must be declared inside another interface", correct: false }
    explanation: "A functional interface has exactly one abstract method, which is what makes it possible for a lambda expression to implement it. @FunctionalInterface is an optional annotation that asks the compiler to enforce this — it documents the intent, it doesn't create it."
  - id_key: method-reference-unbound-vs-bound
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "What is the difference between the method references Task::getName and someTask::getPriority (where someTask is an existing Task variable)?"
    multiple: false
    options:
      - { text: "Task::getName is unbound (the instance arrives as the lambda's argument); someTask::getPriority is bound to that specific already-existing object", correct: true }
      - { text: "There is no difference — both forms behave identically", correct: false }
      - { text: "Task::getName only works inside streams, someTask::getPriority only works outside them", correct: false }
      - { text: "someTask::getPriority is invalid syntax", correct: false }
    explanation: "Class::instanceMethod (Task::getName) is unbound: the object to call the method on is supplied later. instance::instanceMethod (someTask::getPriority) is bound: it always operates on that one specific, already-created object."
  - id_key: stream-laziness
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Given `tasks.stream().filter(t -> t.getPriority().equals(\"HIGH\"))` with no terminal operation called afterward, what happens?"
    multiple: false
    options:
      - { text: "The filter runs immediately over every task", correct: false }
      - { text: "Nothing happens yet — filter() only builds up the pipeline; it isn't executed until a terminal operation like collect() or forEach() is called", correct: true }
      - { text: "It throws an exception because a stream must always end in collect()", correct: false }
      - { text: "It returns a List<Task> directly", correct: false }
    explanation: "Streams are lazy. Intermediate operations like filter() and map() just describe the pipeline; nothing actually iterates the source until a terminal operation triggers execution."
  - id_key: reduce-vs-collect
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A pipeline needs to combine every Task's estimateHours into a single running total (an int). Which terminal operation is designed for that?"
    multiple: false
    options:
      - { text: "collect(Collectors.toList())", correct: false }
      - { text: "sorted()", correct: false }
      - { text: "reduce(0, (total, hours) -> total + hours), typically after mapping each Task to its hours", correct: true }
      - { text: "filter()", correct: false }
    explanation: "reduce() folds a stream down to a single combined value using an identity starting point and an accumulator function — exactly the shape needed for a running total. collect(Collectors.toList()) instead gathers elements into a new collection, not a single scalar."
  - id_key: optional-purpose
    type: mcq
    difficulty: advanced
    points: 2
    prompt: "Why is Optional<Task> generally preferred over returning a possibly-null Task from a search method?"
    multiple: false
    options:
      - { text: "Optional makes the method run faster than returning null", correct: false }
      - { text: "Optional forces the 'might be empty' case into the method's return type, so callers use map/orElse/ifPresent instead of silently forgetting a null check", correct: true }
      - { text: "Optional<Task> and Task are interchangeable, so it makes no real difference", correct: false }
      - { text: "Returning null is illegal in modern Java", correct: false }
    explanation: "Optional communicates possible absence directly through the type system. A caller working with Optional<Task> is guided toward handling the empty case (via orElse, ifPresent, map) rather than relying on discipline to remember a null check on a plain Task return."
  - id_key: taskflow-hours-above-threshold
    type: coding
    difficulty: intermediate
    points: 3
    prompt: >-
      TaskFlow needs to report total hours spent on tasks above a certain size. Read a single
      integer threshold from the first line of input. Read the second line as a space-separated
      list of integers (task hours). Using a Stream with a filter and a sum, print a single
      integer: the sum of only the hours strictly greater than the threshold, with no extra text.
    languages: [java]
    starter_code:
      java: |
        import java.util.Scanner;
        import java.util.ArrayList;
        import java.util.List;

        public class Main {
            public static void main(String[] args) {
                Scanner scanner = new Scanner(System.in);
                int threshold = Integer.parseInt(scanner.nextLine().trim());
                String[] tokens = scanner.nextLine().trim().split("\\s+");

                List<Integer> hours = new ArrayList<>();
                for (String token : tokens) {
                    hours.add(Integer.parseInt(token));
                }

                // TODO: use hours.stream() with .filter() and .mapToInt(...).sum()
                // to print the sum of only the values strictly greater than threshold.

            }
        }
    test_cases:
      - { stdin: "5\n6 3 8 2 10\n", expected: "24", hidden: false, weight: 1 }
      - { stdin: "0\n1 2 3\n", expected: "6", hidden: false, weight: 1 }
      - { stdin: "100\n10 20 30\n", expected: "0", hidden: true, weight: 1 }
      - { stdin: "5\n5 5 5\n", expected: "0", hidden: true, weight: 1 }
    explanation: "hours.stream().filter(h -> h > threshold).mapToInt(Integer::intValue).sum() filters to only values above the threshold, then sums the resulting IntStream. System.out.println(...) on that sum matches the expected output exactly."
  - id_key: streams-lambdas-reflection
    type: subjective
    difficulty: beginner
    points: 2
    prompt: >-
      In your own words: which concept from this module (functional interfaces and lambdas,
      method references, the Stream API, or Optional) felt least intuitive, and why? Be
      specific — this feeds directly into what gets flagged for review.
    multiple: false
    options: []
    explanation: "Graded for genuine, specific reflection rather than a single correct answer — the goal is to surface which topic you're actually shakiest on, not to test recall."
---
