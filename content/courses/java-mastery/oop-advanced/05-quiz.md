---
kind: quiz
id_key: java-mastery/oop-advanced/quiz
course: java-mastery
section: oop-advanced
section_title: "Advanced OOP"
section_position: 4
title: "Module Assessment: Advanced OOP"
position: 4
estimated_minutes: 25
source: [java-mastery-curriculum.md]
pass_percentage: 70
duration_minutes: 25
questions:
  - id_key: super-first-statement
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "UrgentTask extends Task. Where must the call to super(...) appear inside UrgentTask's constructor?"
    multiple: false
    options:
      - { text: "As the first statement in the constructor", correct: true }
      - { text: "As the last statement in the constructor", correct: false }
      - { text: "Anywhere, order doesn't matter", correct: false }
      - { text: "It's never required, even when Task has no no-argument constructor", correct: false }
    explanation: "The superclass portion of an object must be fully initialized before the subclass adds anything on top, so super(...) is required to be the first statement in a subclass constructor."
  - id_key: overriding-vs-overloading-resolution
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "What's the key difference in how overriding and overloading are resolved?"
    multiple: false
    options:
      - { text: "Both are resolved identically, at compile time", correct: false }
      - { text: "Overloading is resolved at compile time by argument types; overriding is resolved at runtime by the object's actual type", correct: true }
      - { text: "Overriding is resolved at compile time; overloading is resolved at runtime", correct: false }
      - { text: "Neither is ever resolved until the JVM shuts down", correct: false }
    explanation: "Overload resolution picks a method signature at compile time based on argument types. Overridden methods are dispatched at runtime based on the real type of the object a reference points to — this is what makes polymorphism work."
  - id_key: abstract-vs-interface-multiple
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Why can a class implement multiple interfaces but extend only one abstract (or any) class?"
    multiple: false
    options:
      - { text: "Interfaces and abstract classes are functionally identical, this is arbitrary", correct: false }
      - { text: "Java supports multiple implementation of interfaces but only single inheritance of classes, by design", correct: true }
      - { text: "A class can actually extend multiple classes too, this is a common misconception", correct: false }
      - { text: "Interfaces can only be implemented one at a time as well", correct: false }
    explanation: "Java deliberately allows a class to implement any number of interfaces (composing multiple capabilities) while restricting it to a single superclass (avoiding the ambiguity of multiple concrete implementation inheritance)."
  - id_key: equals-without-hashcode
    type: mcq
    difficulty: advanced
    points: 2
    prompt: "A Task class overrides equals() to compare by id but leaves hashCode() as Object's default. Two logically-equal Task objects are added to a HashSet. What happens?"
    multiple: false
    options:
      - { text: "The HashSet correctly recognizes them as duplicates and stores only one", correct: false }
      - { text: "Both get added — different default hashCodes route them to different buckets, so equals() is never even called to compare them", correct: true }
      - { text: "The program throws an exception at runtime", correct: false }
      - { text: "It fails to compile, since equals() requires a matching hashCode() override", correct: false }
    explanation: "HashSet buckets by hashCode() first. Without a matching override, two equals()-equal objects can still get different hash codes, land in different buckets, and never be compared — silently breaking de-duplication."
  - id_key: enum-equality
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "Why is it both safe and idiomatic to compare two TaskStatus enum values with ==, unlike comparing two String values?"
    multiple: false
    options:
      - { text: "== on enums secretly calls .equals() internally, so they're identical", correct: false }
      - { text: "Each enum constant is a single shared instance for the whole program, so identity comparison correctly reflects value equality", correct: true }
      - { text: "It isn't actually safe; == should always be avoided for enums too", correct: false }
      - { text: "Enums are primitives under the hood, like int", correct: false }
    explanation: "There is exactly one object per enum constant (e.g., one single TaskStatus.DONE), so reference equality (==) and logical equality coincide — unlike String, where two equal-content objects can be different instances."
  - id_key: effective-priority-coding
    type: coding
    difficulty: intermediate
    points: 3
    prompt: >-
      TaskFlow scores task priority. Read two integers from a single line of input,
      space-separated: estimated hours, and an urgent flag (1 for urgent, 0 for not).
      Print a single integer: the effective priority score, computed as hours, plus
      10 more if the task is urgent. Print only that number, with no extra text.
    languages: [java]
    starter_code:
      java: |
        import java.util.Scanner;

        public class Main {
            public static void main(String[] args) {
                Scanner scanner = new Scanner(System.in);
                int hours = scanner.nextInt();
                int urgentFlag = scanner.nextInt();
                // TODO: print hours, plus 10 more if urgentFlag == 1

            }
        }
    test_cases:
      - { stdin: "5 1", expected: "15", hidden: false, weight: 1 }
      - { stdin: "5 0", expected: "5", hidden: false, weight: 1 }
      - { stdin: "3 1", expected: "13", hidden: true, weight: 1 }
      - { stdin: "8 0", expected: "8", hidden: true, weight: 1 }
      - { stdin: "0 1", expected: "10", hidden: true, weight: 1 }
    explanation: "Reading both integers with scanner.nextInt(), then printing hours + (urgentFlag == 1 ? 10 : 0) with println, mirrors the lesson's UrgentTask carrying extra weight over a plain Task — same underlying data, different effective score."
  - id_key: oop-advanced-reflection
    type: subjective
    difficulty: beginner
    points: 2
    prompt: >-
      In your own words: which single concept from this module (inheritance and
      super, overriding vs. overloading and polymorphism, abstract classes vs.
      interfaces, or the equals/hashCode/enum contract) felt least intuitive to
      you, and why? Be specific about what confused you — this answer feeds
      directly into what gets flagged for extra review.
    multiple: false
    options: []
    explanation: "Graded for genuine, specific reflection rather than a single correct answer — the goal is to surface which topic you're actually shakiest on, not to test recall."
---
