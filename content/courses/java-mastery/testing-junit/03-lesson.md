---
kind: lesson
id_key: java-mastery/testing-junit/mocking-concept
course: java-mastery
section: testing-junit
section_title: "Testing with JUnit"
section_position: 16
title: "The Idea of Mocking"
position: 2
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
Suppose `TaskService.markComplete(...)` should also send a notification email when a task finishes. Testing that directly means either actually sending an email every time the test suite runs (slow, unreliable, and genuinely emails someone every CI run), or finding another way to verify "the service *tried* to notify" without a real email service in the loop. That's the problem mocking solves.

## The dependency problem

```java
public class Main {
    interface NotificationService {
        void sendTaskCompleteNotification(String taskName);
    }

    static class RealEmailNotificationService implements NotificationService {
        public void sendTaskCompleteNotification(String taskName) {
            // In real code: connects to an SMTP server and sends an actual email.
            System.out.println("Sending real email for: " + taskName);
        }
    }

    static class TaskService {
        private final NotificationService notifications;
        TaskService(NotificationService notifications) {
            this.notifications = notifications;
        }
        void markComplete(String taskName) {
            notifications.sendTaskCompleteNotification(taskName);
        }
    }

    public static void main(String[] args) {
        TaskService service = new TaskService(new RealEmailNotificationService());
        service.markComplete("Deploy to prod"); // would send a real email in production
    }
}
```

`TaskService` depends on `NotificationService` through the **interface**, not a concrete email class directly — this is exactly the "program to an interface" principle from the OOP and design-patterns modules, and it's what makes the dependency swappable at all. A class that directly `new`s a concrete `RealEmailNotificationService` inside itself would have no seam to substitute anything at test time.

## A hand-rolled fake

Because `TaskService` depends on the `NotificationService` interface, a test can hand it a completely different implementation — one that just *records* what it was asked to do instead of actually doing it:

```java
public class Main {
    interface NotificationService {
        void sendTaskCompleteNotification(String taskName);
    }

    static class TaskService {
        private final NotificationService notifications;
        TaskService(NotificationService notifications) {
            this.notifications = notifications;
        }
        void markComplete(String taskName) {
            notifications.sendTaskCompleteNotification(taskName);
        }
    }

    // A fake used only in tests: implements the same interface, but records
    // calls instead of sending anything real. No network, no SMTP, no
    // side effects outside this object's own memory.
    static class FakeNotificationService implements NotificationService {
        java.util.List<String> notifiedTasks = new java.util.ArrayList<>();

        public void sendTaskCompleteNotification(String taskName) {
            notifiedTasks.add(taskName);
        }
    }

    public static void main(String[] args) {
        FakeNotificationService fake = new FakeNotificationService();
        TaskService service = new TaskService(fake);

        service.markComplete("Deploy to prod");

        // Verify the service TRIED to notify, without sending a real email:
        boolean notified = fake.notifiedTasks.contains("Deploy to prod");
        System.out.println("Notified: " + notified);
    }
}
```

Run it — the fake proves `markComplete` reached out to notify, entirely in-memory, in milliseconds, with zero real emails sent. This hand-rolled `FakeNotificationService` *is* a mock, conceptually — it just doesn't use a mocking library to generate itself.

## Why not just use the real thing in tests?

- **Speed**: a real email/network/database call is orders of magnitude slower than an in-memory fake — multiply that by thousands of tests in a CI pipeline.
- **Reliability**: a test that depends on a real external service fails whenever that service is slow, down, or rate-limits you — for reasons that have nothing to do with whether your code is actually correct.
- **Side effects**: you don't want "run the test suite" to mean "send real emails to real people," charge a real payment API, or write to a real production database.
- **Isolation**: a unit test for `TaskService` should fail only when `TaskService`'s own logic is wrong — not when an unrelated email server happens to be down. That's what makes it a *unit* test rather than an integration test.

## Mocking libraries (the concept, not the syntax)

In a real Maven/Gradle project, you'd typically reach for a library like **Mockito** instead of hand-writing a `Fake*` class for every dependency — it generates fakes on the fly and lets you assert things like "was `sendTaskCompleteNotification` called exactly once, with this argument?" without writing a recording list by hand. The library-generated version and the hand-rolled `FakeNotificationService` above solve the *exact same problem*; Mockito is just less boilerplate once you have many dependencies to fake across many tests. Understanding the hand-rolled version first is what makes the library version make sense — it's the same idea with the bookkeeping automated.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "testing-junit-mocking-concept-q1",
      "type": "mcq",
      "prompt": "Why does TaskService depending on a NotificationService interface (rather than a concrete email class) matter for testing?",
      "options": [
        { "id": "a", "text": "It doesn't matter — interfaces have no effect on testability" },
        { "id": "b", "text": "It creates a seam: a test can substitute a fake implementation without changing TaskService's code at all" },
        { "id": "c", "text": "Interfaces make code run faster at runtime" },
        { "id": "d", "text": "It's only relevant for classes with more than one method" }
      ],
      "correct": "b",
      "explanation": "Depending on an interface rather than a concrete class is exactly what allows a test to inject a fake — this is the same 'program to an interface' principle the OOP and design-patterns modules covered, applied specifically to testability."
    },
    {
      "id": "testing-junit-mocking-concept-q2",
      "type": "mcq",
      "prompt": "What is the main reason to avoid hitting a real email/network service inside a unit test?",
      "options": [
        { "id": "a", "text": "Real services are always broken" },
        { "id": "b", "text": "Speed, reliability, avoiding real side effects, and keeping the test's pass/fail tied only to the code actually under test — not an unrelated external system" },
        { "id": "c", "text": "Unit tests are technically forbidden from calling any method at all" },
        { "id": "d", "text": "There's no real reason — it's purely a style preference" }
      ],
      "correct": "b",
      "explanation": "A slow, flaky, or side-effecting dependency in a unit test undermines the whole point of testing: fast, reliable, isolated verification of one unit's own logic."
    },
    {
      "id": "testing-junit-mocking-concept-q3",
      "type": "mcq",
      "prompt": "What does a mocking library like Mockito fundamentally provide, compared to hand-writing a Fake* class?",
      "options": [
        { "id": "a", "text": "A completely different concept unrelated to fakes" },
        { "id": "b", "text": "The same underlying idea — a substitutable implementation for tests — generated automatically instead of hand-written, reducing boilerplate as the number of dependencies grows" },
        { "id": "c", "text": "It removes the need for interfaces" },
        { "id": "d", "text": "It only works with database dependencies" }
      ],
      "correct": "b",
      "explanation": "Mocking libraries automate exactly what a hand-rolled fake does manually: substituting a dependency and recording/verifying how it was used, at scale, without writing a new Fake* class for every dependency in every test."
    }
  ]
}
```

## What's next

That closes out testing. The final content module, **Build Tools**, covers how a real TaskFlow project — with JUnit, and every other dependency this course has touched — actually gets built, packaged, and its dependencies managed via Maven and Gradle.
