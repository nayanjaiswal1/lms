---
kind: quiz
id_key: java-mastery/concurrency/quiz
course: java-mastery
section: concurrency
section_title: "Concurrency"
section_position: 11
title: "Module Assessment: Concurrency"
position: 4
estimated_minutes: 30
source: [java-mastery-curriculum.md]
pass_percentage: 70
duration_minutes: 30
questions:
  - id_key: concurrency-vs-parallelism-quiz
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "A single-core machine runs a program with three worker threads. Can that program be concurrent? Can it be parallel?"
    multiple: false
    options:
      - { text: "Concurrent, yes — the OS can time-slice between the three threads. Parallel, no — only one instruction from any thread can execute at the exact same physical instant on one core.", correct: true }
      - { text: "Neither concurrent nor parallel is possible on a single core", correct: false }
      - { text: "Both concurrent and parallel, since Thread objects guarantee true simultaneous execution", correct: false }
      - { text: "Parallel, yes — but not concurrent", correct: false }
    explanation: "Concurrency is a structural property (independent tasks that can interleave); parallelism requires multiple cores actually executing at the same instant. A single core can be concurrent via time-slicing but can never be truly parallel."
  - id_key: race-condition-cause
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Two threads both execute balance++ on a shared int field with no synchronization. What is the root cause of the race condition?"
    multiple: false
    options:
      - { text: "int is not a valid type for shared fields", correct: false }
      - { text: "balance++ is really a read, a modify, and a write, and the JVM offers no guarantee those three steps from one thread won't interleave with another thread's three steps on the same field", correct: true }
      - { text: "Java caches variable values per-thread with no way to synchronize them", correct: false }
      - { text: "The ++ operator only works correctly on final fields", correct: false }
      - { text: "It's not actually a race condition, that's a myth about Java", correct: false }
    explanation: "The three-step read-modify-write nature of ++ is the whole story: without a lock, two threads can interleave those steps and one thread's update is silently lost."
  - id_key: synchronized-mutual-exclusion
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: "What does synchronized guarantee about two methods on the same object, both marked synchronized?"
    multiple: false
    options:
      - { text: "They run in parallel on separate cores for speed", correct: false }
      - { text: "Only one of them can be executing on that object at a time — the second caller blocks until the first exits", correct: true }
      - { text: "They are automatically retried if they throw an exception", correct: false }
      - { text: "Nothing — synchronized only affects static methods", correct: false }
    explanation: "synchronized methods on the same object share that object's intrinsic lock. Only one thread can hold the lock at a time, so calls to any synchronized method on that object are mutually exclusive."
  - id_key: executorservice-vs-raw-thread
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "TaskFlow needs to process 50,000 queued tasks. Why is submitting them to a fixed-size ExecutorService a better default than creating 50,000 raw Thread objects?"
    multiple: false
    options:
      - { text: "Raw threads cannot return a result at all, under any circumstances", correct: false }
      - { text: "A bounded pool reuses a small number of threads and queues excess work, avoiding the memory and scheduling overhead of 50,000 live OS threads at once", correct: true }
      - { text: "ExecutorService tasks run without any actual threads being created", correct: false }
      - { text: "There's no practical difference; both approaches scale identically", correct: false }
      - { text: "Raw Thread objects are deprecated in modern Java", correct: false }
    explanation: "Each OS thread costs memory (a stack) and scheduling overhead. A bounded pool processes a large backlog with a small, fixed number of live threads, queuing the rest — this is precisely the reuse-and-bounded-resource-usage argument for thread pools."
  - id_key: completablefuture-vs-future-get
    type: mcq
    difficulty: advanced
    points: 2
    prompt: "What's the key advantage of chaining work with CompletableFuture's thenApply/thenCompose over calling Future.get() and then doing the next step manually?"
    multiple: false
    options:
      - { text: "thenApply and thenCompose describe the next step to run once a result is ready without blocking the calling thread to wait for it, unlike get() which blocks immediately", correct: true }
      - { text: "CompletableFuture cannot throw exceptions, making it strictly safer", correct: false }
      - { text: "thenApply runs on the same thread as the original computation, guaranteeing ordering", correct: false }
      - { text: "There's no real difference — CompletableFuture is just a renamed Future", correct: false }
    explanation: "Future.get() blocks the calling thread right away. CompletableFuture lets you describe a pipeline of dependent steps that run as results become available, only blocking (if ever) at the very end when you need the final value."
  - id_key: concurrency-sum-of-squares
    type: coding
    difficulty: intermediate
    points: 4
    prompt: >-
      TaskFlow needs to compute the sum of squares of a list of numeric task weights using a
      thread pool. Read an integer N, then read N integers (whitespace/newline separated).
      Submit each number as a separate Callable<Integer> task to an ExecutorService that
      computes its square. Collect every Future, sum all the squared results (joining all
      tasks before summing so the result is deterministic), and print a single integer: the
      total sum. Print nothing else.
    languages: [java]
    starter_code:
      java: |
        import java.util.ArrayList;
        import java.util.List;
        import java.util.Scanner;
        import java.util.concurrent.Callable;
        import java.util.concurrent.ExecutorService;
        import java.util.concurrent.Executors;
        import java.util.concurrent.Future;

        public class Main {
            public static void main(String[] args) throws Exception {
                Scanner scanner = new Scanner(System.in);
                int n = scanner.nextInt();

                ExecutorService pool = Executors.newFixedThreadPool(4);
                List<Future<Integer>> futures = new ArrayList<>();

                // TODO: for each of the n integers read from input, submit a Callable<Integer>
                // to the pool that computes its square, collecting each Future in `futures`.

                // TODO: sum every future's result (future.get() blocks until that task is done)
                // and print the total sum, with no extra text.

                pool.shutdown();
            }
        }
    test_cases:
      - { stdin: "3\n1 2 3", expected: "14", hidden: false, weight: 1 }
      - { stdin: "4\n2 2 2 2", expected: "16", hidden: true, weight: 1 }
      - { stdin: "1\n5", expected: "25", hidden: true, weight: 1 }
      - { stdin: "5\n1 2 3 4 5", expected: "55", hidden: true, weight: 1 }
      - { stdin: "2\n0 0", expected: "0", hidden: true, weight: 1 }
    explanation: >-
      Each of the n integers becomes its own Callable<Integer> submitted to the pool
      (pool.submit(() -> value * value)), stored in a List<Future<Integer>>. A second loop
      calls future.get() on every entry (which blocks until that specific task completes)
      and accumulates the sum. Because every Future is resolved before the total is printed,
      the final sum is identical every run regardless of which order the pool's threads
      actually finish their work in.
  - id_key: concurrency-reflection
    type: subjective
    difficulty: beginner
    points: 2
    prompt: >-
      In your own words: which concept from this module (raw Threads and Runnable, race
      conditions and synchronized, ExecutorService/Callable/Future, or CompletableFuture and
      concurrent collections) felt least intuitive, and why? Be specific — this feeds
      directly into what gets flagged for review.
    multiple: false
    options: []
    explanation: "Graded for genuine, specific reflection rather than a single correct answer — the goal is to surface which concurrency concept you're actually shakiest on."
---
