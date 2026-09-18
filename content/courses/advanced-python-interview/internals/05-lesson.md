---
kind: lesson
id_key: advanced-python-interview/internals/walrus-operator
course: advanced-python-interview
section: internals
section_title: "Memory & the Interpreter"
section_position: 0
title: "Walrus Operator (`:=`)"
position: 4
estimated_minutes: 10
source: ["fifty-advanced-python-concepts/5.walrus_operator.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_1_10.md"]
---
The walrus operator (`:=`, officially the **assignment expression**, added in Python 3.8) lets you assign a value to a name *and* produce that value as the result of the expression, in one step. Plain `=` is a statement — it can't appear inside an `if` condition or a comprehension. `:=` can.

## Before and after

```python
my_dict = {"my_var": 42}

def lookup_v1(d):
    my_var = d.get("my_var")   # separate assignment statement
    if my_var:
        return my_var

def lookup_v2(d):
    if my_var := d.get("my_var"):  # assign AND test in one expression
        return my_var
```

Both functions behave identically — `lookup_v2` just collapses "assign, then check" into a single line. The win compounds once the value being checked is expensive to compute or you'd otherwise have to write it twice.

## Where it earns its keep

```python
# Without walrus: call the expensive function twice, or add a throwaway line
data = fetch_data()
if data:
    process(data)

# With walrus: compute once, inline in the condition
if (data := fetch_data()):
    process(data)
```

```python
# Comprehensions: filter on a computed value without a nested function call
values = [1, 2, 3, 4, 5, 6]
results = [y for x in values if (y := x * x) > 10]
print(results)  # [16, 25, 36] — y is both the filter and the yielded value
```

That comprehension example is the case a plain `=` genuinely cannot express at all: without `:=`, computing `x * x` once and both filtering *and* returning it would require a helper function or a `map`/`filter` chain — the walrus lets a comprehension reuse an intermediate value without recomputing it.

The operator is deliberately minor — it doesn't change what's *possible* in Python, only how tersely a specific pattern (compute-then-check) can be written — but reaching for it in the right spot (a `while` loop reading chunks, a comprehension filtering on a derived value) is a small, reliable signal of comfort with the language.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "internals-walrus-operator-q1",
      "type": "mcq",
      "prompt": "What can `if (data := fetch_data()):` do that `data = fetch_data(); if data:` cannot?",
      "options": [
        { "id": "a", "text": "Nothing functionally different — it's purely a style preference for this exact case" },
        { "id": "b", "text": "It skips calling fetch_data() entirely" },
        { "id": "c", "text": "It makes fetch_data() run asynchronously" },
        { "id": "d", "text": "It caches the result across multiple calls" }
      ],
      "correct": "a",
      "explanation": "For a simple assign-then-check, := is equivalent to a separate assignment statement followed by a check — its real value shows up where a plain assignment statement isn't syntactically allowed at all, like inside a comprehension's condition."
    },
    {
      "id": "internals-walrus-operator-q2",
      "type": "mcq",
      "prompt": "`[y for x in values if (y := x * x) > 10]` — why is the walrus operator necessary here, not just convenient?",
      "options": [
        { "id": "a", "text": "A comprehension's filter clause can't contain a plain assignment statement, so without :=, x*x would need to be computed twice or via a helper" },
        { "id": "b", "text": "List comprehensions don't support arithmetic without it" },
        { "id": "c", "text": "It's required syntax for any comprehension with a filter" },
        { "id": "d", "text": "It prevents the comprehension from allocating a new list" }
      ],
      "correct": "a",
      "explanation": "A comprehension's `if` clause is an expression context, not a statement context — plain `=` isn't valid there. The walrus operator is what lets the filter both compute and reuse x*x in one expression."
    }
  ]
}
```
