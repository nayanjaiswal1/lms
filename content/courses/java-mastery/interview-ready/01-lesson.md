---
kind: lesson
id_key: java-mastery/interview-ready/core-language-oop-theory
course: java-mastery
section: interview-ready
section_title: "Interview Ready"
section_position: 18
title: "Core Language & OOP Theory"
position: 0
estimated_minutes: 35
source: [java-mastery-curriculum.md]
---
You've written TaskFlow's core objects, wired up inheritance and interfaces, and handled exceptions across earlier modules. This module assumes all of that and does something different with it: it drills the exact questions interviewers ask about those same topics, with the full reasoning behind each answer — not just the one-line fact, but *why* it's true and what follow-up an interviewer typically asks next. Five lessons, one theme each, all still built on TaskFlow.

## "What's the difference between `==` and `.equals()`?"

This is close to the single most-asked Java question there is, and the reason it keeps getting asked is that a shallow answer ("`==` checks equality, `.equals()` also checks equality") misses the actual point.

`==` on object references compares **identity** — are these two variables pointing at the exact same object in memory? `.equals()`, by contrast, is a regular method, inherited from `Object`, and its default implementation *also* just does `==` — unless a class overrides it to compare something else, like field-by-field content.

```java
public class Main {
    static class Task {
        private final String name;

        Task(String name) {
            this.name = name;
        }

        @Override
        public boolean equals(Object other) {
            if (this == other) return true;
            if (!(other instanceof Task)) return false;
            Task task = (Task) other;
            return name.equals(task.name);
        }
    }

    public static void main(String[] args) {
        Task a = new Task("Design database schema");
        Task b = new Task("Design database schema");

        System.out.println(a == b);        // false — two different objects on the heap
        System.out.println(a.equals(b));   // true — Task overrides equals() to compare content

        String s1 = "Deploy";
        String s2 = "Deploy";
        System.out.println(s1 == s2);      // true — string literals are interned, same pooled object
    }
}
```

The `String` case at the bottom is the classic trap: `s1 == s2` prints `true` for two `String` **literals** because of string interning (more on that below), which leads beginners to believe `==` works fine on `String`s — until they compare a literal against a `new String("Deploy")` or a value built with concatenation at runtime, where `==` reliably breaks. The rule to say out loud: **always use `.equals()` to compare object content, `==` only when you genuinely mean "is this the same object."**

## "If you override `equals()`, why do you also need to override `hashCode()`?"

This is the natural follow-up, and it trips people up because the connection isn't obvious from the method signatures alone. The contract, straight from `Object`'s Javadoc, is: **if two objects are equal according to `.equals()`, they must return the same value from `.hashCode()`.** Nothing requires the reverse — unequal objects *can* share a hash code (a "collision," which hash-based collections are built to handle) — but equal objects sharing different hash codes breaks things silently.

Here's the concrete failure. `HashSet` and `HashMap` use `hashCode()` first to pick a bucket, then `equals()` only to compare against other entries *already in that bucket*:

```java
import java.util.HashSet;
import java.util.Objects;

public class Main {
    static class Task {
        private final String name;

        Task(String name) {
            this.name = name;
        }

        @Override
        public boolean equals(Object other) {
            if (this == other) return true;
            if (!(other instanceof Task)) return false;
            return name.equals(((Task) other).name);
        }

        // Deliberately omitted in the broken version — see the comment below.
        @Override
        public int hashCode() {
            return Objects.hash(name);
        }
    }

    public static void main(String[] args) {
        HashSet<Task> seen = new HashSet<>();
        seen.add(new Task("Design database schema"));

        boolean containsDuplicate = seen.contains(new Task("Design database schema"));
        System.out.println("Duplicate detected: " + containsDuplicate); // true, with hashCode() overridden correctly
    }
}
```

With `hashCode()` overridden consistently with `equals()` (both based on `name`), the second `Task` lands in the *same bucket* as the first, `equals()` confirms they match, and `contains()` correctly reports `true`. Delete the `hashCode()` override and the two logically-equal `Task` objects fall into different (essentially random, identity-based) buckets — `contains()` would report `false` even though `.equals()` would say `true` if you called it directly. That's the bug: silently broken deduplication, with no compiler warning, because nothing *requires* you to override `hashCode()` alongside `equals()` — it's a contract enforced by convention and by every hash-based collection's behavior, not by the compiler.

## Abstract class vs. interface — going deeper

You've seen both in the OOP module; the interview version of this question wants you to articulate the decision, not just the syntax difference. Three angles worth having ready:

1. **State.** An abstract class can hold instance fields and constructors — shared, mutable state that every subclass inherits. An interface (even with default methods) fundamentally cannot hold instance state; it can only declare behavior.
2. **Multiple inheritance.** A Java class can implement any number of interfaces but extend only one class. If TaskFlow needs a `Task` to be both `Comparable<Task>` and `Serializable` and `Auditable`, those must be interfaces — a class literally cannot extend more than one superclass.
3. **The real decision rule:** ask "is this an *is-a* relationship with shared implementation and state?" — use an abstract class (a `RecurringTask extends Task` sharing `name`, `id`, and completion logic). Ask "is this a *capability* that unrelated classes might all support?" — use an interface (`Comparable<Task>`, `Auditable` — a `Task`, a `Project`, and a `User` might all be `Auditable` despite sharing no inheritance relationship at all).

```java
public class Main {
    interface Auditable {
        String auditSummary(); // capability: "can produce an audit trail entry"
    }

    static abstract class Task implements Auditable {
        protected final String name; // shared state

        Task(String name) {
            this.name = name;
        }

        abstract boolean isOverdue(); // subclasses must define this differently

        @Override
        public String auditSummary() { // shared implementation, inherited by every subclass
            return "Task[" + name + "] overdue=" + isOverdue();
        }
    }

    static class RecurringTask extends Task {
        RecurringTask(String name) {
            super(name);
        }

        @Override
        boolean isOverdue() {
            return false; // recurring tasks reset instead of going overdue
        }
    }

    public static void main(String[] args) {
        Task t = new RecurringTask("Weekly status report");
        System.out.println(t.auditSummary());
    }
}
```

`RecurringTask` inherits `name` and the shared `auditSummary()` logic from the abstract class, while `Auditable` describes a capability that any other unrelated class (`Project`, `User`) could implement too, without joining `Task`'s inheritance hierarchy at all.

## How overload resolution actually works

`System.out.println` has a dozen overloads — `println(int)`, `println(String)`, `println(Object)`, and so on — and the compiler picks one **at compile time**, based on the static (declared) types of the arguments, not their runtime values. The resolution order, roughly:

1. **Exact match** — an overload whose parameter types exactly match the argument types.
2. **Widening primitive conversion** — `int` → `long`, `float` → `double`, etc., if no exact match exists.
3. **Autoboxing** — `int` → `Integer`, if no widening match exists either.
4. **Varargs** — `Object...`-style overloads are tried last, only if nothing else matches.

```java
public class Main {
    static void logPriority(int priority) {
        System.out.println("int overload: " + priority);
    }

    static void logPriority(long priority) {
        System.out.println("long overload: " + priority);
    }

    static void logPriority(Object priority) {
        System.out.println("Object overload: " + priority);
    }

    public static void main(String[] args) {
        byte b = 5;
        logPriority(b); // widens byte -> int: picks the int overload, not long or Object
    }
}
```

`byte` has no exact-match overload here, so the compiler widens it — and stops at the *first* widening conversion that produces a match (`byte` → `int`), never considering autoboxing to `Byte`/`Object` at all, because a valid match was already found at the widening stage. This is exactly the kind of thing an interviewer asks to see if you understand it's a **compile-time, static-type decision** — unlike overriding, which resolves at runtime based on the object's actual class.

## Checked vs. unchecked exceptions, the interview framing

You covered the mechanics earlier in the course: checked exceptions (subclasses of `Exception`, not `RuntimeException`) must be caught or declared, unchecked ones don't have to be. The interview-level follow-up is usually "so which should *you* use when you design a new exception type for TaskFlow?" The honest, opinionated answer most experienced Java developers give: prefer unchecked exceptions for your own APIs unless the caller has a genuine, reasonable way to *recover* from the failure at the call site. Checked exceptions that just get caught and rethrown, or swallowed with an empty `catch` block, are worse than no exception handling at all — they add ceremony (`throws` clauses cascading up every method signature) without adding real safety, and empty `catch` blocks are one of the most common ways real bugs get silently hidden.

## Why `String` is immutable, and why that matters

A `String`'s backing character data cannot be changed after construction — every "modifying" method (`substring`, `concat`, `toUpperCase`, ...) returns a **new** `String` rather than mutating the original. Three concrete reasons this matters, all worth having ready in an interview:

- **The string pool.** Because `String`s are immutable, the JVM can safely have many variables share one underlying object for identical literals (`"Deploy"` from two different places in your code is the same pooled object) — that sharing would be unsafe if any one reference could mutate the shared data out from under the others.
- **Thread-safety.** An immutable object can be freely shared across threads with zero synchronization, because there's no mutation to race on. `Task` names, `User` usernames — anything modeled as `String` — never needs a lock just to be read concurrently.
- **Security and reliability.** `String` is used constantly for things like file paths, class names, and network hosts. If `String` were mutable, code that validated a value and then handed it to something else (e.g., a security check followed by a file open) could have the value changed out from under it between the check and the use — immutability closes that entire class of bug.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "interview-ready-core-language-oop-theory-q1",
      "type": "mcq",
      "prompt": "Why does contains() on a HashSet<Task> silently return false for a logically-equal Task if equals() is overridden but hashCode() is not?",
      "options": [
        { "id": "a", "text": "HashSet ignores equals() entirely and only ever uses ==" },
        { "id": "b", "text": "Without a matching hashCode() override, the two equal objects land in different buckets, so equals() is never even called to compare them" },
        { "id": "c", "text": "hashCode() is required by the compiler whenever equals() is overridden, so this scenario cannot compile" },
        { "id": "d", "text": "HashSet always returns false for custom objects regardless of equals()" }
      ],
      "correct": "b",
      "explanation": "HashSet/HashMap use hashCode() to pick a bucket first and only call equals() against objects already in that bucket. If hashCode() isn't overridden consistently with equals(), two equal objects can land in different buckets and never get compared at all."
    },
    {
      "id": "interview-ready-core-language-oop-theory-q2",
      "type": "mcq",
      "prompt": "Which factor most directly forces you to use an interface instead of an abstract class in Java?",
      "options": [
        { "id": "a", "text": "The need for shared instance state across subclasses" },
        { "id": "b", "text": "The need for a constructor" },
        { "id": "c", "text": "The need for one class to inherit multiple unrelated capabilities, since a class can implement many interfaces but extend only one class" },
        { "id": "d", "text": "Interfaces compile faster than abstract classes" }
      ],
      "correct": "c",
      "explanation": "Java allows single inheritance of classes but multiple implementation of interfaces. When a class needs to be Comparable, Auditable, and Serializable simultaneously, those capabilities must be interfaces — an abstract class slot is limited to one."
    },
    {
      "id": "interview-ready-core-language-oop-theory-q3",
      "type": "mcq",
      "prompt": "Overload resolution in Java (choosing between logPriority(int), logPriority(long), logPriority(Object)) happens:",
      "options": [
        { "id": "a", "text": "At runtime, based on the actual value passed in" },
        { "id": "b", "text": "At compile time, based on the static/declared type of the argument, preferring exact match, then widening, then autoboxing, then varargs" },
        { "id": "c", "text": "Randomly, whichever overload is declared first in the file" },
        { "id": "d", "text": "At runtime, based on which overload was called most recently" }
      ],
      "correct": "b",
      "explanation": "Overload resolution is entirely a compile-time decision based on static types, following a fixed preference order: exact match, then widening primitive conversion, then autoboxing, then varargs — unlike overriding, which resolves dynamically at runtime."
    },
    {
      "id": "interview-ready-core-language-oop-theory-q4",
      "type": "mcq",
      "prompt": "Which of these is NOT a direct benefit of String's immutability?",
      "options": [
        { "id": "a", "text": "Multiple references can safely share the same pooled String literal" },
        { "id": "b", "text": "Strings can be shared across threads with no synchronization" },
        { "id": "c", "text": "A value cannot be changed out from under code that already validated it" },
        { "id": "d", "text": "String comparisons with == always work correctly for any two Strings with equal content" }
      ],
      "correct": "d",
      "explanation": "== only reliably matches for interned literals sharing the same pooled object — a String built at runtime (e.g. via concatenation or new String(...)) with identical content can still fail == against a literal. .equals() is still required for correct content comparison; immutability doesn't change that fact."
    }
  ]
}
```

## What's next

Next up: the Collections Framework and generics, at the depth interviewers actually probe — HashMap internals, Big-O tradeoffs, and what type erasure really means at runtime.
