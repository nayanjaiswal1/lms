---
kind: lesson
id_key: java-mastery/oop-advanced/abstract-and-interfaces
course: java-mastery
section: oop-advanced
section_title: "Advanced OOP"
section_position: 4
title: "Abstract Classes and Interfaces"
position: 2
estimated_minutes: 25
source: [java-mastery-curriculum.md]
---
Inheritance so far has meant "reuse a concrete class's implementation." Sometimes you want to describe a **contract** — a set of behaviors something must support — without committing to how it's implemented, or without forcing unrelated classes into the same inheritance tree. Java gives you two tools for this: **abstract classes** and **interfaces**.

## Interfaces: a pure contract

```java
public class Main {
    public static void main(String[] args) {
        User user = new User("Priya");
        user.notify("You've been assigned: Fix login bug");
    }
}

interface Notifiable {
    void notify(String message); // abstract — every implementer must define this

    default void notifyUrgently(String message) {
        notify("URGENT: " + message); // default method — shared, but overridable
    }
}

class User implements Notifiable {
    private String username;

    User(String username) {
        this.username = username;
    }

    @Override
    public void notify(String message) {
        System.out.println("[to " + username + "] " + message);
    }
}
```

`interface Notifiable` declares `notify(String message)` with no body — any class that `implements Notifiable` **must** provide one, or it won't compile. This is a pure capability contract: "anything `Notifiable` can be told something," with zero assumption about how. `notifyUrgently` is a **default method** (added in Java 8) — it has a body, so implementers get it for free without writing it themselves, though they can still override it if they need different behavior.

## Abstract classes: partial implementation

```java
public class Main {
    public static void main(String[] args) {
        NotificationChannel channel = new EmailChannel("oncall@taskflow.dev");
        channel.dispatch("Database failover triggered");
    }
}

abstract class NotificationChannel {
    private String destination;

    NotificationChannel(String destination) {
        this.destination = destination;
    }

    // Concrete method — shared by every channel, no need to reimplement it
    void dispatch(String message) {
        System.out.println("Dispatching to " + destination + "...");
        send(message);
    }

    // Abstract method — each channel must define how it actually sends
    abstract void send(String message);
}

class EmailChannel extends NotificationChannel {
    EmailChannel(String destination) {
        super(destination);
    }

    @Override
    void send(String message) {
        System.out.println("EMAIL: " + message);
    }
}
```

`abstract class NotificationChannel` mixes both worlds: `dispatch(...)` is a normal concrete method with a body, shared by every subclass exactly as written; `send(...)` is `abstract` — no body, and every concrete subclass must supply one, same as an interface method. The difference from an interface is that `NotificationChannel` also has state (`destination`) and a constructor, and it can share real, reusable logic (`dispatch`'s two-line implementation) rather than just declaring a contract. `new NotificationChannel("...")` would be a compile error — an abstract class can never be instantiated directly, only through a concrete subclass like `EmailChannel`.

## Choosing between them

| | Abstract class | Interface |
|---|---|---|
| Instantiable? | Never | Never |
| Fields with state? | Yes | No instance fields (only constants) |
| Constructor? | Yes | No |
| A class can extend/implement how many? | One abstract class (single inheritance) | Any number of interfaces |
| Use when... | Related classes share real implementation and state, not just a signature | Unrelated classes need to share one capability, regardless of their place in the class hierarchy |

`Task` and `UrgentTask` sharing a constructor and fields — that's the abstract-class shape. `User`, `Team`, and `UrgentTask` all being able to receive a notification, despite having nothing else in common — that's the interface shape, and it's exactly why a class can implement several interfaces at once but extend only one class:

```java
public class Main {
    public static void main(String[] args) {
        UrgentTask task = new UrgentTask("Payment gateway down", "oncall@taskflow.dev");
        task.notify("New urgent task assigned");
        task.log("Task created");
    }
}

interface Notifiable {
    void notify(String message);
}

interface Loggable {
    void log(String entry);
}

class UrgentTask implements Notifiable, Loggable {
    private String name;
    private String escalationContact;

    UrgentTask(String name, String escalationContact) {
        this.name = name;
        this.escalationContact = escalationContact;
    }

    @Override
    public void notify(String message) {
        System.out.println("[to " + escalationContact + "] " + message);
    }

    @Override
    public void log(String entry) {
        System.out.println("[LOG] " + name + ": " + entry);
    }
}
```

`UrgentTask implements Notifiable, Loggable` picks up both contracts at once — something no `extends` clause could do, since Java only allows extending one superclass. Interfaces let unrelated capabilities compose freely; abstract classes let closely related classes share real code.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-advanced-abstract-and-interfaces-q1",
      "type": "mcq",
      "prompt": "Can you write `new NotificationChannel(\"oncall@taskflow.dev\")` if NotificationChannel is declared abstract?",
      "options": [
        { "id": "a", "text": "Yes, abstract only affects subclassing, not instantiation" },
        { "id": "b", "text": "No — abstract classes can never be instantiated directly, only through a concrete subclass" },
        { "id": "c", "text": "Yes, but only if the class has no abstract methods" },
        { "id": "d", "text": "It depends on whether the constructor is public" }
      ],
      "correct": "b",
      "explanation": "An abstract class is explicitly incomplete — it may have unimplemented (abstract) methods — so the compiler forbids instantiating it directly. Only a concrete subclass that implements every abstract method can be instantiated."
    },
    {
      "id": "oop-advanced-abstract-and-interfaces-q2",
      "type": "mcq",
      "prompt": "How many interfaces can a single class implement, compared to how many classes it can extend?",
      "options": [
        { "id": "a", "text": "Exactly one of each" },
        { "id": "b", "text": "Any number of interfaces, but only one superclass" },
        { "id": "c", "text": "Any number of both" },
        { "id": "d", "text": "Only one interface, but any number of superclasses" }
      ],
      "correct": "b",
      "explanation": "Java supports single inheritance of classes (extends one superclass) but multiple implementation of interfaces (implements as many as needed) — this is exactly why interfaces are the tool for giving unrelated classes a shared capability."
    },
    {
      "id": "oop-advanced-abstract-and-interfaces-q3",
      "type": "mcq",
      "prompt": "When should you reach for an abstract class instead of an interface?",
      "options": [
        { "id": "a", "text": "Never — interfaces should always be preferred in modern Java" },
        { "id": "b", "text": "When a group of closely related classes needs to share real implementation and instance state, not just a method signature" },
        { "id": "c", "text": "When you need a class to implement more than one contract at once" },
        { "id": "d", "text": "Abstract classes and interfaces are fully interchangeable, so it never matters" }
      ],
      "correct": "b",
      "explanation": "Abstract classes can hold constructors, fields, and concrete methods that subclasses inherit as-is — useful when related classes genuinely share implementation, not just a contract, which is exactly what interfaces can't provide."
    }
  ]
}
```

## What's next

The final lesson in this module covers the contract every Java object inherits — `equals()`, `hashCode()`, and `toString()` — including why overriding one without the other silently breaks `HashSet` and `HashMap`, plus **enums**, for a fixed, type-safe set of values like a task's status.
