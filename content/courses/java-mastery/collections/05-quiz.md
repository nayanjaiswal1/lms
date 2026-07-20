---
kind: quiz
id_key: java-mastery/collections/quiz
course: java-mastery
section: collections
section_title: "Collections Framework"
section_position: 7
title: "Module Assessment: Collections Framework"
position: 4
estimated_minutes: 25
source: [java-mastery-curriculum.md]
pass_percentage: 70
duration_minutes: 25
questions:
  - id_key: arraylist-vs-linkedlist-default
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "Which List implementation should you default to for most use cases, and why?"
    multiple: false
    options:
      - { text: "LinkedList, because it's always faster", correct: false }
      - { text: "ArrayList, because it offers fast O(1) indexed access and good cache locality for typical access patterns", correct: true }
      - { text: "Either one, they perform identically in every case", correct: false }
      - { text: "Neither — arrays should always be used instead", correct: false }
    explanation: "ArrayList's array-backed storage gives fast indexed access and covers the large majority of real-world use cases. LinkedList only wins when you specifically need frequent insert/remove at arbitrary positions without indexed access."
  - id_key: set-dedup-guarantee
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "What is the defining guarantee of any Set implementation?"
    multiple: false
    options:
      - { text: "Elements are always sorted", correct: false }
      - { text: "No duplicate elements are allowed", correct: true }
      - { text: "Elements are always accessible by index", correct: false }
      - { text: "Insertion order is always preserved", correct: false }
    explanation: "Every Set implementation guarantees no duplicates. Ordering behavior (none, insertion order, sorted order) varies by implementation — HashSet, LinkedHashSet, TreeSet respectively — but dedup is the one guarantee they all share."
  - id_key: map-getordefault-purpose
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "What problem does map.getOrDefault(key, fallback) solve compared to plain map.get(key)?"
    multiple: false
    options:
      - { text: "It's faster than get() for large maps", correct: false }
      - { text: "It avoids getting back null for a missing key, returning a supplied fallback value instead, without a manual containsKey check", correct: true }
      - { text: "It removes the key after reading it", correct: false }
      - { text: "It only works on TreeMap" }
    explanation: "get() returns null for a missing key, which callers must guard against. getOrDefault() supplies a safe fallback directly, removing the need for a manual containsKey + get pair."
  - id_key: concurrent-modification-fix
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "What is the safe way to remove elements from a List while iterating over it?"
    multiple: false
    options:
      - { text: "Call list.remove(element) directly inside an enhanced for-loop over the same list", correct: false }
      - { text: "Use the list's own Iterator and call Iterator.remove(), which adjusts the iterator's internal state as part of the removal", correct: true }
      - { text: "It's never safe to remove elements while iterating, under any circumstance", correct: false }
      - { text: "Convert the list to an array first, always" }
    explanation: "Modifying a List directly during an enhanced for-loop throws ConcurrentModificationException. Iterator.remove() is safe specifically because it's a method on the iterator itself, which can keep its position consistent as it removes."
  - id_key: comparable-vs-comparator
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A Task class needs to be sorted by priority in one report and by estimated hours in another. What's the appropriate approach?"
    multiple: false
    options:
      - { text: "Implement Comparable<Task> twice with two different compareTo methods", correct: false }
      - { text: "Implement Comparable<Task> once for one natural ordering (e.g. priority), and use separate Comparator instances (e.g. via Comparator.comparing) for the other orderings needed", correct: true }
      - { text: "Sorting by more than one field is not possible in Java", correct: false }
      - { text: "Rewrite the Task class fields every time a new sort order is needed" }
    explanation: "A class can only implement Comparable once, giving it a single natural ordering. Additional orderings are supplied externally as Comparator instances passed to list.sort(comparator) or Collections.sort(list, comparator), without modifying the class."
  - id_key: collections-priority-sort
    type: coding
    difficulty: intermediate
    points: 3
    prompt: >-
      TaskFlow needs to sort a batch of task priorities. Read a single line of
      space-separated integers from stdin (the priority values). Print them sorted in
      ascending order, space-separated, on one line, with no leading or trailing spaces.
    languages: [java]
    starter_code:
      java: |
        import java.util.ArrayList;
        import java.util.Collections;
        import java.util.List;
        import java.util.Scanner;

        public class Main {
            public static void main(String[] args) {
                Scanner scanner = new Scanner(System.in);
                String line = scanner.nextLine();
                // Split line on spaces, parse each as an int, sort ascending,
                // then print them space-separated on one line.

            }
        }
    test_cases:
      - { stdin: "5 3 8 1", expected: "1 3 5 8", hidden: false, weight: 1 }
      - { stdin: "9", expected: "9", hidden: false, weight: 1 }
      - { stdin: "2 2 1", expected: "1 2 2", hidden: true, weight: 1 }
      - { stdin: "10 -3 4 0", expected: "-3 0 4 10", hidden: true, weight: 1 }
      - { stdin: "7 6 5 4 3 2 1", expected: "1 2 3 4 5 6 7", hidden: true, weight: 1 }
    explanation: "Split the line with String.split(\" \"), parse each token with Integer.parseInt, collect into a List<Integer>, sort with Collections.sort (ascending natural order), then join with String.join(\" \", ...) or a loop that avoids a trailing space — a TreeSet is unsuitable here since duplicate priorities like \"2 2 1\" must be preserved in the output."
  - id_key: collections-reflection
    type: subjective
    difficulty: beginner
    points: 2
    prompt: >-
      In your own words: which single concept from this module (List/ArrayList vs.
      LinkedList, Set implementations, Map and computeIfAbsent, or Queue/Deque/Iterator/
      Comparator) felt least intuitive to you, and why? Be specific about what confused
      you — this answer feeds directly into what gets flagged for extra review.
    multiple: false
    options: []
    explanation: "Graded for genuine, specific reflection rather than a single correct answer — the goal is to surface which topic you're actually shakiest on, not to test recall."
---
