---
kind: lesson
id_key: java-mastery/build-tools/gradle-basics
course: java-mastery
section: build-tools
section_title: "Build Tools"
section_position: 17
title: "Gradle Basics"
position: 1
estimated_minutes: 25
source: [java-mastery-curriculum.md]
---
**Gradle** solves the same problem as Maven — reproducible dependency management, compilation, testing, and packaging — but with a different core idea: instead of a declarative XML document that a fixed engine interprets, a Gradle build script is written in a real programming language (Groovy or Kotlin) and executed directly. This lesson uses the **Groovy DSL** (`build.gradle`), the older and still extremely common option; Gradle also supports a Kotlin DSL (`build.gradle.kts`) with the same structure but Kotlin syntax.

## A minimal `build.gradle`

Same dependency and plugin setup as the Maven `pom.xml` from the previous lesson, expressed as a Gradle build script. Like `pom.xml`, this is **not runnable in this course's Java code runner** — it's a build script meant for the `gradle`/`gradlew` command line tool against a real project on disk, not a Java program:

```groovy
plugins {
    id 'java'
}

group = 'com.taskflow'
version = '1.0.0'

repositories {
    mavenCentral()
}

dependencies {
    testImplementation 'org.junit.jupiter:junit-jupiter:5.10.2'
}

java {
    sourceCompatibility = JavaVersion.VERSION_21
    targetCompatibility = JavaVersion.VERSION_21
}

test {
    useJUnitPlatform()
}
```

Compare this to the Maven `pom.xml`: `plugins { id 'java' }` plays the same role as Maven's `<packaging>jar</packaging>` plus the compiler plugin — it tells Gradle "this is a Java project, wire up compile/test/jar tasks automatically." `repositories { mavenCentral() }` says where to fetch dependencies from (Gradle doesn't assume Maven Central by default the way Maven does — you declare it explicitly). `testImplementation` is Gradle's equivalent of Maven's `<scope>test</scope>` — a dependency needed only to compile and run tests, not shipped with the main application.

Gradle also uses the same standard `src/main/java`, `src/main/resources`, `src/test/java` layout as Maven by default (via the `java` plugin) — that convention isn't a Maven-only thing, it's shared enough between the two tools that switching between projects doesn't mean relearning where files live.

## Why teams choose Gradle over Maven (or vice versa)

- **Build script as code vs. declarative XML.** Maven's `pom.xml` can only do what the XML schema and installed plugins allow — anything conditional or dynamic needs a plugin. Gradle's `build.gradle` is Groovy (or Kotlin) code: you can write an `if` statement, a loop, or a custom task directly in the build file. This is a genuine tradeoff, not a strict upgrade — the flexibility that makes complex builds easier also makes a build script easier to make inconsistent or hard to reason about across a large team, which is part of why some organizations deliberately prefer Maven's rigidity.
- **Incremental builds.** Gradle tracks inputs and outputs of every task (compile, test, etc.) and skips a task entirely if nothing relevant changed since the last run — re-running `gradle build` right after a successful build with no code changes finishes almost instantly. Maven's lifecycle model doesn't have this built in the same way; it recompiles more eagerly.
- **Performance at scale.** Gradle's daemon process stays warm between builds (avoiding JVM startup cost every invocation), and it can build independent modules of a multi-module project in parallel. This matters most on large projects with many modules — for a single small project like early TaskFlow, the practical difference is minor.
- **Maven's advantage is convention and predictability.** Because every `pom.xml` follows the same rigid shape, a Maven project is often faster for a newcomer to understand at a glance, and there's less room for one team's build script to diverge in surprising ways from another's.

Neither tool is "correct" — plenty of production Java codebases use each. What matters for you as a developer is recognizing both shapes on sight, since you'll encounter both across different jobs and open-source projects.

## The commands you'll actually type

Gradle projects ship with a **wrapper** — `gradlew` (Linux/macOS) and `gradlew.bat` (Windows) — a small script checked into the project that downloads and runs the exact Gradle version the project was built with, so nobody needs Gradle pre-installed globally or fights a version mismatch. You almost always run the wrapper, not a bare `gradle` command:

- **`./gradlew build`** — compiles, runs tests, and packages the project, roughly the Gradle equivalent of Maven's `mvn package` (it also runs additional checks by default).
- **`./gradlew test`** — compiles and runs tests only, without producing the final package.
- **`./gradlew clean`** — deletes the build output directory (`build/`, Gradle's equivalent of Maven's `target/`), often chained as `./gradlew clean build`.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "build-tools-gradle-basics-q1",
      "type": "mcq",
      "prompt": "What is the fundamental difference between a Gradle build.gradle file and a Maven pom.xml?",
      "options": [
        { "id": "a", "text": "There is no real difference — they use identical syntax" },
        { "id": "b", "text": "build.gradle is executable code (Groovy or Kotlin); pom.xml is declarative XML interpreted by a fixed engine" },
        { "id": "c", "text": "pom.xml supports dependencies, build.gradle does not" },
        { "id": "d", "text": "Gradle projects cannot have a src/main/java layout" }
      ],
      "correct": "b",
      "explanation": "Maven's pom.xml is declarative data that Maven's engine interprets; Gradle's build.gradle is an actual script written in Groovy or Kotlin, giving it more programmatic flexibility at the cost of being less uniformly predictable across projects."
    },
    {
      "id": "build-tools-gradle-basics-q2",
      "type": "mcq",
      "prompt": "What does testImplementation in a Gradle build.gradle correspond to in a Maven pom.xml?",
      "options": [
        { "id": "a", "text": "A <plugin> entry" },
        { "id": "b", "text": "A dependency with <scope>test</scope>" },
        { "id": "c", "text": "The <packaging> element" },
        { "id": "d", "text": "The maven-compiler-plugin" }
      ],
      "correct": "b",
      "explanation": "testImplementation marks a dependency as needed only for compiling and running tests, not the main application — the same role Maven's <scope>test</scope> plays."
    },
    {
      "id": "build-tools-gradle-basics-q3",
      "type": "mcq",
      "prompt": "Why do Gradle projects typically run `./gradlew build` rather than a bare `gradle build`?",
      "options": [
        { "id": "a", "text": "gradlew is required because gradle does not exist as a command" },
        { "id": "b", "text": "The wrapper script (gradlew) downloads and runs the exact Gradle version the project expects, so contributors don't need a matching global install" },
        { "id": "c", "text": "gradlew runs faster because it skips tests" },
        { "id": "d", "text": "gradlew is only used on Windows" }
      ],
      "correct": "b",
      "explanation": "The Gradle wrapper is checked into the project and pins the exact Gradle version, avoiding \"works on my machine\" version mismatches — this is why ./gradlew, not a globally installed gradle, is the standard way to build."
    }
  ]
}
```

## What's next

With both major build tools covered, the last lesson in this module looks at what actually goes wrong as a project's dependency list and package structure grow — dependency conflicts, scopes, and how TaskFlow should organize its packages as it scales past a handful of classes.
