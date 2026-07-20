---
kind: lesson
id_key: java-mastery/interview-ready/design-and-modern-java-theory
course: java-mastery
section: interview-ready
section_title: "Interview Ready"
section_position: 18
title: "Design & Modern Java Theory"
position: 3
estimated_minutes: 35
source: [java-mastery-curriculum.md]
---
This lesson pressure-tests design judgment and modern-Java awareness — the questions interviewers ask to see whether you've internalized *why* certain choices are good, not just whether you can define a term.

## "Explain SOLID — and give me a concrete violation and fix"

Naming all five letters gets you nowhere in an interview if you can't back at least two of them with a real example. Two that come up constantly:

**Single Responsibility Principle.** *Violation*: a `TaskService` class that both persists tasks to a database AND formats them into HTML for an email digest. Change the email template, and you risk breaking persistence code in the same file, reviewed by the same diff. *Fix*: split into `TaskRepository` (persistence) and `TaskEmailFormatter` (presentation) — each has exactly one reason to change.

**Open/Closed Principle.** *Violation*: a `calculatePriorityScore(Task task)` method with an `if/else if` chain keyed on `task.getType()`, requiring an edit to this method every time a new task type is added. *Fix*: the Strategy pattern from the design-patterns module — a `PriorityStrategy` interface with one implementation per task type, so adding a new type means adding a new class, never touching the existing ones.

Being ready to state — out loud, unprompted — "here's a violation I've actually reasoned through, and here's the fix" is worth more than reciting all five initials correctly.

```java
public class Main {
    // Violation: mixes calculation logic with formatting, and needs editing
    // for every new priority rule.
    static String badReport(int hours, boolean urgent) {
        String score;
        if (urgent && hours > 8) {
            score = "CRITICAL";
        } else if (urgent) {
            score = "HIGH";
        } else if (hours > 8) {
            score = "MEDIUM";
        } else {
            score = "LOW";
        }
        return "Priority: " + score; // formatting logic mixed in here too
    }

    public static void main(String[] args) {
        System.out.println(badReport(10, true));
    }
}
```

## "Why favor composition over inheritance?"

Inheritance couples a subclass to its superclass's implementation, not just its interface — a change to a base class can silently break every subclass, even ones the base class's author never anticipated (the classic "fragile base class" problem). It also only allows a single line of extension in Java (no multiple inheritance of classes), forcing awkward hierarchies when a class genuinely needs multiple unrelated capabilities.

**Composition** — a class *holding a reference* to another class and delegating to it, rather than extending it — avoids both problems: you can compose as many capabilities as needed, and each collaborator can be swapped independently (this is exactly what made the mocking lesson's `NotificationService` substitutable). The interview-ready answer: "favor composition over inheritance" doesn't mean *never* use inheritance — the OOP module's `Task`/`UrgentTask` relationship is a legitimate is-a relationship — it means reach for inheritance only when the relationship is genuinely "is-a," and reach for composition ("has-a") for everything else, especially cross-cutting capabilities like logging, notification, or persistence strategy.

## "When are records the right tool — and when aren't they?"

Right tool: immutable data carriers — DTOs crossing a service boundary, value objects like a `Coordinate` or `Money` amount, or event types in a sealed hierarchy (`TaskCreated`, `TaskCompleted`). Wrong tool: anything with state that's meant to mutate over its lifetime (a `Task` whose `status` genuinely transitions in place), or anything that needs to participate in an inheritance hierarchy as a subclass of another concrete class (records are implicitly final and cannot extend a class). A sharp interview answer distinguishes "this type represents a value" from "this type represents an entity with a lifecycle" — records are for the former.

## "What is a functional interface, and why do lambdas need one?"

A **functional interface** is any interface with exactly one abstract method (it can have any number of `default`/`static` methods, those don't count). A lambda expression is just syntactic sugar for "an anonymous implementation of a functional interface's single abstract method" — the compiler infers which functional interface a lambda targets from the assignment context. This is *why* `Comparator<T>` (one abstract method: `compare`), `Runnable` (one abstract method: `run`), and your own `@FunctionalInterface`-annotated types can all be implemented with a lambda, while an interface with two abstract methods cannot — there'd be no unambiguous way to know which method the lambda's body is implementing.

```java
public class Main {
    @FunctionalInterface
    interface TaskFilter {
        boolean test(String taskName);
    }

    static void printMatching(String[] tasks, TaskFilter filter) {
        for (String t : tasks) {
            if (filter.test(t)) System.out.println(t);
        }
    }

    public static void main(String[] args) {
        String[] tasks = { "Deploy to prod", "Design schema", "Deprecate old API" };
        // The lambda below IS an implementation of TaskFilter's single abstract method.
        printMatching(tasks, name -> name.startsWith("De"));
    }
}
```

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "interview-ready-design-modern-q1",
      "type": "mcq",
      "prompt": "What is the 'fragile base class' problem that motivates favoring composition over inheritance?",
      "options": [
        { "id": "a", "text": "Base classes are always slower at runtime than composed objects" },
        { "id": "b", "text": "A change to a base class's implementation can silently break subclasses the base class's author never anticipated, since subclasses are coupled to implementation, not just interface" },
        { "id": "c", "text": "Java forbids more than one level of inheritance" },
        { "id": "d", "text": "Base classes cannot have private fields" }
      ],
      "correct": "b",
      "explanation": "Inheritance couples a subclass to its superclass's internals in ways that aren't always visible at the call site, making base-class changes riskier than changes to a composed, interface-bound collaborator."
    },
    {
      "id": "interview-ready-design-modern-q2",
      "type": "mcq",
      "prompt": "Which scenario is the best fit for a record?",
      "options": [
        { "id": "a", "text": "An immutable event type like TaskCompleted(String taskName, int actualHours) used in a sealed event hierarchy" },
        { "id": "b", "text": "A Task entity whose status field is meant to mutate in place as work progresses" },
        { "id": "c", "text": "A class that must extend another concrete class" },
        { "id": "d", "text": "A class requiring custom getX()-style accessor names for an existing API contract" }
      ],
      "correct": "a",
      "explanation": "Records are for immutable values — an event describing something that already happened is a textbook fit, since it never needs to change after construction."
    },
    {
      "id": "interview-ready-design-modern-q3",
      "type": "mcq",
      "prompt": "Why can an interface with two abstract methods NOT be implemented with a lambda?",
      "options": [
        { "id": "a", "text": "Lambdas can only be used with classes, never interfaces" },
        { "id": "b", "text": "A lambda's body implements exactly one method, so the compiler would have no unambiguous way to know which of the two abstract methods it's implementing" },
        { "id": "c", "text": "Java forbids interfaces from having more than one method entirely" },
        { "id": "d", "text": "It can be — this restriction doesn't actually exist" }
      ],
      "correct": "b",
      "explanation": "A functional interface's single-abstract-method constraint exists precisely so a lambda has one unambiguous target to implement — this is the formal definition behind why Runnable and Comparator work with lambdas and a two-method interface doesn't."
    }
  ]
}
```

## What's next

The final lesson closes the loop: not what to know, but how to *talk through* what you know under interview pressure.
