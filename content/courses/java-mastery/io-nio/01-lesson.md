---
kind: lesson
id_key: java-mastery/io-nio/file-io-try-with-resources
course: java-mastery
section: io-nio
section_title: "File I/O & NIO"
section_position: 9
title: "File I/O Basics & Try-With-Resources"
position: 0
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
Everything TaskFlow has done so far lives only in memory — the moment the program ends, every `Task` and `User` object vanishes. Real applications persist data, and the most basic way Java writes and reads text is `FileWriter` and `FileReader`.

## Writing a file with `FileWriter`

```java
import java.io.FileWriter;
import java.io.IOException;

public class Main {
    public static void main(String[] args) throws IOException {
        String exportPath = "taskflow-export.txt";

        try (FileWriter writer = new FileWriter(exportPath)) {
            writer.write("Design database schema,6,HIGH\n");
            writer.write("Build REST API,10,HIGH\n");
            writer.write("Write tests,4,MEDIUM\n");
        }

        System.out.println("Export written to " + exportPath);
    }
}
```

`FileWriter` opens (or creates) a file and writes raw text to it. `throws IOException` on `main` is necessary because file operations can fail for reasons entirely outside your program's control — the disk is full, the path doesn't exist, permissions are wrong — and Java forces you to acknowledge that with a **checked exception**.

## Why `try-with-resources` matters

A `FileWriter` holds a real operating-system file handle open. Operating systems place a hard limit on how many file handles a process can have open simultaneously — leak enough of them (by forgetting to close files after use) and a long-running program eventually fails to open *any* file, including ones it desperately needs, like its own log file.

```java
import java.io.FileWriter;
import java.io.IOException;

public class Main {
    public static void main(String[] args) {
        String exportPath = "taskflow-leaky.txt";

        // The manual, error-prone way — DON'T do this:
        FileWriter writer = null;
        try {
            writer = new FileWriter(exportPath);
            writer.write("Design database schema,6,HIGH\n");
            // If an exception is thrown here, the code below never runs, and the file handle leaks.
        } catch (IOException e) {
            System.out.println("Write failed: " + e.getMessage());
        } finally {
            // You have to remember this yourself, AND handle the fact that close() can also throw.
            if (writer != null) {
                try {
                    writer.close();
                } catch (IOException e) {
                    System.out.println("Close failed: " + e.getMessage());
                }
            }
        }

        System.out.println("Done (the hard way)");
    }
}
```

That's a lot of ceremony just to guarantee a file gets closed — and it's easy to get wrong (forget the `finally`, forget the null check, forget `close()` itself can throw). `try-with-resources`, shown in the first example, replaces all of it: any resource declared in the `try (...)` parentheses is **automatically closed** when the block exits, whether it exits normally or via an exception. It works for any class implementing `java.io.Closeable` (or the broader `AutoCloseable`), which includes `FileWriter`, `FileReader`, and every stream class in `java.io`.

## Reading it back with `FileReader`

```java
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;

public class Main {
    public static void main(String[] args) throws IOException {
        String path = "taskflow-roundtrip.txt";

        try (FileWriter writer = new FileWriter(path)) {
            writer.write("Design database schema,6,HIGH\n");
            writer.write("Build REST API,10,HIGH\n");
        }

        StringBuilder contents = new StringBuilder();
        try (FileReader reader = new FileReader(path)) {
            int character;
            // read() returns one char at a time as an int, or -1 at end of stream
            while ((character = reader.read()) != -1) {
                contents.append((char) character);
            }
        }

        System.out.print(contents);
    }
}
```

`FileReader.read()` returns one character at a time as an `int` (the `char` value, or `-1` once the stream is exhausted — `-1` can't be confused with a real character because `char` values are never negative). Reading one character at a time works, but it's slow for anything beyond tiny files — that's exactly the problem the next lesson's `BufferedReader` solves.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "io-nio-file-io-try-with-resources-q1",
      "type": "mcq",
      "prompt": "What's the real risk of forgetting to close a FileWriter?",
      "options": [
        { "id": "a", "text": "The written data is silently discarded" },
        { "id": "b", "text": "The program crashes immediately" },
        { "id": "c", "text": "The underlying OS file handle stays open, and enough leaks can exhaust the process's file handle limit" },
        { "id": "d", "text": "Nothing — Java automatically closes files during garbage collection at a predictable time" }
      ],
      "correct": "c",
      "explanation": "Operating systems cap how many file handles a process can hold open at once. Leaked handles from unclosed files accumulate and eventually block the program from opening any file at all — garbage collection timing is not predictable enough to rely on for cleanup."
    },
    {
      "id": "io-nio-file-io-try-with-resources-q2",
      "type": "mcq",
      "prompt": "What does try-with-resources guarantee compared to manual try/finally?",
      "options": [
        { "id": "a", "text": "It guarantees the resource is closed automatically when the block exits, whether normally or via exception, with no explicit close() call or null-check needed" },
        { "id": "b", "text": "It prevents any exception from ever being thrown inside the block" },
        { "id": "c", "text": "It only works with FileWriter, not other resource types" },
        { "id": "d", "text": "It makes file writes synchronous when they'd otherwise be asynchronous" }
      ],
      "correct": "a",
      "explanation": "Any resource implementing Closeable/AutoCloseable declared in the try(...) parentheses is closed automatically on exit from the block, replacing the error-prone manual finally + null-check + nested try/catch pattern."
    },
    {
      "id": "io-nio-file-io-try-with-resources-q3",
      "type": "mcq",
      "prompt": "Why does FileReader.read() return an int rather than a char?",
      "options": [
        { "id": "a", "text": "So it can return -1 to signal end-of-stream, a value no valid char can represent" },
        { "id": "b", "text": "int and char are interchangeable in Java, so it makes no difference" },
        { "id": "c", "text": "Because reading always returns two characters packed together" },
        { "id": "d", "text": "To support Unicode characters larger than a char can hold" }
      ],
      "correct": "a",
      "explanation": "char is always non-negative, so read() uses the wider int return type specifically to be able to return -1 as an unambiguous end-of-stream sentinel that no real character value could ever collide with."
    }
  ]
}
```

## What's next

Reading one character (or one byte) at a time is correct but slow. The next lesson introduces `BufferedReader` and `BufferedWriter`, which batch reads and writes internally for a dramatic performance difference on anything beyond trivially small files.
