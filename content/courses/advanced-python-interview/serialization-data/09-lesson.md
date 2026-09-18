---
kind: lesson
id_key: advanced-python-interview/serialization-data/memoryview
course: advanced-python-interview
section: serialization-data
section_title: "Serialization & Low-Level Data"
section_position: 4
title: "`memoryview`"
position: 8
estimated_minutes: 12
source: ["fifty-advanced-python-concepts/35.memoryview.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_26_40.md"]
---
Slicing a `bytes` or `bytearray` object copies the sliced data into a brand-new object. For a million-byte buffer, slicing out even a small chunk means allocating and copying that chunk — wasted work if all you needed was to *look at* part of the buffer. `memoryview` fixes this by exposing the same underlying memory through a view, with no copy at all.

## Copy vs. view

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

## Views can write back to the original

Because a `memoryview` shares memory with its source (when the source is mutable, like `bytearray`), writing through the view changes the original:

```python
buf = bytearray(b"Hello, World!")
mv = memoryview(buf)

mv[0:5] = b"HELLO"   # writes directly into buf's memory, no copy
print(buf)           # bytearray(b'HELLO, World!')
```

This cuts both ways — it's the whole point when you want in-place mutation of a large buffer, but it means a `memoryview` keeps its source object alive and mutable-through-the-view for as long as the view exists, which is worth remembering before handing a view out to code you don't control.

## Where this matters in practice

Anywhere large binary payloads move through a program without needing full copies at every step: reading network buffers, processing large files in chunks, or feeding data into C extensions (NumPy, `struct`, `array`) that understand the buffer protocol directly. A web server parsing a large multipart upload, or a protocol parser slicing a byte stream into fields, is exactly the kind of hot path where "avoid the copy" turns into a measurable memory and latency win.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "serialization-data-memoryview-q1",
      "type": "mcq",
      "prompt": "Why does memoryview slicing use far less memory than slicing a bytearray directly?",
      "options": [
        { "id": "a", "text": "memoryview compresses the data automatically" },
        { "id": "b", "text": "A memoryview slice is a view (pointer + offset + length) into the existing memory, not a copy of the bytes" },
        { "id": "c", "text": "memoryview only supports small buffers" },
        { "id": "d", "text": "bytearray slicing is actually a bug that will be fixed" }
      ],
      "correct": "b",
      "explanation": "Slicing a memoryview creates another lightweight view referencing the same underlying memory; slicing a bytearray directly allocates a new object and copies the sliced bytes into it."
    },
    {
      "id": "serialization-data-memoryview-q2",
      "type": "mcq",
      "prompt": "In `buf = bytearray(...); mv = memoryview(buf); mv[0:5] = b\"HELLO\"`, what happens to buf?",
      "options": [
        { "id": "a", "text": "buf is unchanged — memoryview is always read-only" },
        { "id": "b", "text": "buf's first 5 bytes are modified in place, since mv shares memory with buf" },
        { "id": "c", "text": "A TypeError is raised because memoryview can't be assigned to" },
        { "id": "d", "text": "A new bytearray is created, leaving buf untouched" }
      ],
      "correct": "b",
      "explanation": "Because memoryview shares memory with its mutable source, writing through the view mutates buf directly — no copy is made in either direction."
    }
  ]
}
```
