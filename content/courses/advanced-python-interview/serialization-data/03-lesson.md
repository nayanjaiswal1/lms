---
kind: lesson
id_key: advanced-python-interview/serialization-data/heapq
course: advanced-python-interview
section: serialization-data
section_title: "Serialization & Low-Level Data"
section_position: 4
title: "`heapq`"
position: 2
estimated_minutes: 12
source: ["fifty-advanced-python-concepts/29.heapq.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_26_40.md"]
---
`heapq` gives Python a priority queue built on an ordinary list, kept in **binary heap** order: the smallest element is always at index `0`, and `heappush`/`heappop` maintain that invariant in `O(log n)` instead of the `O(n)` a naive "sort the list every time" approach would cost.

## Why not just sort a list?

A plain list can act as a priority queue if you re-sort it after every insert, but that's `O(n log n)` per insert. A heap only restores the invariant along one path from the leaf to the root (or root to leaf), so both `heappush` and `heappop` are `O(log n)` — the difference matters the moment a scheduler is handling thousands of tasks.

## Building a task scheduler

```python
import heapq

class TaskScheduler:
    def __init__(self):
        self.task_queue = []  # a min-heap of (priority, task_name) tuples

    def add_task(self, priority, task_name):
        # Lower priority number = executed sooner
        heapq.heappush(self.task_queue, (priority, task_name))

    def execute_task(self):
        if not self.task_queue:
            print("No tasks to execute.")
            return
        priority, task_name = heapq.heappop(self.task_queue)
        print(f"Executing '{task_name}' (priority {priority})")

    def peek_next_task(self):
        if not self.task_queue:
            print("No tasks in the queue.")
            return
        priority, task_name = self.task_queue[0]
        print(f"Next up: '{task_name}' (priority {priority})")


scheduler = TaskScheduler()
scheduler.add_task(3, "Write report")
scheduler.add_task(1, "Fix critical bug")
scheduler.add_task(2, "Attend team meeting")

scheduler.peek_next_task()   # Fix critical bug is priority 1 — heap keeps it at the front
scheduler.execute_task()
scheduler.execute_task()
scheduler.execute_task()
scheduler.execute_task()     # empty queue
```

`heapq` compares the tuples element by element, so `(1, "Fix critical bug")` sorts before `(2, "Attend team meeting")` purely on the first element — ties on priority fall back to comparing the task name, which is usually fine but worth knowing if two priorities can collide and the names aren't comparable (mixing types there raises `TypeError`).

## Where this shows up

Beyond task schedulers: Dijkstra's shortest-path algorithm pops the "closest known node" every iteration, event simulators pop the "next event in time," and `heapq.nlargest`/`heapq.nsmallest` give you the top-k of a collection without fully sorting it — all the same underlying idea of "give me the extreme element next, cheaply, repeatedly."

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "serialization-data-heapq-q1",
      "type": "mcq",
      "prompt": "Why is heapq.heappush faster than re-sorting a list after every insert?",
      "options": [
        { "id": "a", "text": "It only restores the heap invariant along one path, costing O(log n) instead of O(n log n)" },
        { "id": "b", "text": "heapq stores data in a hash table instead of a list" },
        { "id": "c", "text": "It skips maintaining any order at all" },
        { "id": "d", "text": "Python lists are automatically kept sorted" }
      ],
      "correct": "a",
      "explanation": "A heap only needs to bubble the new element up (or down) one path to the root, an O(log n) operation, versus O(n log n) to fully re-sort the list on every insert."
    },
    {
      "id": "serialization-data-heapq-q2",
      "type": "mcq",
      "prompt": "In TaskScheduler, why does heapq.heappush use (priority, task_name) tuples with priority first?",
      "options": [
        { "id": "a", "text": "Tuples must always have exactly two elements" },
        { "id": "b", "text": "heapq compares tuples element-by-element, so ordering by priority first makes the heap sort by priority" },
        { "id": "c", "text": "task_name needs to come first for heapq to work at all" },
        { "id": "d", "text": "It's arbitrary and has no effect on ordering" }
      ],
      "correct": "b",
      "explanation": "heapq.heappush/heappop maintain min-heap order using Python's default tuple comparison, which compares the first element first — putting priority first means the heap orders by priority."
    }
  ]
}
```
