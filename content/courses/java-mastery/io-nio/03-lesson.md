---
kind: lesson
id_key: java-mastery/io-nio/nio-file-path
course: java-mastery
section: io-nio
section_title: "File I/O & NIO"
section_position: 9
title: "java.nio.file: Path and Files"
position: 2
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
`java.io.File`, from the very first Java release, represents a filesystem path — but its API is thin and its error handling is famously bad (many operations just return `false` on failure instead of telling you *why*). Java 7 introduced `java.nio.file` (often called "NIO.2") as a modern replacement: the `Path` interface plus the `Files` utility class, with richer operations and exceptions that actually explain what went wrong.

## `Path` and the old `File` API, side by side

```java
import java.io.File;
import java.nio.file.Path;
import java.nio.file.Paths;

public class Main {
    public static void main(String[] args) {
        // The old way: java.io.File
        File oldStyle = new File("taskflow-exports/2024/report.txt");
        System.out.println("Old API name: " + oldStyle.getName());
        System.out.println("Old API parent: " + oldStyle.getParent());

        // The modern way: java.nio.file.Path
        Path modern = Paths.get("taskflow-exports", "2024", "report.txt");
        System.out.println("Modern API: " + modern);
        System.out.println("Modern file name: " + modern.getFileName());
        System.out.println("Modern parent: " + modern.getParent());
    }
}
```

`Paths.get(...)` builds a `Path` from one or more path segments, joining them with the correct OS-specific separator automatically — you never hardcode `/` or `\`. `Path` itself is just an immutable representation of a location; the actual filesystem operations (does it exist, read it, write it, delete it) live on the separate `Files` utility class, which is the biggest structural difference from `File`, where all of that was methods on the `File` object itself.

## `Files.exists`, `Files.write`, `Files.readAllLines`

Because these lesson code boxes run in a sandboxed environment without a persistent filesystem across separate runs, this example is self-contained: it creates a temp file with `Files.createTempFile`, writes to it, reads it back, and prints the result — all within one program execution, so you see real, live filesystem behavior every time you run it.

```java
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

public class Main {
    public static void main(String[] args) throws IOException {
        Path tempFile = Files.createTempFile("taskflow-export", ".csv");

        System.out.println("Exists before write? " + Files.exists(tempFile));

        List<String> lines = List.of(
            "Design database schema,6,HIGH",
            "Build REST API,10,HIGH",
            "Write tests,4,MEDIUM"
        );

        // Files.write can take a List<String> directly — one write call, no manual loop
        Files.write(tempFile, lines, StandardCharsets.UTF_8);

        System.out.println("Exists after write? " + Files.exists(tempFile));
        System.out.println("File size in bytes: " + Files.size(tempFile));

        // Files.readAllLines reads the whole file into a List<String> in one call
        List<String> readBack = Files.readAllLines(tempFile, StandardCharsets.UTF_8);

        int totalHours = 0;
        for (String line : readBack) {
            String[] fields = line.split(",");
            totalHours += Integer.parseInt(fields[1]);
        }

        System.out.println("Lines read back: " + readBack.size());
        System.out.println("Total estimated hours: " + totalHours);

        Files.delete(tempFile); // clean up
        System.out.println("Exists after delete? " + Files.exists(tempFile));
    }
}
```

`Files.write` and `Files.readAllLines` handle the entire buffering/closing/looping dance from the previous two lessons in a single method call each — for small-to-medium files where loading everything into memory at once is fine, this is dramatically less boilerplate than the manual `BufferedReader`/`BufferedWriter` approach. For very large files that shouldn't be loaded entirely into memory, `Files.newBufferedReader`/`Files.newBufferedWriter` give you back a `BufferedReader`/`BufferedWriter` built on a `Path`, so you're not forced to choose one style forever.

## Checking and appending

```java
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.List;

public class Main {
    public static void main(String[] args) throws IOException {
        Path tempFile = Files.createTempFile("taskflow-log", ".txt");

        Files.write(tempFile, List.of("Task created: Design schema"), StandardCharsets.UTF_8);

        // StandardOpenOption.APPEND adds to the end instead of overwriting
        Files.write(
            tempFile,
            List.of("Task created: Build REST API"),
            StandardCharsets.UTF_8,
            StandardOpenOption.APPEND
        );

        List<String> allLines = Files.readAllLines(tempFile);
        System.out.println("Total log lines: " + allLines.size());
        for (String line : allLines) {
            System.out.println(line);
        }

        Files.delete(tempFile);
    }
}
```

Without `StandardOpenOption.APPEND`, each `Files.write` call overwrites the file from scratch — this is a common surprise for anyone expecting `write` to behave like appending to a log by default.

## Why NIO.2 is generally preferred now

`java.io.File` is still around (plenty of older code and some libraries still use it), but for new code `java.nio.file` is the better default: better exceptions (`Files.readAllLines` throws a specific, descriptive `IOException` rather than `File`'s pattern of silently returning `false`/`null` on failure), a richer `Files` API (symbolic links, file attributes, directory walking, atomic moves), and `Path`'s cleaner separation between "a location" (`Path`) and "operations on that location" (`Files`).

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "io-nio-nio-file-path-q1",
      "type": "mcq",
      "prompt": "What is the key structural difference between java.io.File and java.nio.file.Path?",
      "options": [
        { "id": "a", "text": "Path can only represent directories, not files" },
        { "id": "b", "text": "File bundles both the path representation and filesystem operations into one class; Path represents only the location, with operations moved to the separate Files utility class" },
        { "id": "c", "text": "Path is only usable on Linux, not Windows" },
        { "id": "d", "text": "There is no real difference — Path is just a renamed File" }
      ],
      "correct": "b",
      "explanation": "File conflates 'a path' and 'operations on that path' into one object. NIO.2 splits these: Path is an immutable location, and Files holds the static utility methods (exists, write, readAllLines, delete, etc.) that act on a Path."
    },
    {
      "id": "io-nio-nio-file-path-q2",
      "type": "mcq",
      "prompt": "Calling Files.write(path, lines) a second time on the same path, without any StandardOpenOption, does what?",
      "options": [
        { "id": "a", "text": "Appends the new lines to the end of the existing file" },
        { "id": "b", "text": "Throws an exception because the file already exists" },
        { "id": "c", "text": "Overwrites the file's previous contents from scratch" },
        { "id": "d", "text": "Merges the two sets of lines alphabetically" }
      ],
      "correct": "c",
      "explanation": "The default behavior of Files.write is to create or overwrite the file. Appending requires explicitly passing StandardOpenOption.APPEND."
    },
    {
      "id": "io-nio-nio-file-path-q3",
      "type": "mcq",
      "prompt": "Why is java.nio.file generally preferred over java.io.File for new code?",
      "options": [
        { "id": "a", "text": "java.io.File has been fully removed from modern Java" },
        { "id": "b", "text": "It offers richer functionality (symbolic links, file attributes, atomic moves) and better error reporting via descriptive exceptions instead of silent false/null returns" },
        { "id": "c", "text": "java.nio.file is faster purely because it has a shorter package name" },
        { "id": "d", "text": "java.io.File cannot read text files at all" }
      ],
      "correct": "b",
      "explanation": "java.io.File is still present for compatibility, but NIO.2's Files/Path API gives clearer failure signals (specific exceptions instead of a bare false or null) and covers more filesystem operations."
    }
  ]
}
```

## What's next

That's file I/O covered from the classic streams up through the modern NIO.2 API. The next module shifts to functional programming in Java: lambda expressions, method references, and the Stream API — tools that transform how you process collections like TaskFlow's lists of tasks.
