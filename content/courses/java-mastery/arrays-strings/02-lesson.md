---
kind: lesson
id_key: java-mastery/arrays-strings/two-dimensional-arrays
course: java-mastery
section: arrays-strings
section_title: "Arrays & Strings"
section_position: 5
title: "2D Arrays: Grids of Data"
position: 1
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
A 1D array is a single row of values. Plenty of real data is naturally a **grid** — TaskFlow, for instance, needs to track which team member is assigned to which day of the week. A 2D array is Java's way to model that: an array of arrays.

## Declaring a 2D array

```java
public class Main {
    public static void main(String[] args) {
        // 3 team members (rows) x 5 workdays (columns): hours assigned each day
        int[][] schedule = new int[3][5];

        schedule[0][0] = 4; // member 0, Monday
        schedule[0][1] = 6; // member 0, Tuesday
        schedule[1][2] = 8; // member 1, Wednesday

        System.out.println("Member 0, Monday: " + schedule[0][0] + "h");
        System.out.println("Member 1, Wednesday: " + schedule[1][2] + "h");
        System.out.println("Member 2, Monday (default): " + schedule[2][0] + "h");
    }
}
```

`new int[3][5]` allocates a grid of 3 rows and 5 columns, all defaulted to `0`. `schedule[row][col]` accesses a single cell — the first index picks the row, the second picks the column within that row. Under the hood, a Java 2D array is literally an array of arrays: `schedule` is an `int[3][]` where each of the 3 elements is itself an `int[5]`.

## Initializing with literal values

```java
public class Main {
    public static void main(String[] args) {
        // Rows: Alice, Bob. Columns: Mon, Tue, Wed, Thu, Fri.
        int[][] hoursAssigned = {
            { 4, 6, 0, 8, 2 }, // Alice
            { 0, 5, 5, 5, 5 }  // Bob
        };

        System.out.println("Alice, Thursday: " + hoursAssigned[0][3] + "h");
        System.out.println("Bob, Monday: " + hoursAssigned[1][0] + "h");
        System.out.println("Rows (team members): " + hoursAssigned.length);
        System.out.println("Columns (days): " + hoursAssigned[0].length);
    }
}
```

Each inner `{ ... }` is one row. `hoursAssigned.length` gives the number of rows; `hoursAssigned[0].length` gives the number of columns in row 0 specifically — Java's 2D arrays are technically "jagged" arrays where each row is an independent array, so different rows are allowed to have different lengths (though in a well-formed grid, they typically match).

## Traversing with nested loops

```java
public class Main {
    public static void main(String[] args) {
        String[] members = { "Alice", "Bob" };
        String[] days = { "Mon", "Tue", "Wed", "Thu", "Fri" };
        int[][] hoursAssigned = {
            { 4, 6, 0, 8, 2 },
            { 0, 5, 5, 5, 5 }
        };

        for (int row = 0; row < hoursAssigned.length; row++) {
            int weeklyTotal = 0;
            for (int col = 0; col < hoursAssigned[row].length; col++) {
                weeklyTotal += hoursAssigned[row][col];
            }
            System.out.println(members[row] + ": " + weeklyTotal + "h this week");
        }

        System.out.println("--- Day-by-day breakdown ---");
        for (int col = 0; col < days.length; col++) {
            System.out.print(days[col] + ": ");
            for (int row = 0; row < hoursAssigned.length; row++) {
                System.out.print(members[row] + "=" + hoursAssigned[row][col] + "h ");
            }
            System.out.println();
        }
    }
}
```

The outer loop walks rows, the inner loop walks columns within that row — the standard pattern for visiting every cell exactly once. Which loop is outer versus inner just changes traversal order (row-by-row vs. column-by-column); the second block above swaps them to print a day-by-day view of the same grid instead of a member-by-member one.

## Enhanced for-loop over a 2D array

```java
public class Main {
    public static void main(String[] args) {
        int[][] hoursAssigned = {
            { 4, 6, 0, 8, 2 },
            { 0, 5, 5, 5, 5 }
        };

        int grandTotal = 0;
        for (int[] row : hoursAssigned) {       // each row is itself an int[]
            for (int hours : row) {             // each hours is a single int
                grandTotal += hours;
            }
        }

        System.out.println("Grand total across the team: " + grandTotal + "h");
    }
}
```

`for (int[] row : hoursAssigned)` reads naturally: for each row (an `int[]`) in the grid. Nesting a second enhanced for-loop inside it visits every individual cell without manually tracking indices — cleaner when you don't need the row/column numbers themselves, as here where only the sum matters.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "arrays-strings-two-dimensional-arrays-q1",
      "type": "mcq",
      "prompt": "For int[][] grid = new int[3][5], what does grid[1][4] refer to?",
      "options": [
        { "id": "a", "text": "Row 1, column 4 — a single int" },
        { "id": "b", "text": "An entire row, as an int[]" },
        { "id": "c", "text": "It's out of bounds and throws immediately" },
        { "id": "d", "text": "Row 4, column 1" }
      ],
      "correct": "a",
      "explanation": "grid[1][4] first selects row index 1 (valid: 0-2), then column index 4 within that row (valid: 0-4), yielding a single int. Both indices are in bounds."
    },
    {
      "id": "arrays-strings-two-dimensional-arrays-q2",
      "type": "mcq",
      "prompt": "In Java, what actually is a 2D array like int[][] grid under the hood?",
      "options": [
        { "id": "a", "text": "A single contiguous block that the compiler treats as flat" },
        { "id": "b", "text": "An array whose elements are themselves arrays (an array of int[])" },
        { "id": "c", "text": "A special built-in Matrix type" },
        { "id": "d", "text": "Identical to a List<List<Integer>>" }
      ],
      "correct": "b",
      "explanation": "Java has no true multidimensional array type — int[][] is an array of int[] references. This is why rows can have different lengths (a jagged array) and why grid.length gives row count while grid[0].length gives that row's column count."
    },
    {
      "id": "arrays-strings-two-dimensional-arrays-q3",
      "type": "mcq",
      "prompt": "In `for (int[] row : hoursAssigned) { for (int hours : row) { ... } }`, what type is `row`?",
      "options": [
        { "id": "a", "text": "int" },
        { "id": "b", "text": "int[] — one row of the grid" },
        { "id": "c", "text": "int[][] — the whole grid" },
        { "id": "d", "text": "This is a compile error" }
      ],
      "correct": "b",
      "explanation": "Since hoursAssigned is int[][] (an array of int[]), each element the outer enhanced for-loop yields is one int[] row. The inner loop then iterates the individual int values within that row."
    }
  ]
}
```

## What's next

Grids of numbers are useful, but TaskFlow deals constantly with text — task names, tags, descriptions. The next lesson digs into **Strings**: immutability, and the methods you'll use on them every day.
