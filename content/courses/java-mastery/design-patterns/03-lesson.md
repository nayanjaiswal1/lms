---
kind: lesson
id_key: java-mastery/design-patterns/builder-observer
course: java-mastery
section: design-patterns
section_title: "Design Patterns"
section_position: 14
title: "Builder and Observer Patterns"
position: 3
estimated_minutes: 25
source: [java-mastery-curriculum.md]
---
Builder is another creational pattern, this time solving a *construction* problem. Observer is a **behavioral** pattern — it's about how objects react to each other's changes over time, rather than how they get built.

## The problem Builder solves: telescoping constructors

TaskFlow's real `Task` has a lot of optional fields beyond `name` and `estimateHours`: priority, assignee, status, due date, and more. A common first instinct is a chain of overloaded constructors, each delegating to a bigger one:

```java
public class Main {
    public static void main(String[] args) {
        Task t1 = new Task("Design schema", 6);
        Task t2 = new Task("Design schema", 6, "HIGH");
        Task t3 = new Task("Design schema", 6, "HIGH", "alice");

        System.out.println(t1.name + ", " + t1.priority + ", " + t1.assignee);
        System.out.println(t3.name + ", " + t3.priority + ", " + t3.assignee);
    }
}

class Task {
    String name;
    int estimateHours;
    String priority;
    String assignee;

    Task(String name, int estimateHours) {
        this(name, estimateHours, "MEDIUM");
    }

    Task(String name, int estimateHours, String priority) {
        this(name, estimateHours, priority, "unassigned");
    }

    Task(String name, int estimateHours, String priority, String assignee) {
        this.name = name;
        this.estimateHours = estimateHours;
        this.priority = priority;
        this.assignee = assignee;
    }
}
```

This works for four fields, but every additional optional field (`status`, `dueDate`, `project`, `tags`...) multiplies the plausible constructor combinations. Worse, a call like `new Task("x", 6, "HIGH", "alice")` tells a reader nothing about which positional argument means what.

The **Builder** pattern fixes both problems:

```java
public class Main {
    public static void main(String[] args) {
        Task task = new Task.Builder("Design schema", 6)
                .priority("HIGH")
                .assignee("alice")
                .status("IN_PROGRESS")
                .build();

        System.out.println(task.name + " | " + task.priority + " | "
                + task.assignee + " | " + task.status);
    }
}

class Task {
    final String name;
    final int estimateHours;
    final String priority;
    final String assignee;
    final String status;

    private Task(Builder builder) {
        this.name = builder.name;
        this.estimateHours = builder.estimateHours;
        this.priority = builder.priority;
        this.assignee = builder.assignee;
        this.status = builder.status;
    }

    static class Builder {
        private final String name;
        private final int estimateHours;
        private String priority = "MEDIUM";
        private String assignee = "unassigned";
        private String status = "TODO";

        public Builder(String name, int estimateHours) {
            this.name = name;
            this.estimateHours = estimateHours;
        }

        public Builder priority(String priority) {
            this.priority = priority;
            return this;
        }

        public Builder assignee(String assignee) {
            this.assignee = assignee;
            return this;
        }

        public Builder status(String status) {
            this.status = status;
            return this;
        }

        public Task build() {
            return new Task(this);
        }
    }
}
```

`name` and `estimateHours` are required, passed straight to the Builder's own constructor. Everything else is optional with a sensible default, and read as a self-documenting method call — `.priority("HIGH")` is unambiguous in a way a bare `"HIGH"` positional argument never was. Each builder method returns `this`, which is what makes the calls chain fluently. The outer `Task` constructor is `private`: the only way to obtain a `Task` is through the Builder, so it's impossible to construct one in a half-initialized state.

## The Observer pattern

Observer lets objects (**observers**, or listeners) subscribe to another object's (the **subject**'s) state changes, without the subject knowing anything concrete about who's listening. When a TaskFlow task's status changes, several unrelated things should happen — logging, notifying the assignee, refreshing a dashboard — without `Task` itself knowing about logging, notifications, or dashboards.

```java
import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        Task task = new Task("Deploy to prod");
        task.addListener(new LoggingListener());
        task.addListener(new NotificationListener("alice"));

        task.setStatus("IN_PROGRESS");
        task.setStatus("DONE");
    }
}

interface TaskListener {
    void onStatusChanged(Task task, String oldStatus, String newStatus);
}

class Task {
    private final String name;
    private String status = "TODO";
    private final List<TaskListener> listeners = new ArrayList<>();

    Task(String name) {
        this.name = name;
    }

    public void addListener(TaskListener listener) {
        listeners.add(listener);
    }

    public void setStatus(String newStatus) {
        String oldStatus = this.status;
        this.status = newStatus;
        for (TaskListener listener : listeners) {
            listener.onStatusChanged(this, oldStatus, newStatus);
        }
    }

    public String getName() {
        return name;
    }
}

class LoggingListener implements TaskListener {
    @Override
    public void onStatusChanged(Task task, String oldStatus, String newStatus) {
        System.out.println("[LOG] " + task.getName() + ": " + oldStatus + " -> " + newStatus);
    }
}

class NotificationListener implements TaskListener {
    private final String username;

    NotificationListener(String username) {
        this.username = username;
    }

    @Override
    public void onStatusChanged(Task task, String oldStatus, String newStatus) {
        if (newStatus.equals("DONE")) {
            System.out.println("[NOTIFY " + username + "] " + task.getName() + " is done!");
        }
    }
}
```

`Task` only knows about the `TaskListener` interface — never about `LoggingListener` or `NotificationListener` specifically. New listener types (a dashboard updater, a Slack integration) can be added later without touching `Task` at all. That's Open/Closed again, this time applied to a runtime-event scenario instead of a creation scenario.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "design-patterns-builder-observer-q1",
      "type": "mcq",
      "prompt": "What problem does the Builder pattern solve compared to a chain of overloaded constructors?",
      "options": [
        { "id": "a", "text": "It makes object construction faster at runtime" },
        { "id": "b", "text": "It avoids the exponential growth of constructor overloads and makes optional-field calls self-documenting" },
        { "id": "c", "text": "It removes the need for a class to have any fields" },
        { "id": "d", "text": "It allows fields to be reassigned after construction" }
      ],
      "correct": "b",
      "explanation": "Telescoping constructors multiply combinatorially as optional fields are added, and positional arguments are unreadable. Builder methods are named, chainable, and only set what's explicitly called."
    },
    {
      "id": "design-patterns-builder-observer-q2",
      "type": "mcq",
      "prompt": "Why is Task's own constructor declared private in the Builder example?",
      "options": [
        { "id": "a", "text": "Private constructors run faster" },
        { "id": "b", "text": "So the only way to obtain a Task instance is through Builder.build(), preventing a half-initialized Task" },
        { "id": "c", "text": "Java requires it whenever a nested class exists" },
        { "id": "d", "text": "It has no effect since Builder is in the same file" }
      ],
      "correct": "b",
      "explanation": "Making the constructor private forces every caller through the Builder's fluent API, guaranteeing a Task is always fully and consistently constructed before it's usable."
    },
    {
      "id": "design-patterns-builder-observer-q3",
      "type": "mcq",
      "prompt": "In the Observer example, what does Task depend on to notify listeners of a status change?",
      "options": [
        { "id": "a", "text": "The concrete LoggingListener and NotificationListener classes directly" },
        { "id": "b", "text": "Only the TaskListener interface — it has no knowledge of any specific listener implementation" },
        { "id": "c", "text": "A hardcoded email address" },
        { "id": "d", "text": "Reflection to discover listener classes at runtime" }
      ],
      "correct": "b",
      "explanation": "Task calls onStatusChanged on every registered TaskListener without knowing or caring which concrete class implements it — new listener types can be added without ever modifying Task."
    }
  ]
}
```

## What's next

Last lesson in this module: the **Strategy** pattern, for swapping how TaskFlow sorts and prioritizes a task list at runtime.
