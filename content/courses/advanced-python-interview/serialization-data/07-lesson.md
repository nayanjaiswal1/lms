---
kind: lesson
id_key: advanced-python-interview/serialization-data/bytes
course: advanced-python-interview
section: serialization-data
section_title: "Serialization & Low-Level Data"
section_position: 4
title: "`bytes`"
position: 6
estimated_minutes: 12
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

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "serialization-data-bytes-q1",
      "type": "mcq",
      "prompt": "What's the fundamental difference between str and bytes in Python?",
      "options": [
        { "id": "a", "text": "str is a sequence of Unicode characters for text; bytes is a sequence of raw 0-255 integers for binary data" },
        { "id": "b", "text": "bytes is just a faster version of str with no functional difference" },
        { "id": "c", "text": "str can only hold ASCII characters, bytes holds everything else" },
        { "id": "d", "text": "They are interchangeable and Python converts automatically" }
      ],
      "correct": "a",
      "explanation": "str represents human-readable Unicode text; bytes represents raw binary data as integers 0-255. Converting between them always requires an explicit encode()/decode() step and an encoding name."
    },
    {
      "id": "serialization-data-bytes-q2",
      "type": "mcq",
      "prompt": "What happens if you call .decode('utf-8') on bytes that don't represent valid UTF-8 text?",
      "options": [
        { "id": "a", "text": "Python silently returns an empty string" },
        { "id": "b", "text": "It raises a UnicodeDecodeError" },
        { "id": "c", "text": "It automatically detects and uses the correct encoding instead" },
        { "id": "d", "text": "It returns the raw bytes unchanged" }
      ],
      "correct": "b",
      "explanation": "decode() assumes the bytes were produced with the specified encoding; if the byte sequence isn't valid under that encoding, Python raises UnicodeDecodeError rather than guessing."
    }
  ]
}
```
