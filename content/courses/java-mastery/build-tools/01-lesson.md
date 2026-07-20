---
kind: lesson
id_key: java-mastery/build-tools/maven-basics
course: java-mastery
section: build-tools
section_title: "Build Tools"
section_position: 17
title: "Maven Basics"
position: 0
estimated_minutes: 25
source: [java-mastery-curriculum.md]
---
Every real Java project — including TaskFlow — needs a way to declare its dependencies, compile consistently across machines, run its tests, and package itself into something deployable. So far in this course, every code box has been a single self-contained file with no dependencies. **Maven** is one of the two dominant tools (Gradle is the other, next lesson) that solves the "how do I build a multi-file, multi-dependency Java project the same way every time" problem.

Maven is **declarative**: you describe *what* your project needs — its dependencies, its packaging type, its plugins — in an XML file called `pom.xml` ("Project Object Model"), and Maven figures out *how* to actually run the build by following a fixed, standardized lifecycle.

## The standard directory layout

Maven has a strong opinion about where your files live, and following it means zero configuration is needed to tell Maven where to find anything:

```
taskflow/
├── pom.xml
└── src/
    ├── main/
    │   ├── java/          ← your application source code
    │   │   └── com/taskflow/...
    │   └── resources/     ← non-code files bundled into the build (config, templates)
    └── test/
        ├── java/          ← test source code (JUnit tests, mirrors main/java's package structure)
        └── resources/     ← test-only resources
```

This is often called "convention over configuration." A newcomer to any Maven project — including a future contributor to TaskFlow — already knows where to find the code without reading a build script, because every Maven project everywhere is laid out identically.

## A minimal `pom.xml`

This is a realistic minimal `pom.xml` for TaskFlow. It is **not runnable in this course's Java code runner** — `pom.xml` is a build configuration file, not a Java program; it only means something when the `mvn` command line tool reads it against a real project directory on disk:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
                              http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.taskflow</groupId>
    <artifactId>taskflow-core</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>

    <properties>
        <maven.compiler.source>21</maven.compiler.source>
        <maven.compiler.target>21</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.junit.jupiter</groupId>
            <artifactId>junit-jupiter</artifactId>
            <version>5.10.2</version>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.13.0</version>
            </plugin>
        </plugins>
    </build>
</project>
```

Breaking down the sections:

- **`groupId` / `artifactId` / `version`** — together, the "GAV coordinates" that uniquely identify this project (or any dependency of it) inside Maven's dependency ecosystem. `groupId` is typically your reversed domain (`com.taskflow`), `artifactId` is the specific module name.
- **`<dependencies>`** — every library the project needs, each identified by its own GAV coordinates. Maven downloads these automatically from a remote repository (Maven Central, by default) into a local cache (`~/.m2/repository`) the first time you build, then reuses the cache afterward.
- **`<build><plugins>`** — plugins extend what the build *does*. The compiler plugin here controls which Java language level `javac` compiles against; other common plugins package a runnable "fat jar," run static analysis, or generate code.

## The build lifecycle

Maven's lifecycle is a fixed, ordered sequence of **phases**. Running any phase runs every phase before it too:

```
validate → compile → test → package → install → deploy
```

| Phase | What happens |
|---|---|
| `validate` | Checks the project structure and `pom.xml` are well-formed |
| `compile` | Compiles `src/main/java` into `.class` files |
| `test` | Compiles and runs `src/test/java` against the compiled main code |
| `package` | Bundles compiled classes and resources into a `.jar` (or `.war`) |
| `install` | Copies the packaged artifact into your local `~/.m2` repository, so other local projects can depend on it |
| `deploy` | Uploads the artifact to a shared remote repository for other teams/machines to use |

Because the phases are ordered and cumulative, running `mvn package` first silently runs `validate`, `compile`, and `test` for you — you never invoke earlier phases separately unless you specifically want to stop there.

## The commands you'll actually type

- **`mvn compile`** — compiles main source only, stops there. Good for a fast "does this even compile" check.
- **`mvn test`** — compiles main and test source, then runs every test. This is what you run constantly while developing.
- **`mvn package`** — runs everything through `test`, then produces the final `.jar` in `target/`.
- **`mvn clean`** — deletes the `target/` directory (Maven's build output folder), often chained as `mvn clean package` to guarantee a fresh build with no stale `.class` files left over from a previous run.

If a TaskFlow contributor changes a class and its tests suddenly fail, `mvn test` is the one command that reproduces exactly what continuous integration will see — that consistency, more than any individual feature, is the real reason teams standardize on a build tool instead of everyone compiling by hand with `javac`.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "build-tools-maven-basics-q1",
      "type": "mcq",
      "prompt": "In Maven's standard directory layout, where does application (non-test) source code live?",
      "options": [
        { "id": "a", "text": "src/java" },
        { "id": "b", "text": "src/main/java" },
        { "id": "c", "text": "java/src/main" },
        { "id": "d", "text": "main/src" }
      ],
      "correct": "b",
      "explanation": "Maven's convention-over-configuration layout puts application source under src/main/java, resources under src/main/resources, and test code under the parallel src/test/java and src/test/resources."
    },
    {
      "id": "build-tools-maven-basics-q2",
      "type": "mcq",
      "prompt": "If you run `mvn package`, which lifecycle phases also run before it, in order?",
      "options": [
        { "id": "a", "text": "None — package runs in isolation" },
        { "id": "b", "text": "Only test" },
        { "id": "c", "text": "validate, compile, and test" },
        { "id": "d", "text": "install and deploy, then package last" }
      ],
      "correct": "c",
      "explanation": "Maven's lifecycle phases are ordered and cumulative: validate, compile, test, package, install, deploy. Invoking package runs every phase before it — validate, compile, test — automatically."
    },
    {
      "id": "build-tools-maven-basics-q3",
      "type": "mcq",
      "prompt": "What identifies a specific dependency (or your own project) uniquely within Maven's ecosystem?",
      "options": [
        { "id": "a", "text": "The file name of the pom.xml" },
        { "id": "b", "text": "Its GAV coordinates: groupId, artifactId, and version" },
        { "id": "c", "text": "The order it appears in <dependencies>" },
        { "id": "d", "text": "The plugin section of the pom.xml" }
      ],
      "correct": "b",
      "explanation": "groupId, artifactId, and version together (often shorthanded \"GAV\") uniquely identify an artifact in a Maven repository — this is how Maven knows exactly which jar to fetch and cache."
    }
  ]
}
```

## What's next

Maven isn't the only build tool in wide use — the next lesson covers **Gradle**, which solves the same problems with a different philosophy: a build *script* instead of a declarative XML document.
