---
kind: lesson
id_key: java-mastery/build-tools/dependency-management
course: java-mastery
section: build-tools
section_title: "Build Tools"
section_position: 17
title: "Dependency Management & Project Structure"
position: 2
estimated_minutes: 25
source: [java-mastery-curriculum.md]
---
Declaring a dependency in `pom.xml` or `build.gradle` is the easy part. The harder part — the part that actually causes real production incidents — is what happens once a project has dozens of dependencies that depend on *other* dependencies, and two of them disagree about which version of a shared library they need.

## Semantic versioning

Most Java libraries version themselves using **semantic versioning**: `MAJOR.MINOR.PATCH`, e.g. `5.10.2`.

- **MAJOR** bumps signal breaking API changes — upgrading from `4.x` to `5.x` might require code changes on your end.
- **MINOR** bumps add functionality in a backward-compatible way — `5.9.0` to `5.10.0` should be a safe upgrade.
- **PATCH** bumps are bug fixes only, no API changes — `5.10.1` to `5.10.2` should always be safe to take.

This convention is what makes it reasonable to pin a dependency to a specific version in `pom.xml`/`build.gradle` rather than always grabbing "latest": you can reason about the risk of an upgrade just from the version number changing, without reading a changelog line by line every time.

## Transitive dependencies and "dependency hell"

When TaskFlow declares a dependency on some library, it doesn't just get that library — it also gets everything *that* library depends on, recursively. These are **transitive dependencies**, and you never write them down explicitly; the build tool resolves the whole tree for you.

The problem arises when two of your direct dependencies transitively require *different, incompatible* versions of the same shared library — classically nicknamed **"dependency hell" or "diamond dependency conflict."** Picture it as a diamond shape:

```
        TaskFlow
        /      \
   LibraryA   LibraryB
       \        /
     CommonLib
   (A wants 2.x, B wants 3.x)
```

Both Maven and Gradle resolve this automatically rather than failing the build outright, but they do it differently:

- **Maven** uses "nearest wins": whichever version is *closest* to your project in the dependency tree (fewest hops away) is selected. If two versions are the same distance, the one declared first in the `pom.xml` wins.
- **Gradle** uses "highest wins" by default: among all the versions requested anywhere in the tree, the newest one is selected.

Neither strategy guarantees the chosen version is actually compatible with every dependency that wanted a different one — that's the "hell" part. Both tools let you inspect the resolved tree (`mvn dependency:tree`, `./gradlew dependencies`) and force a specific version explicitly when the automatic choice causes a runtime error like `NoSuchMethodError` — a classic symptom of code compiled against one version of a library running against a different, incompatible version actually on the classpath at runtime.

## Separating main and test dependencies

Not every dependency belongs in your shipped application. A testing framework like JUnit, or a mocking library like Mockito, is essential *while developing* but has no business being bundled into the `.jar` that actually runs in production — it would bloat the artifact and could even introduce security-relevant code paths nobody intended to ship.

Both tools model this with a concept that controls which dependencies apply where:

| Concept | Maven | Gradle |
|---|---|---|
| Name | `scope` | `configuration` |
| Main app code | `compile` (the default — no `<scope>` needed) | `implementation` |
| Test-only code | `test` | `testImplementation` |

This is exactly the `<scope>test</scope>` and `testImplementation` you saw in the `pom.xml` and `build.gradle` examples in the previous two lessons — now you know *why* that distinction exists: it's the build tool's way of guaranteeing JUnit never ends up in TaskFlow's production jar.

## Why package structure matters as TaskFlow grows

A build tool resolves *external* dependencies, but a project also needs internal organization — how you split your own code into packages. A single flat package with every class in it works fine for a course exercise; it breaks down fast in a real application, because nothing stops a web-layer class from directly manipulating database internals, and nothing signals to a new contributor where a given piece of logic is supposed to live.

The conventional fix is to organize packages by **architectural layer**, matching how data flows through the application:

```
com.taskflow.core       ← domain objects: Task, User, Project, Team — no framework dependencies
com.taskflow.service     ← business logic: TaskService, ProjectService — orchestrates core objects
com.taskflow.web          ← HTTP layer: controllers/handlers that call into service, never into core directly
```

This is a complete, runnable illustration of the *idea* — a `Task` domain object with no framework dependencies, and a service that operates on it, mirroring how `com.taskflow.core` and `com.taskflow.service` would be split into separate files/packages in a real multi-file project:

```java
public class Main {

    // Represents what would live in com.taskflow.core in a real project
    static class Task {
        private final String name;
        private boolean complete;

        Task(String name) {
            this.name = name;
            this.complete = false;
        }

        String getName() {
            return name;
        }

        boolean isComplete() {
            return complete;
        }

        void markComplete() {
            this.complete = true;
        }
    }

    // Represents what would live in com.taskflow.service in a real project
    static class TaskService {
        void completeTask(Task task) {
            task.markComplete();
            System.out.println("Completed: " + task.getName());
        }
    }

    public static void main(String[] args) {
        Task task = new Task("Set up Maven build");
        TaskService service = new TaskService();

        service.completeTask(task);
        System.out.println("Is complete: " + task.isComplete());
    }
}
```

The value isn't visible in a five-class toy example — it's visible six months and forty classes later, when a new contributor needs to find "where does task-completion logic live" and the package name answers the question before they open a single file. Consistent layering also makes dependency direction enforceable: `core` should never import from `web`, and a codebase that violates that consistently is a strong early signal of design trouble, long before it becomes an unmaintainable mess.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "build-tools-dependency-management-q1",
      "type": "mcq",
      "prompt": "Under semantic versioning (MAJOR.MINOR.PATCH), which kind of version bump signals a breaking API change?",
      "options": [
        { "id": "a", "text": "PATCH" },
        { "id": "b", "text": "MINOR" },
        { "id": "c", "text": "MAJOR" },
        { "id": "d", "text": "None — semantic versioning never signals breaking changes" }
      ],
      "correct": "c",
      "explanation": "MAJOR version bumps indicate breaking changes; MINOR adds backward-compatible functionality; PATCH is bug fixes only with no API changes."
    },
    {
      "id": "build-tools-dependency-management-q2",
      "type": "mcq",
      "prompt": "Two of TaskFlow's dependencies transitively require different versions of the same shared library. How does Maven resolve this by default?",
      "options": [
        { "id": "a", "text": "It fails the build immediately and refuses to compile" },
        { "id": "b", "text": "It selects the version declared nearest to your project in the dependency tree (\"nearest wins\")" },
        { "id": "c", "text": "It always picks the highest version number available" },
        { "id": "d", "text": "It downloads both versions and lets the JVM choose at runtime" }
      ],
      "correct": "b",
      "explanation": "Maven's default conflict resolution is \"nearest wins\" — the version closest to your project in the dependency graph is selected, with declaration order as a tiebreaker at equal distance. Gradle instead defaults to \"highest wins.\""
    },
    {
      "id": "build-tools-dependency-management-q3",
      "type": "mcq",
      "prompt": "Why is JUnit typically declared with test scope (Maven) or as testImplementation (Gradle) rather than a plain/main dependency?",
      "options": [
        { "id": "a", "text": "Test scope dependencies compile faster than main-scope ones" },
        { "id": "b", "text": "It keeps JUnit out of the packaged production artifact, since it's only needed while developing and running tests" },
        { "id": "c", "text": "JUnit cannot be declared as a main dependency at all" },
        { "id": "d", "text": "It has no real effect — scope is purely documentation" }
      ],
      "correct": "b",
      "explanation": "Test-scoped dependencies are available for compiling and running tests but are excluded from the final packaged artifact, keeping testing/mocking libraries out of what actually ships to production."
    }
  ]
}
```

## What's next

That's the full build-tools picture: how Maven and Gradle structure a project, run through their lifecycle, and manage dependencies. From here, the course moves into its final module — **interview-ready** — pulling every topic you've learned across the whole course, including this one, into the kind of theory questions you'll actually be asked.
