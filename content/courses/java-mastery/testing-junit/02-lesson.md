---
kind: lesson
id_key: java-mastery/testing-junit/test-lifecycle-and-organization
course: java-mastery
section: testing-junit
section_title: "Testing with JUnit"
section_position: 16
title: "Test Lifecycle & Organization"
position: 1
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
A handful of standalone `@Test` methods works fine for a toy example. A real test suite needs shared setup, a consistent shape per test, and a naming convention that makes a failing test's *purpose* obvious from its name alone — before you even read the assertion that failed.

**Note:** as in the previous lesson, the JUnit-specific code below is real, idiomatic test code you'd run via Maven/Gradle — not directly runnable in this course's plain-`Main` code box. Read it for the pattern.

## `@BeforeEach` and `@AfterEach`

Most test classes need the same fresh setup before every single test — and JUnit gives you a hook to avoid repeating it in every `@Test` method:

```java
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class TaskServiceTest {

    private TaskService service;
    private Task task;

    @BeforeEach
    void setUp() {
        // Runs fresh before EVERY @Test method in this class — no test
        // accidentally depends on state left over from a previous one.
        service = new TaskService();
        task = new Task("Deploy to prod");
    }

    @AfterEach
    void tearDown() {
        // Runs after every test — cleanup for resources that need it
        // (closing a connection, deleting a temp file). Often empty for
        // plain in-memory objects like this one.
    }

    @Test
    void markCompleteSetsTaskAsComplete() {
        boolean result = service.markComplete(task);
        assertTrue(result);
    }

    @Test
    void markCompleteRejectsNullTask() {
        assertThrows(IllegalArgumentException.class, () -> service.markComplete(null));
    }
}
```

Without `@BeforeEach`, both tests would need to repeat `service = new TaskService(); task = new Task(...)` in their own bodies — harmless with two tests, unmaintainable with fifty. Critically, `@BeforeEach` runs **fresh for every test**, so `markCompleteSetsTaskAsComplete` mutating `task.complete` can never leak into `markCompleteRejectsNullTask` running afterward — each test gets a clean slate.

## `@DisplayName` — readable failure output

```java
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class TaskServiceTest {

    @Test
    @DisplayName("marking a task complete flips its complete flag to true")
    void markCompleteSetsTaskAsComplete() {
        // ...
    }
}
```

`@DisplayName` doesn't change what the test does — it changes what shows up in test reports and IDE output when the test runs (or fails), so a teammate scanning a failing build sees a sentence describing the broken behavior instead of a bare method name.

## Arrange-Act-Assert

The internal shape of a good test, regardless of framework, follows the same three-beat structure:

```java
@Test
void markCompleteSetsTaskAsComplete() {
    // Arrange: set up the exact state this test needs
    Task task = new Task("Deploy to prod");
    TaskService service = new TaskService();

    // Act: perform the one action under test
    boolean result = service.markComplete(task);

    // Assert: verify the outcome
    assertTrue(result);
    assertTrue(task.complete);
}
```

Keeping these three phases visually separated (even just with the comments, or a blank line between them) makes a test's intent obvious at a glance, and makes it easy to spot a test that's secretly doing too much — if "Act" is five lines calling three different methods, that's a sign the test (or the code it's testing) needs to be split up.

## One test class per production class

The convention that scales: `TaskService` gets `TaskServiceTest`, `TaskRepository` gets `TaskRepositoryTest`, and so on — a 1:1 mapping that means anyone can find a class's tests immediately, and a test file never becomes an unfocused grab-bag testing five unrelated classes at once. Individual test method names should read like a sentence describing the specific behavior under test — `markCompleteSetsTaskAsComplete` and `markCompleteRejectsNullTask`, not `test1` and `test2` — since a failing test's *name* is often the first (and sometimes only) thing a teammate reads in a CI failure notification.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "testing-junit-lifecycle-and-organization-q1",
      "type": "mcq",
      "prompt": "Why does @BeforeEach run before EVERY test method, rather than once per class?",
      "options": [
        { "id": "a", "text": "So each test starts from the same clean, predictable state, and no test can accidentally depend on leftover state from a previous test" },
        { "id": "b", "text": "It's a JUnit performance optimization with no behavioral purpose" },
        { "id": "c", "text": "Because JUnit requires it for the test class to compile" },
        { "id": "d", "text": "So all tests share exactly one Task instance" }
      ],
      "correct": "a",
      "explanation": "Fresh setup per test prevents test-order dependencies — a classic source of flaky test suites where a test only passes if another test happened to run first."
    },
    {
      "id": "testing-junit-lifecycle-and-organization-q2",
      "type": "mcq",
      "prompt": "What is the purpose of the Arrange-Act-Assert structure inside a test method?",
      "options": [
        { "id": "a", "text": "It's required syntax that JUnit enforces at compile time" },
        { "id": "b", "text": "It keeps a test's setup, the action under test, and the verification visually and logically separated, making its intent clear at a glance" },
        { "id": "c", "text": "It determines the order tests run in across a class" },
        { "id": "d", "text": "It replaces the need for assertions" }
      ],
      "correct": "b",
      "explanation": "Arrange-Act-Assert is a convention, not a language feature — but a strong one, since it keeps every test readable and makes tests doing 'too much' easy to spot."
    },
    {
      "id": "testing-junit-lifecycle-and-organization-q3",
      "type": "mcq",
      "prompt": "Why prefer a test name like markCompleteRejectsNullTask over test2?",
      "options": [
        { "id": "a", "text": "JUnit runs alphabetically-named tests faster" },
        { "id": "b", "text": "A descriptive name documents the exact behavior under test, which is often the first thing a teammate reads when a test fails in CI" },
        { "id": "c", "text": "There's no real difference — either is equally good practice" },
        { "id": "d", "text": "Numbered test names are required for @BeforeEach to work" }
      ],
      "correct": "b",
      "explanation": "A descriptive test method name is effectively free documentation — it tells a reader (or a CI failure notification) exactly what broke, without needing to open the method body first."
    }
  ]
}
```

## What's next

The last lesson in this module covers **mocking** — what to do when the class you're testing depends on something you don't want a unit test to actually touch, like a real email service.
