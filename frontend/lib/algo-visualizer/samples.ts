import type { LanguageId } from "./core/types";

export interface Sample {
  name: string;
  tag: string;
  description: string;
  timeComplexity: string;
  spaceComplexity: string;
  code: string;
}

export const SAMPLES: Record<LanguageId, Sample[]> = {
  python: [
    {
      name: "Bubble Sort",
      tag: "Algorithms • Sorting",
      description: "Repeatedly swap adjacent out-of-order elements until the array is sorted.",
      timeComplexity: "O(n²)",
      spaceComplexity: "O(1)",
      code: `def bubble_sort(arr):
    n = len(arr)
    for i in range(n):
        for j in range(0, n - i - 1):
            if arr[j] > arr[j + 1]:
                arr[j], arr[j + 1] = arr[j + 1], arr[j]
    return arr


arr = [5, 2, 9, 1, 5, 6]
print(bubble_sort(arr))
`,
    },
    {
      name: "Binary Search",
      tag: "Algorithms • Searching",
      description: "Find a target in a sorted array by repeatedly halving the search range.",
      timeComplexity: "O(log n)",
      spaceComplexity: "O(1)",
      code: `def binary_search(arr, target):
    low = 0
    high = len(arr) - 1
    while low <= high:
        mid = (low + high) // 2
        if arr[mid] == target:
            return mid
        elif arr[mid] < target:
            low = mid + 1
        else:
            high = mid - 1
    return -1


arr = [1, 3, 5, 7, 9, 11, 13]
result = binary_search(arr, 9)
print(f"Found at index {result}")
`,
    },
    {
      name: "Recursive Factorial",
      tag: "Algorithms • Recursion",
      description: "Compute n! by multiplying n by factorial(n - 1) down to the base case.",
      timeComplexity: "O(n)",
      spaceComplexity: "O(n)",
      code: `def factorial(n):
    if n <= 1:
        return 1
    return n * factorial(n - 1)


print(factorial(5))
`,
    },
    {
      name: "Reverse String (Stack)",
      tag: "Algorithms • Stack",
      description: "Push every character onto a stack, then pop them back off — last in, first out reverses the string.",
      timeComplexity: "O(n)",
      spaceComplexity: "O(n)",
      code: `def reverse_string(s):
    stack = []
    for ch in s:
        stack.append(ch)
    out = ""
    while stack:
        out += stack.pop()
    return out


print(reverse_string("REVERSE"))
`,
    },
    {
      name: "Process Queue",
      tag: "Algorithms • Queue",
      description: "Enqueue every item, then dequeue from the front — first in, first out preserves arrival order.",
      timeComplexity: "O(n)",
      spaceComplexity: "O(n)",
      code: `def process_queue(items):
    queue = []
    for item in items:
        queue.append(item)
    order = []
    while queue:
        order.append(queue.pop(0))
    return order


print(process_queue([1, 2, 3, 4, 5]))
`,
    },
  ],
  javascript: [
    {
      name: "Bubble Sort",
      tag: "Algorithms • Sorting",
      description: "Repeatedly swap adjacent out-of-order elements until the array is sorted.",
      timeComplexity: "O(n²)",
      spaceComplexity: "O(1)",
      code: `function bubbleSort(arr) {
  let n = arr.length;
  for (let i = 0; i < n; i++) {
    for (let j = 0; j < n - i - 1; j++) {
      if (arr[j] > arr[j + 1]) {
        [arr[j], arr[j + 1]] = [arr[j + 1], arr[j]];
      }
    }
  }
  return arr;
}

let arr = [5, 2, 9, 1, 5, 6];
console.log(bubbleSort(arr));
`,
    },
    {
      name: "Binary Search",
      tag: "Algorithms • Searching",
      description: "Find a target in a sorted array by repeatedly halving the search range.",
      timeComplexity: "O(log n)",
      spaceComplexity: "O(1)",
      code: `function binarySearch(arr, target) {
  let low = 0;
  let high = arr.length - 1;
  while (low <= high) {
    let mid = Math.floor((low + high) / 2);
    if (arr[mid] === target) {
      return mid;
    } else if (arr[mid] < target) {
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  return -1;
}

let arr = [1, 3, 5, 7, 9, 11, 13];
let result = binarySearch(arr, 9);
console.log(\`Found at index \${result}\`);
`,
    },
    {
      name: "Recursive Factorial",
      tag: "Algorithms • Recursion",
      description: "Compute n! by multiplying n by factorial(n - 1) down to the base case.",
      timeComplexity: "O(n)",
      spaceComplexity: "O(n)",
      code: `function factorial(n) {
  if (n <= 1) {
    return 1;
  }
  return n * factorial(n - 1);
}

console.log(factorial(5));
`,
    },
    {
      name: "Reverse String (Stack)",
      tag: "Algorithms • Stack",
      description: "Push every character onto a stack, then pop them back off — last in, first out reverses the string.",
      timeComplexity: "O(n)",
      spaceComplexity: "O(n)",
      code: `function reverseString(s) {
  let stack = [];
  for (let ch of s) {
    stack.push(ch);
  }
  let out = "";
  while (stack.length) {
    out += stack.pop();
  }
  return out;
}

console.log(reverseString("REVERSE"));
`,
    },
    {
      name: "Process Queue",
      tag: "Algorithms • Queue",
      description: "Enqueue every item, then dequeue from the front — first in, first out preserves arrival order.",
      timeComplexity: "O(n)",
      spaceComplexity: "O(n)",
      code: `function processQueue(items) {
  let queue = [];
  for (let item of items) {
    queue.push(item);
  }
  let order = [];
  while (queue.length) {
    order.push(queue.shift());
  }
  return order;
}

console.log(processQueue([1, 2, 3, 4, 5]));
`,
    },
  ],
};
