---
kind: quiz
id_key: java-mastery/design-patterns/quiz
course: java-mastery
section: design-patterns
section_title: "Design Patterns"
section_position: 14
title: "Module Assessment: Design Patterns"
position: 5
estimated_minutes: 25
source: [java-mastery-curriculum.md]
pass_percentage: 70
duration_minutes: 25
questions:
  - id_key: srp-violation
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "A TaskService class both saves tasks to the database AND formats them into HTML for email notifications. Which SOLID principle does this violate?"
    multiple: false
    options:
      - { text: "Single Responsibility Principle — the class has two reasons to change (persistence logic and presentation logic)", correct: true }
      - { text: "Liskov Substitution Principle", correct: false }
      - { text: "Interface Segregation Principle", correct: false }
      - { text: "It doesn't violate any SOLID principle", correct: false }
    explanation: "A class with two unrelated responsibilities has two independent reasons to change — a hallmark SRP violation. Persistence and presentation should live in separate classes."
  - id_key: singleton-thread-safety
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Why is a naive lazy Singleton (checking `if (instance == null) instance = new Thing();` with no synchronization) unsafe under concurrency?"
    multiple: false
    options:
      - { text: "It isn't unsafe — Singletons are always thread-safe by design", correct: false }
      - { text: "Two threads can both see instance as null at the same time and each construct a separate instance, breaking the single-instance guarantee", correct: true }
      - { text: "Java forbids static fields from being null", correct: false }
      - { text: "Singleton and thread-safety are unrelated concepts", correct: false }
    explanation: "The null-check-then-create sequence isn't atomic. Two threads can both pass the null check before either finishes constructing, producing two 'singleton' instances — exactly the race condition the concurrency module covered."
  - id_key: factory-purpose
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "What problem does the Factory pattern solve?"
    multiple: false
    options:
      - { text: "It centralizes object-creation logic so calling code doesn't need to know which concrete subtype to instantiate", correct: true }
      - { text: "It makes classes immutable" }
      - { text: "It replaces the need for constructors entirely" }
      - { text: "It's only useful for creating Singletons" }
    explanation: "A Factory encapsulates the decision of which concrete class to instantiate, so callers depend on an interface/supertype and a creation method rather than on every concrete subtype's constructor directly."
  - id_key: builder-vs-telescoping-constructors
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "What problem does the Builder pattern solve that a class with many optional constructor parameters runs into?"
    multiple: false
    options:
      - { text: "It avoids 'telescoping constructors' — many overloaded constructors for every combination of optional fields — by letting callers set only the fields they care about, fluently, before building" , correct: true }
      - { text: "It makes a class's fields public" , correct: false }
      - { text: "It eliminates the need for a class to have any fields" , correct: false }
      - { text: "It's required for every Java class regardless of parameter count" , correct: false }
    explanation: "Builder trades a combinatorial explosion of overloaded constructors for one fluent, readable construction path, especially valuable once several fields are optional."
  - id_key: observer-purpose
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "In the Observer pattern, what is the relationship between the subject (e.g. a Task) and its observers (e.g. TaskListeners)?"
    multiple: false
    options:
      - { text: "The subject holds a list of observers and notifies all of them when relevant state changes, without needing to know what each observer does with that notification" , correct: true }
      - { text: "Each observer directly modifies the subject's private fields" , correct: false }
      - { text: "Only one observer may be registered at a time" , correct: false }
      - { text: "Observers poll the subject continuously instead of being notified" , correct: false }
    explanation: "Observer decouples the subject from the specific reactions its observers take — the subject just announces \"this changed,\" and each observer decides independently how to react."
  - id_key: strategy-vs-if-else
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "How does the Strategy pattern improve on a method full of if/else branches choosing behavior by a type flag?"
    multiple: false
    options:
      - { text: "It encapsulates each behavior as its own class implementing a common interface, so adding a new behavior means adding a new class instead of editing an existing method (Open/Closed in practice)" , correct: true }
      - { text: "It removes the need for interfaces entirely" , correct: false }
      - { text: "It only works with numeric comparisons" , correct: false }
      - { text: "It requires fewer classes than an if/else chain" , correct: false }
    explanation: "Strategy turns \"which behavior\" into \"which object,\" letting new behaviors be added as new classes without touching the code that uses them — a direct, practical example of the Open/Closed Principle from this module's first lesson."
  - id_key: design-patterns-builder-coding
    type: coding
    difficulty: intermediate
    points: 3
    prompt: >-
      Using a Builder-style class, construct a simple report line. Read a task name and an integer hours value
      from one line of stdin, space-separated (the name has no spaces). Build the output using method chaining
      on a small builder class with methods like withName(...) and withHours(...) and a build() method that
      returns a formatted String, then print exactly: "<name>: <hours>h" (e.g. "Deploy: 6h").
    languages: [java]
    starter_code:
      java: |
        import java.util.Scanner;

        public class Main {
            static class ReportBuilder {
                private String name;
                private int hours;

                ReportBuilder withName(String name) {
                    this.name = name;
                    return this;
                }

                ReportBuilder withHours(int hours) {
                    this.hours = hours;
                    return this;
                }

                String build() {
                    return name + ": " + hours + "h";
                }
            }

            public static void main(String[] args) {
                Scanner scanner = new Scanner(System.in);
                // Read a task name and an integer hours value from one line, then
                // use ReportBuilder via method chaining to build and print the report line.

            }
        }
    test_cases:
      - { stdin: "Deploy 6", expected: "Deploy: 6h", hidden: false, weight: 1 }
      - { stdin: "Design 3", expected: "Design: 3h", hidden: true, weight: 1 }
      - { stdin: "Review 0", expected: "Review: 0h", hidden: true, weight: 1 }
    explanation: "Each with*() method returns `this`, enabling the fluent chain new ReportBuilder().withName(name).withHours(hours).build() — the defining shape of the Builder pattern."
  - id_key: design-patterns-reflection
    type: subjective
    difficulty: beginner
    points: 2
    prompt: >-
      In your own words: which pattern from this module (Singleton, Factory, Builder, Observer, or Strategy)
      felt least intuitive, and why? Be specific about what confused you — this feeds directly into what gets
      flagged for review.
    multiple: false
    options: []
    explanation: "Graded for genuine, specific reflection rather than a single correct answer — the goal is to surface which pattern you're actually shakiest on."
---
