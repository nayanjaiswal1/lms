---
kind: lesson
id_key: java-mastery/io-nio/buffered-reader-writer
course: java-mastery
section: io-nio
section_title: "File I/O & NIO"
section_position: 9
title: "BufferedReader & BufferedWriter"
position: 1
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
Every `FileReader.read()` call and every `FileWriter.write()` call is, underneath, a request to the operating system — and system calls are expensive relative to in-memory work. Reading a 10,000-line file one character at a time means potentially tens of thousands of system calls. `BufferedReader` and `BufferedWriter` fix this by batching.

## Why buffering matters

A **buffer** is just an in-memory chunk (an array) that sits between your code and the OS. `BufferedReader` reads a large block of the file into that buffer in one system call, then serves your individual `read()`/`readLine()` calls out of memory until the buffer runs dry — at which point it refills with one more system call. `BufferedWriter` works the same way in reverse: your `write()` calls accumulate in the buffer and get flushed to disk in large batches instead of one tiny write per call.

```java
import java.io.BufferedWriter;
import java.io.FileWriter;
import java.io.IOException;

public class Main {
    public static void main(String[] args) throws IOException {
        String path = "taskflow-buffered-export.txt";

        // Wrap a FileWriter in a BufferedWriter — writes accumulate in memory,
        // flushed to disk in large batches instead of one system call per write().
        try (BufferedWriter writer = new BufferedWriter(new FileWriter(path))) {
            writer.write("Design database schema,6,HIGH");
            writer.newLine(); // portable newline — matches the OS convention
            writer.write("Build REST API,10,HIGH");
            writer.newLine();
            writer.write("Write tests,4,MEDIUM");
            writer.newLine();
        }

        System.out.println("Wrote buffered export to " + path);
    }
}
```

`writer.newLine()` is preferred over hardcoding `"\n"` because it writes whatever line separator the host OS actually uses (`\n` on Linux/macOS, `\r\n` on Windows) — a small but real portability detail.

## Reading line-by-line with `BufferedReader.readLine()`

```java
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;

public class Main {
    public static void main(String[] args) throws IOException {
        String path = "taskflow-buffered-roundtrip.txt";

        try (BufferedWriter writer = new BufferedWriter(new FileWriter(path))) {
            writer.write("Design database schema,6,HIGH");
            writer.newLine();
            writer.write("Build REST API,10,HIGH");
            writer.newLine();
            writer.write("Write tests,4,MEDIUM");
            writer.newLine();
        }

        int totalHours = 0;
        try (BufferedReader reader = new BufferedReader(new FileReader(path))) {
            String line;
            // readLine() returns null once the stream is exhausted — the loop condition below
            // both assigns line AND checks for that sentinel in one expression
            while ((line = reader.readLine()) != null) {
                String[] fields = line.split(",");
                String name = fields[0];
                int hours = Integer.parseInt(fields[1]);
                String priority = fields[2];

                System.out.println(name + " -> " + hours + "h (" + priority + ")");
                totalHours += hours;
            }
        }

        System.out.println("Total estimated hours: " + totalHours);
    }
}
```

`readLine()` returns an entire line as a `String`, with the line terminator already stripped, or `null` at end of stream — `null` here plays the same role `-1` played for `FileReader.read()`: an unambiguous sentinel a real line can never equal (an empty line comes back as `""`, not `null`). This `while ((line = reader.readLine()) != null)` pattern is the standard idiom for reading a whole file line by line in Java; you'll see it constantly.

## Layered streams: the decorator pattern in practice

`new BufferedReader(new FileReader(path))` is two objects layered together: the inner `FileReader` talks to the actual file, and the outer `BufferedReader` wraps it, adding buffering and `readLine()` without `FileReader` itself needing to change. This is Java's I/O library applying the **decorator pattern** throughout — small, focused stream classes that wrap each other to add capability, rather than one giant class doing everything. You'll see this same wrap-around-a-stream shape again with things like `BufferedInputStream` wrapping a `FileInputStream` for binary data.

## Closing writers still matters — buffering doesn't remove that

Buffering changes *when* data physically reaches the disk, not *whether* it needs to. A `BufferedWriter` accumulates written text in its internal buffer and only flushes it out to the underlying `FileWriter` once that buffer fills up — or when `close()` (or an explicit `flush()`) runs. Skip the `try-with-resources` block, or crash before it exits, and whatever's still sitting in the buffer never makes it to disk at all, even though your code technically "wrote" it. This is a sharper version of the same resource-leak problem the previous lesson covered with `FileWriter`: with buffering in the mix, an unclosed writer doesn't just leak a handle, it can silently drop data that was never flushed.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "io-nio-buffered-reader-writer-q1",
      "type": "mcq",
      "prompt": "Why is BufferedReader typically faster than reading directly with FileReader.read()?",
      "options": [
        { "id": "a", "text": "It compresses the file contents before reading" },
        { "id": "b", "text": "It reads large chunks into an in-memory buffer with fewer system calls, serving individual read requests from memory instead of hitting the OS every time" },
        { "id": "c", "text": "It skips characters it considers unimportant" },
        { "id": "d", "text": "It reads the file in a separate background thread automatically" }
      ],
      "correct": "b",
      "explanation": "System calls are relatively expensive. Buffering amortizes that cost across many reads/writes by batching data transfer into large chunks instead of one system call per character."
    },
    {
      "id": "io-nio-buffered-reader-writer-q2",
      "type": "mcq",
      "prompt": "What does BufferedReader.readLine() return once the end of the file is reached?",
      "options": [
        { "id": "a", "text": "An empty string \"\"" },
        { "id": "b", "text": "-1" },
        { "id": "c", "text": "null" },
        { "id": "d", "text": "It throws an exception" }
      ],
      "correct": "c",
      "explanation": "readLine() returns null at end-of-stream, distinct from an empty line (which returns \"\"). The common while ((line = reader.readLine()) != null) idiom relies on this."
    },
    {
      "id": "io-nio-buffered-reader-writer-q3",
      "type": "mcq",
      "prompt": "In `new BufferedReader(new FileReader(path))`, what role does the outer BufferedReader play?",
      "options": [
        { "id": "a", "text": "It replaces FileReader entirely and ignores it" },
        { "id": "b", "text": "It wraps FileReader, adding buffering and line-based reading, without FileReader itself changing" },
        { "id": "c", "text": "It converts the file to binary format" },
        { "id": "d", "text": "It opens a second, independent connection to the file" }
      ],
      "correct": "b",
      "explanation": "This is Java I/O's decorator pattern: FileReader handles the raw connection to the file, and BufferedReader wraps it to add buffering and convenience methods like readLine() on top."
    }
  ]
}
```

## What's next

`FileReader`/`FileWriter`/`BufferedReader`/`BufferedWriter` are all part of the original `java.io` package. The next lesson covers `java.nio.file` — the modern, more capable file API introduced in Java 7 (NIO.2), and when it's preferable to the classic `java.io.File`.
