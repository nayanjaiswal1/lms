---
kind: lesson
id_key: java-mastery/design-patterns/dry-principle
course: java-mastery
section: design-patterns
section_title: "Design Patterns"
section_position: 14
title: "DRY Principle"
position: 1
estimated_minutes: 20
source: [dry-principle-course-notes]
---
SOLID tells you how to shape individual classes. DRY is the principle that governs everything *between* them: as TaskFlow grew, the same validation rule or the same message-formatting logic started showing up in more than one place, copy-pasted rather than shared. DRY — **Don't Repeat Yourself** — is the discipline that catches that before it becomes a bug.

## What DRY actually means

Every piece of *knowledge* in a system should have a single, unambiguous, authoritative representation.

> The key word is **knowledge**, not just code. Two blocks of code can look identical by coincidence and not be a DRY violation — and two blocks that look nothing alike can still be expressing the same rule twice.

In TaskFlow terms, "knowledge" covers things like: what makes a task title valid, how a due date gets formatted for display, which fields a `Task` record has, and what "overdue" means. If that last one is decided in one place today and reimplemented slightly differently somewhere else next sprint, TaskFlow now has two different opinions about which tasks are overdue.

## Why repetition is dangerous

| Problem | What it looks like in TaskFlow |
|---|---|
| Hard to maintain | The overdue-date rule changes; you update it in `TaskManager` and forget the copy in `TaskExportService` |
| Bug magnet | One copy of the title-validation check gets a blank-string fix, the other doesn't |
| Bloated codebase | The same ten-line validation block, copy-pasted into every place a task gets created |
| Poor test coverage | Each copy needs its own tests, and they rarely all get written or kept in sync |

## The Rule of Three

Don't extract on the first duplicate — wait until you see the same logic **three times** before pulling it out into its own class or method.

- Two occurrences might be coincidence, or might diverge on purpose later.
- Three occurrences is a pattern, not a coincidence — that's the signal to extract.

Extracting too early is its own trap, covered below.

## Applying DRY: task validation

TaskFlow creates tasks from three different entry points — the UI-backed `TaskManager`, a bulk `TaskImportService` for CSV uploads, and a `TaskApiHandler` for the public API. Each one grew its own copy of "is this task valid":

```java
// TaskManager.addTask(...)
if (title == null || title.isBlank()) {
    throw new IllegalArgumentException("Task title cannot be blank");
}

// TaskImportService.importRow(...) — same rule, written again
if (title == null || title.trim().isEmpty()) {
    throw new IllegalArgumentException("Row has blank title");
}

// TaskApiHandler.createTask(...) — a third copy, and it's missing the null check
if (title.isEmpty()) {
    throw new IllegalArgumentException("title is required");
}
```

Three copies of the same knowledge — "a task title must be non-null and non-blank" — and they've already drifted: the API handler's version throws a `NullPointerException` instead of a clear error if `title` is `null`. That's exactly the bug DRY is meant to prevent. Extract it once:

```java
public class TaskValidator {
    public static void validateTitle(String title) {
        if (title == null || title.isBlank()) {
            throw new IllegalArgumentException("Task title cannot be blank");
        }
    }
}
```

Now `TaskManager`, `TaskImportService`, and `TaskApiHandler` all call `TaskValidator.validateTitle(title)`. Fix the rule once — say, adding a max-length check — and all three callers pick it up automatically, with no risk of one being missed.

## A second example: task notifications

`TaskReminderService`, `OverdueAlertService`, and `AssignmentNotifier` all send messages to users, and all three had grown their own copy of "build a message string, then call the notification API":

```
TaskReminderService  → formats its own message, calls NotificationApi directly
OverdueAlertService  → formats its own (slightly different) message, calls NotificationApi directly
AssignmentNotifier   → formats its own message, calls NotificationApi directly
```

Splitting the shared knowledge out into two focused classes fixes it:

```
TaskMessageFormatter → formats a message from a Task and a reason
NotificationSender   → sends a formatted message via the notification API

TaskReminderService, OverdueAlertService, AssignmentNotifier
  → each calls TaskMessageFormatter, then NotificationSender
```

The payoff shows up the next time TaskFlow changes: swap notification providers, and `NotificationSender` is the only class that changes. Change the message template, and `TaskMessageFormatter` is the only class that changes. Add a `TaskCompletedNotifier` next quarter, and it costs zero changes to the three services that already exist.

## When repetition is okay

DRY is easy to over-apply. A few cases where duplication is the right call:

**Premature abstraction.** Don't extract the first time you see similar-looking code — let a real pattern show up first (see the Rule of Three above). As Sandi Metz puts it: "duplication is far cheaper than the wrong abstraction." A `TaskValidator` built after seeing three real call sites will fit all three; one built after seeing one call site is a guess.

**Tests.** A test for `TaskValidator.validateTitle` should read top-to-bottom without jumping into a shared helper to understand what it's asserting. A little repeated setup across tests is a fair trade for tests that are easy to read in isolation.

**Trivial code.** `dueDate.isBefore(LocalDate.now())` doesn't need a `DateUtils.isPast(dueDate)` wrapper — the abstraction costs more to look up than the line it replaces saves.

## The mental trigger

Before copy-pasting a block of logic, ask: *if this rule changes tomorrow, will I remember every place it lives?* If the honest answer is no, that's the signal to extract it — not on principle, but because a "no" there is how TaskFlow ends up with three different definitions of "overdue."

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "design-patterns-dry-principle-q1",
      "type": "mcq",
      "prompt": "TaskManager, TaskImportService, and TaskApiHandler each independently reimplement the 'title must not be blank' check, and one of the three copies is missing the null check the others have. What does DRY say should have prevented this?",
      "options": [
        { "id": "a", "text": "The check should have a single authoritative implementation that all three callers use" },
        { "id": "b", "text": "Each entry point should validate differently since they receive input differently" },
        { "id": "c", "text": "Validation should be removed from TaskApiHandler entirely" },
        { "id": "d", "text": "This isn't a DRY violation because the code isn't character-for-character identical" }
      ],
      "correct": "a",
      "explanation": "DRY is about knowledge, not literal text — 'a task title must be non-null and non-blank' is one piece of knowledge that was expressed three times and drifted. A single TaskValidator.validateTitle fixes it once for every caller."
    },
    {
      "id": "design-patterns-dry-principle-q2",
      "type": "mcq",
      "prompt": "According to the Rule of Three, when should you extract a piece of duplicated logic into its own class or method?",
      "options": [
        { "id": "a", "text": "Immediately, the first time you notice any two blocks that look similar" },
        { "id": "b", "text": "Only after the same logic has shown up a third time, since two occurrences may be coincidental or meant to diverge" },
        { "id": "c", "text": "Never — extraction always adds unnecessary indirection" },
        { "id": "d", "text": "Only if the duplicated block is longer than 20 lines" }
      ],
      "correct": "b",
      "explanation": "Two occurrences might be coincidence or deliberate divergence; a third occurrence is what confirms a real, stable pattern worth extracting."
    },
    {
      "id": "design-patterns-dry-principle-q3",
      "type": "mcq",
      "prompt": "TaskReminderService, OverdueAlertService, and AssignmentNotifier are refactored so each one calls a shared TaskMessageFormatter and NotificationSender instead of formatting and sending messages independently. What is the main benefit?",
      "options": [
        { "id": "a", "text": "The code runs faster at runtime" },
        { "id": "b", "text": "Swapping the notification provider or changing the message template now requires a change in exactly one place instead of three" },
        { "id": "c", "text": "It removes the need for any of the three services to exist" },
        { "id": "d", "text": "It makes the three services implement the same interface" }
      ],
      "correct": "b",
      "explanation": "The point of extracting shared knowledge into TaskMessageFormatter and NotificationSender is that a change to formatting or to the sending mechanism now propagates automatically to every caller instead of needing to be repeated in each service."
    },
    {
      "id": "design-patterns-dry-principle-q4",
      "type": "mcq",
      "prompt": "Which of these is a case where DRY should NOT be applied, per Sandi Metz's 'duplication is far cheaper than the wrong abstraction'?",
      "options": [
        { "id": "a", "text": "Three separate services all reimplementing the same overdue-task calculation" },
        { "id": "b", "text": "Extracting a shared TaskValidator after seeing the same title check written three times" },
        { "id": "c", "text": "Building a shared abstraction after seeing only one call site, guessing at what the other future call sites might need" },
        { "id": "d", "text": "Extracting NotificationSender after three services duplicated the same API call" }
      ],
      "correct": "c",
      "explanation": "Abstracting from a single call site is premature abstraction — you're guessing at a shape instead of letting a real, repeated pattern reveal it. That guess is usually wrong and costs more to unwind than the duplication would have."
    }
  ]
}
```

## What's next

Next up: the **Singleton** and **Factory** patterns — two ways of controlling how TaskFlow objects get created, starting with a `TaskIdGenerator` that must only ever exist once.
