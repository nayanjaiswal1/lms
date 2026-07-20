---
kind: lesson
id_key: java-mastery/testing-junit/junit-basics
course: java-mastery
section: testing-junit
section_title: "Testing with JUnit"
section_position: 16
title: "Why Automated Tests Matter & JUnit 5 Basics"
position: 0
estimated_minutes: 25
source: [java-mastery-curriculum.md]
---
Every TaskFlow example so far has been verified by eyeballing printed output. That works for a 20-line example. It does not work for a real codebase: once TaskFlow has dozens of classes and someone changes `TaskService`, how do you know they didn't silently break `markComplete()` while fixing something else? **Automated tests** answer that question in seconds, every time, without a human re-checking by hand.

## What a unit test actually is

A unit test calls one small piece of your code with known inputs and asserts the output is what you expect — and it either passes silently or fails loudly, with no manual inspection required. **JUnit 5** is the standard testing framework for Java.

Here's the production code being tested — a small `TaskService`:

```java
public class Main {
    static class Task {
        String name;
        boolean complete;
        Task(String name) { this.name = name; this.complete = false; }
    }

    static class TaskService {
        boolean markComplete(Task task) {
            if (task == null) {
                throw new IllegalArgumentException("task cannot be null");
            }
            task.complete = true;
            return task.complete;
        }
    }

    public static void main(String[] args) {
        Task t = new Task("Deploy to prod");
        TaskService service = new TaskService();
        System.out.println(service.markComplete(t));
        System.out.println(t.complete);
    }
}
```

**Note on this lesson's code:** the block below shows real, idiomatic JUnit 5 test code — the shape you'd actually write in a Maven/Gradle project with the `junit-jupiter` dependency (see the Build Tools module). It is *not* directly executable in this course's plain-`Main`-class code runner, since that requires a JUnit test runner, not `java Main`. Read it for the pattern, not to hit Run on it:

```java
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class TaskServiceTest {

    @Test
    void markCompleteSetsTaskAsComplete() {
        Task task = new Task("Deploy to prod");
        TaskService service = new TaskService();

        boolean result = service.markComplete(task);

        assertTrue(result);
        assertTrue(task.complete);
    }

    @Test
    void markCompleteRejectsNullTask() {
        TaskService service = new TaskService();

        assertThrows(IllegalArgumentException.class, () -> service.markComplete(null));
    }
}
```

- `@Test` marks a method as a test case — JUnit discovers and runs every `@Test`-annotated method automatically.
- `assertEquals(expected, actual)`, `assertTrue(condition)`, `assertFalse(condition)` — the core assertion family; a failed assertion throws, which JUnit catches and reports as a test failure with a clear diff.
- `assertThrows(ExceptionType.class, () -> ...)` — asserts that running the given lambda throws exactly that exception type, the standard way to test error-handling paths.

## The same behavior, actually runnable here

So you still get something you can execute directly in this course, here's the identical logic verified by hand — `if` checks and a `PASS`/`FAIL` printout instead of `@Test`/`assertTrue`. This is conceptually what JUnit does under the hood, just without the framework:

```java
public class Main {
    static class Task {
        String name;
        boolean complete;
        Task(String name) { this.name = name; this.complete = false; }
    }

    static class TaskService {
        boolean markComplete(Task task) {
            if (task == null) {
                throw new IllegalArgumentException("task cannot be null");
            }
            task.complete = true;
            return task.complete;
        }
    }

    public static void main(String[] args) {
        int passed = 0, failed = 0;

        // "Test 1": markComplete sets the task as complete
        Task t = new Task("Deploy to prod");
        boolean result = new TaskService().markComplete(t);
        if (result && t.complete) {
            System.out.println("PASS: markCompleteSetsTaskAsComplete");
            passed++;
        } else {
            System.out.println("FAIL: markCompleteSetsTaskAsComplete");
            failed++;
        }

        // "Test 2": markComplete rejects a null task
        boolean threw = false;
        try {
            new TaskService().markComplete(null);
        } catch (IllegalArgumentException e) {
            threw = true;
        }
        if (threw) {
            System.out.println("PASS: markCompleteRejectsNullTask");
            passed++;
        } else {
            System.out.println("FAIL: markCompleteRejectsNullTask");
            failed++;
        }

        System.out.println(passed + " passed, " + failed + " failed");
    }
}
```

Run it — both hand-rolled checks pass. This is exactly the value JUnit automates for you at scale: instead of writing this bookkeeping (`passed++`, printing PASS/FAIL, tracking totals) by hand for every class in a real project, `@Test` + assertions + a test runner does it uniformly, with far better failure output (JUnit tells you the expected vs. actual value on failure, not just "FAIL").

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "testing-junit-junit-basics-q1",
      "type": "mcq",
      "prompt": "What does the @Test annotation do in JUnit 5?",
      "options": [
        { "id": "a", "text": "Marks a method as a test case that JUnit discovers and runs automatically" },
        { "id": "b", "text": "Marks a method as deprecated" },
        { "id": "c", "text": "Tells the compiler to skip the method" },
        { "id": "d", "text": "Runs the method only in production builds" }
      ],
      "correct": "a",
      "explanation": "JUnit scans a test class for @Test-annotated methods and executes each one independently, reporting pass/fail per method."
    },
    {
      "id": "testing-junit-junit-basics-q2",
      "type": "mcq",
      "prompt": "What does assertThrows(IllegalArgumentException.class, () -> service.markComplete(null)) verify?",
      "options": [
        { "id": "a", "text": "That markComplete(null) returns false" },
        { "id": "b", "text": "That calling markComplete(null) throws exactly an IllegalArgumentException" },
        { "id": "c", "text": "That markComplete never throws any exception" },
        { "id": "d", "text": "That the method completes within a time limit" }
      ],
      "correct": "b",
      "explanation": "assertThrows runs the given lambda and asserts it throws the specified exception type — the standard JUnit pattern for testing that error conditions are actually rejected, not silently allowed."
    },
    {
      "id": "testing-junit-junit-basics-q3",
      "type": "mcq",
      "prompt": "Why bother writing automated tests instead of just running a program and eyeballing the printed output?",
      "options": [
        { "id": "a", "text": "Eyeballing output doesn't scale — automated tests catch regressions the moment unrelated code changes, without a human re-checking by hand every time" },
        { "id": "b", "text": "Automated tests are required by the Java compiler" },
        { "id": "c", "text": "There's no real benefit, it's purely a convention" },
        { "id": "d", "text": "Tests replace the need to run the program at all" }
      ],
      "correct": "a",
      "explanation": "The core value of automated tests is repeatability at scale — they re-verify behavior instantly, every time, as a codebase grows far beyond what anyone could manually re-check on every change."
    }
  ]
}
```

## What's next

Next: structuring tests properly — setup/teardown lifecycle hooks, naming conventions, and the Arrange-Act-Assert shape that keeps a large test suite readable.
