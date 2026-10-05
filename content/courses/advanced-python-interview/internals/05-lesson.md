---
kind: lesson
id_key: advanced-python-interview/serialization-data/bytes
course: advanced-python-interview
section: internals
section_title: "Memory & the Interpreter"
section_position: 5
section_group: Advanced
title: "`bytes`"
position: 4
estimated_minutes: 24
source: ["fifty-advanced-python-concepts/33.bytes.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_26_40.md"]
---
A Python `str` is a sequence of Unicode characters — text, meant for humans to read. A `bytes` object is a sequence of raw integers in the range 0–255 — the actual binary data a file, a network socket, or an image format works with. Confusing the two (or forgetting to convert between them) is one of the most common sources of `UnicodeDecodeError`/`TypeError` bugs when working with files and network I/O.

## Writing and reading binary data

```python
# Write binary data to a file
with open("example.bin", "wb") as f:   # "wb" = write bytes
    f.write(b"Binary data")

# Read it back
with open("example.bin", "rb") as f:   # "rb" = read bytes
    data = f.read()
    print(data)        # b'Binary data'
    print(type(data))  # <class 'bytes'>
```

The `b"..."` prefix creates a `bytes` literal. Opening a file in `"wb"`/`"rb"` mode (instead of `"w"`/`"r"`) tells Python to hand back raw bytes instead of trying to decode them as text — mixing modes (writing bytes to a text-mode file, or vice versa) raises a `TypeError` immediately.

## Converting between `str` and `bytes`

Text becomes bytes via an explicit **encoding**, and bytes become text via the matching **decoding**:

```python
text = "Hello, world"
encoded = text.encode("utf-8")     # b'Hello, world'
decoded = encoded.decode("utf-8")  # 'Hello, world'

print(encoded, type(encoded))
print(decoded, type(decoded))
```

If the bytes don't actually represent valid text in the encoding you decode with, `.decode()` raises `UnicodeDecodeError` — this is why "just decode it" is unsafe without knowing (or being told, e.g. via a `Content-Type` header) which encoding produced the bytes in the first place.

## `bytearray`: the mutable sibling

`bytes` is immutable, like `str`. When binary data needs to be built up or modified in place — assembling a network packet piece by piece — `bytearray` is the mutable equivalent:

```python
buf = bytearray(b"Hello")
buf[0] = ord("J")   # mutate a single byte in place
buf.extend(b", world")
print(bytes(buf))   # b'Jello, world'
```

## Why this matters

`bytes` shows up anywhere Python talks to something that isn't Python: reading an image or audio file, parsing a binary network protocol, computing a hash (`hashlib` operates on bytes, not str), or streaming a large file without loading it fully as decoded text. Treating binary data as text — or text as binary — is a bug waiting for the first non-ASCII input.

## `memoryview`

Slicing a `bytes` or `bytearray` object copies the sliced data into a brand-new object. For a million-byte buffer, slicing out even a small chunk means allocating and copying that chunk — wasted work if all you needed was to *look at* part of the buffer. `memoryview` fixes this by exposing the same underlying memory through a view, with no copy at all.

### Copy vs. view

```python
import sys

data = bytearray(b"A" * 10**6)  # 1,000,000 bytes
mv = memoryview(data)

# Slicing a memoryview creates another view — no copy
mv_slice = mv[100:100000]

# Slicing the bytearray directly copies ~99,900 bytes into a new object
bytes_slice = data[100:100000]

print(f"memoryview slice: {sys.getsizeof(mv_slice):,} bytes")
print(f"bytearray slice:  {sys.getsizeof(bytes_slice):,} bytes")
```

`mv_slice` reports a small, roughly constant size — it's just a window (a pointer, an offset, and a length) into `data`'s existing memory. `bytes_slice` reports a size proportional to the ~99,900 bytes it actually copied. The bigger the buffer and the more slicing you do, the more this gap matters.

### Views can write back to the original

Because a `memoryview` shares memory with its source (when the source is mutable, like `bytearray`), writing through the view changes the original:

```python
buf = bytearray(b"Hello, World!")
mv = memoryview(buf)

mv[0:5] = b"HELLO"   # writes directly into buf's memory, no copy
print(buf)           # bytearray(b'HELLO, World!')
```

This cuts both ways — it's the whole point when you want in-place mutation of a large buffer, but it means a `memoryview` keeps its source object alive and mutable-through-the-view for as long as the view exists, which is worth remembering before handing a view out to code you don't control.

### Where this matters in practice

Anywhere large binary payloads move through a program without needing full copies at every step: reading network buffers, processing large files in chunks, or feeding data into C extensions (NumPy, `struct`, `array`) that understand the buffer protocol directly. A web server parsing a large multipart upload, or a protocol parser slicing a byte stream into fields, is exactly the kind of hot path where "avoid the copy" turns into a measurable memory and latency win.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "serialization-data-bytes-q1",
      "type": "mcq",
      "prompt": "What's the fundamental difference between str and bytes in Python?",
      "options": [
        {
          "id": "a",
          "text": "str is a sequence of Unicode characters for text; bytes is a sequence of raw 0-255 integers for binary data"
        },
        {
          "id": "b",
          "text": "bytes is just a faster version of str with no functional difference"
        },
        {
          "id": "c",
          "text": "str can only hold ASCII characters, bytes holds everything else"
        },
        {
          "id": "d",
          "text": "They are interchangeable and Python converts automatically"
        }
      ],
      "correct": "a",
      "explanation": "str represents human-readable Unicode text; bytes represents raw binary data as integers 0-255. Converting between them always requires an explicit encode()/decode() step and an encoding name."
    },
    {
      "id": "serialization-data-bytes-q2",
      "type": "mcq",
      "prompt": "What happens if you call .decode('utf-8') on bytes that don't represent valid UTF-8 text?",
      "options": [
        {
          "id": "a",
          "text": "Python silently returns an empty string"
        },
        {
          "id": "b",
          "text": "It raises a UnicodeDecodeError"
        },
        {
          "id": "c",
          "text": "It automatically detects and uses the correct encoding instead"
        },
        {
          "id": "d",
          "text": "It returns the raw bytes unchanged"
        }
      ],
      "correct": "b",
      "explanation": "decode() assumes the bytes were produced with the specified encoding; if the byte sequence isn't valid under that encoding, Python raises UnicodeDecodeError rather than guessing."
    },
    {
      "id": "serialization-data-memoryview-q1",
      "type": "mcq",
      "prompt": "Why does memoryview slicing use far less memory than slicing a bytearray directly?",
      "options": [
        {
          "id": "a",
          "text": "memoryview compresses the data automatically"
        },
        {
          "id": "b",
          "text": "A memoryview slice is a view (pointer + offset + length) into the existing memory, not a copy of the bytes"
        },
        {
          "id": "c",
          "text": "memoryview only supports small buffers"
        },
        {
          "id": "d",
          "text": "bytearray slicing is actually a bug that will be fixed"
        }
      ],
      "correct": "b",
      "explanation": "Slicing a memoryview creates another lightweight view referencing the same underlying memory; slicing a bytearray directly allocates a new object and copies the sliced bytes into it."
    },
    {
      "id": "serialization-data-memoryview-q2",
      "type": "mcq",
      "prompt": "In `buf = bytearray(...); mv = memoryview(buf); mv[0:5] = b\"HELLO\"`, what happens to buf?",
      "options": [
        {
          "id": "a",
          "text": "buf is unchanged — memoryview is always read-only"
        },
        {
          "id": "b",
          "text": "buf's first 5 bytes are modified in place, since mv shares memory with buf"
        },
        {
          "id": "c",
          "text": "A TypeError is raised because memoryview can't be assigned to"
        },
        {
          "id": "d",
          "text": "A new bytearray is created, leaving buf untouched"
        }
      ],
      "correct": "b",
      "explanation": "Because memoryview shares memory with its mutable source, writing through the view mutates buf directly — no copy is made in either direction."
    }
  ]
}
```
