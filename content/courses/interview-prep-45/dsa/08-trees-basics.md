---
kind: lesson
id_key: interview-prep-45/day-06
course: interview-prep-45
section: dsa
section_title: "Data Structures & Algorithms"
section_position: 2
title: "Trees: Traversals and Core Patterns"
position: 8
estimated_minutes: 120
source:
    - 45-day-interview-roadmap.md
---
Picture a company org chart: a CEO at the top, managers below, workers below them. That shape, one node with children, children with their own children, is a tree. Most tree problems have a simple trick: the answer for a node is built from the answers of its children. Write a function that trusts its own recursive calls, and the tree problem nearly solves itself.

## Visiting every node in a tree

Take this small tree of numbers:

```
        5
       / \
      3   8
     / \   \
    1   4   9
```

There are four common ways to walk through it, and they differ only in *when* you record a node compared to its children.

- **Preorder** (node, left, right): record the node first, then its subtrees. `5, 3, 1, 4, 8, 9`. Good for copying or serializing a tree, since you write the parent before you write its children.
- **Inorder** (left, node, right): record the node between its subtrees. `1, 3, 4, 5, 8, 9`. For a search tree (covered in the next lesson), this always comes out sorted.
- **Postorder** (left, right, node): record the node last. `1, 4, 3, 9, 8, 5`. Use this whenever children must be fully handled before the parent, such as deleting a tree from the bottom up, or totaling up a subtree's values.
- **Level order**: visit row by row, left to right: `[5], [3, 8], [1, 4, 9]`. This one isn't recursive at all; it uses a queue, the same tool BFS uses on graphs later in this course.

```python
class TreeNode:
    def __init__(self, val=0, left=None, right=None):
        self.val = val
        self.left = left
        self.right = right

def preorder(root):
    if root is None:
        return []
    return [root.val] + preorder(root.left) + preorder(root.right)

def inorder(root):
    if root is None:
        return []
    return inorder(root.left) + [root.val] + inorder(root.right)

def postorder(root):
    if root is None:
        return []
    return postorder(root.left) + postorder(root.right) + [root.val]

from collections import deque

def level_order(root):
    if root is None:
        return []
    result = []
    queue = deque([root])
    while queue:
        level = []
        for _ in range(len(queue)):
            node = queue.popleft()
            level.append(node.val)
            if node.left:
                queue.append(node.left)
            if node.right:
                queue.append(node.right)
        result.append(level)
    return result
```
```javascript +
class TreeNode {
    constructor(val = 0, left = null, right = null) {
        this.val = val;
        this.left = left;
        this.right = right;
    }
}

function preorder(root) {
    if (root === null) {
        return [];
    }
    return [root.val, ...preorder(root.left), ...preorder(root.right)];
}

function inorder(root) {
    if (root === null) {
        return [];
    }
    return [...inorder(root.left), root.val, ...inorder(root.right)];
}

function postorder(root) {
    if (root === null) {
        return [];
    }
    return [...postorder(root.left), ...postorder(root.right), root.val];
}

function levelOrder(root) {
    if (root === null) {
        return [];
    }
    const result = [];
    const queue = [root];
    while (queue.length > 0) {
        const level = [];
        const levelSize = queue.length;
        for (let i = 0; i < levelSize; i++) {
            const node = queue.shift();
            level.push(node.val);
            if (node.left) {
                queue.push(node.left);
            }
            if (node.right) {
                queue.push(node.right);
            }
        }
        result.push(level);
    }
    return result;
}
```
```java +
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        TreeNode root = new TreeNode(1, new TreeNode(2), new TreeNode(3));
        System.out.println("Preorder: " + preorder(root));
        System.out.println("Inorder: " + inorder(root));
        System.out.println("Postorder: " + postorder(root));
        System.out.println("Level order: " + levelOrder(root));
    }

    static List<Integer> preorder(TreeNode root) {
        List<Integer> result = new ArrayList<>();
        if (root == null) {
            return result;
        }
        result.add(root.val);
        result.addAll(preorder(root.left));
        result.addAll(preorder(root.right));
        return result;
    }

    static List<Integer> inorder(TreeNode root) {
        List<Integer> result = new ArrayList<>();
        if (root == null) {
            return result;
        }
        result.addAll(inorder(root.left));
        result.add(root.val);
        result.addAll(inorder(root.right));
        return result;
    }

    static List<Integer> postorder(TreeNode root) {
        List<Integer> result = new ArrayList<>();
        if (root == null) {
            return result;
        }
        result.addAll(postorder(root.left));
        result.addAll(postorder(root.right));
        result.add(root.val);
        return result;
    }

    static List<List<Integer>> levelOrder(TreeNode root) {
        List<List<Integer>> result = new ArrayList<>();
        if (root == null) {
            return result;
        }
        Deque<TreeNode> queue = new ArrayDeque<>();
        queue.add(root);
        while (!queue.isEmpty()) {
            List<Integer> level = new ArrayList<>();
            int levelSize = queue.size();
            for (int i = 0; i < levelSize; i++) {
                TreeNode node = queue.poll();
                level.add(node.val);
                if (node.left != null) {
                    queue.add(node.left);
                }
                if (node.right != null) {
                    queue.add(node.right);
                }
            }
            result.add(level);
        }
        return result;
    }
}

class TreeNode {
    int val;
    TreeNode left;
    TreeNode right;

    TreeNode(int val) {
        this(val, null, null);
    }

    TreeNode(int val, TreeNode left, TreeNode right) {
        this.val = val;
        this.left = left;
        this.right = right;
    }
}
```

The versions above build small lists and glue them together with `+`. That reads well, but real code usually passes one shared list down through the recursion instead, so it doesn't keep building and throwing away little lists. Know both; be ready to write the faster one if asked.

> **Remember:** preorder writes the parent first, postorder writes it last, inorder puts it in the middle. Level order is the odd one out: no recursion, just a queue.

```knowledge-check
{ "questions": [
    { "id": "dsa-trees-basics-traversal-order-q1", "type": "mcq",
      "prompt": "For the tree 5 (left 3, right 8), where 3 has children 1 and 4, what does an inorder traversal produce?",
      "options": [
        {"id": "a", "text": "1, 3, 4, 5, 8"},
        {"id": "b", "text": "5, 3, 1, 4, 8"},
        {"id": "c", "text": "1, 4, 3, 8, 5"},
        {"id": "d", "text": "5, 8, 3, 4, 1"}
      ],
      "correct": "a",
      "explanation": "Inorder visits left subtree, then the node, then right subtree. That order for this tree is 1, 3, 4 (left side), then 5, then 8." }
] }
```

## Doing it without recursion

Every recursive traversal above has an iterative version that uses an explicit stack instead of the call stack. Interviewers ask for this to check that you understand what the recursion was actually doing, not that you memorized three lines.

Preorder is the easiest to convert: push right before left, so left comes off the stack first.

```python
def preorder_iterative(root):
    if root is None:
        return []
    result = []
    stack = [root]
    while stack:
        node = stack.pop()
        result.append(node.val)
        if node.right:
            stack.append(node.right)
        if node.left:
            stack.append(node.left)
    return result
```
```javascript +
function preorderIterative(root) {
    if (root === null) {
        return [];
    }
    const result = [];
    const stack = [root];
    while (stack.length > 0) {
        const node = stack.pop();
        result.push(node.val);
        if (node.right) {
            stack.push(node.right);
        }
        if (node.left) {
            stack.push(node.left);
        }
    }
    return result;
}
```
```java +
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        TreeNode root = new TreeNode(1, new TreeNode(2), new TreeNode(3));
        System.out.println(preorderIterative(root));
    }

    static List<Integer> preorderIterative(TreeNode root) {
        List<Integer> result = new ArrayList<>();
        if (root == null) {
            return result;
        }
        Deque<TreeNode> stack = new ArrayDeque<>();
        stack.push(root);
        while (!stack.isEmpty()) {
            TreeNode node = stack.pop();
            result.add(node.val);
            if (node.right != null) {
                stack.push(node.right);
            }
            if (node.left != null) {
                stack.push(node.left);
            }
        }
        return result;
    }
}

class TreeNode {
    int val;
    TreeNode left;
    TreeNode right;

    TreeNode(int val) {
        this(val, null, null);
    }

    TreeNode(int val, TreeNode left, TreeNode right) {
        this.val = val;
        this.left = left;
        this.right = right;
    }
}
```

Inorder is trickier, since you can't just push both children at once. You have to walk all the way left first, process the node you land on, then step right:

```python
def inorder_iterative(root):
    result = []
    stack = []
    node = root
    while stack or node:
        while node:          # go as far left as possible
            stack.append(node)
            node = node.left
        node = stack.pop()   # process the node
        result.append(node.val)
        node = node.right    # then explore the right subtree
    return result
```
```javascript +
function inorderIterative(root) {
    const result = [];
    const stack = [];
    let node = root;
    while (stack.length > 0 || node !== null) {
        while (node !== null) {           // go as far left as possible
            stack.push(node);
            node = node.left;
        }
        node = stack.pop();               // process the node
        result.push(node.val);
        node = node.right;                // then explore the right subtree
    }
    return result;
}
```
```java +
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        TreeNode root = new TreeNode(2, new TreeNode(1), new TreeNode(3));
        System.out.println(inorderIterative(root));
    }

    static List<Integer> inorderIterative(TreeNode root) {
        List<Integer> result = new ArrayList<>();
        Deque<TreeNode> stack = new ArrayDeque<>();
        TreeNode node = root;
        while (!stack.isEmpty() || node != null) {
            while (node != null) {            // go as far left as possible
                stack.push(node);
                node = node.left;
            }
            node = stack.pop();               // process the node
            result.add(node.val);
            node = node.right;                // then explore the right subtree
        }
        return result;
    }
}

class TreeNode {
    int val;
    TreeNode left;
    TreeNode right;

    TreeNode(int val) {
        this(val, null, null);
    }

    TreeNode(int val, TreeNode left, TreeNode right) {
        this.val = val;
        this.left = left;
        this.right = right;
    }
}
```

Postorder iteratively is the fiddly one. Do a "node, right, left" walk (swap the push order from preorder above), then reverse the result. That flips it into "left, right, node" for free.

```python
def postorder_iterative(root):
    if root is None:
        return []
    result = []
    stack = [root]
    while stack:
        node = stack.pop()
        result.append(node.val)
        if node.left:
            stack.append(node.left)
        if node.right:
            stack.append(node.right)
    return result[::-1]
```
```javascript +
function postorderIterative(root) {
    if (root === null) {
        return [];
    }
    const result = [];
    const stack = [root];
    while (stack.length > 0) {
        const node = stack.pop();
        result.push(node.val);
        if (node.left) {
            stack.push(node.left);
        }
        if (node.right) {
            stack.push(node.right);
        }
    }
    return result.reverse();
}
```
```java +
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Deque;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        TreeNode root = new TreeNode(1, new TreeNode(2), new TreeNode(3));
        System.out.println(postorderIterative(root));
    }

    static List<Integer> postorderIterative(TreeNode root) {
        List<Integer> result = new ArrayList<>();
        if (root == null) {
            return result;
        }
        Deque<TreeNode> stack = new ArrayDeque<>();
        stack.push(root);
        while (!stack.isEmpty()) {
            TreeNode node = stack.pop();
            result.add(node.val);
            if (node.left != null) {
                stack.push(node.left);
            }
            if (node.right != null) {
                stack.push(node.right);
            }
        }
        Collections.reverse(result);
        return result;
    }
}

class TreeNode {
    int val;
    TreeNode left;
    TreeNode right;

    TreeNode(int val) {
        this(val, null, null);
    }

    TreeNode(int val, TreeNode left, TreeNode right) {
        this.val = val;
        this.left = left;
        this.right = right;
    }
}
```

> **Remember:** preorder-iterative pushes right then left. Postorder-iterative is preorder's "node, right, left" twin, reversed at the end. Inorder needs a "walk left, then pop" loop.

```knowledge-check
{ "questions": [
    { "id": "dsa-trees-basics-iterative-q1", "type": "mcq",
      "prompt": "Why do interviewers sometimes ask for the iterative version of a tree traversal instead of the recursive one?",
      "options": [
        {"id": "a", "text": "To check you understand what the recursion is doing, not just that you memorized it"},
        {"id": "b", "text": "Because recursive traversals are always incorrect"},
        {"id": "c", "text": "Because iterative versions run in less time"},
        {"id": "d", "text": "Because trees can't be traversed recursively in most languages"}
      ],
      "correct": "a",
      "explanation": "Recursive and iterative traversals have the same time complexity. The iterative version forces you to make the call stack's behavior explicit with your own stack, which shows real understanding." }
] }
```

## Two facts about a tree's shape

Two properties come up again and again, so get them cold.

**Height**: how many edges are on the longest path from a node down to a leaf. A single node has height 0. Height is naturally computed bottom-up, a postorder-shaped recursion: a node's height is 1 more than the taller of its two children's heights.

**Balance**: a tree is height-balanced if, at every node, the heights of its left and right subtrees differ by at most 1. Checking this the naive way, calling a height function at every node, costs O(n²) in the worst case on a long, skewed tree, since you recompute overlapping heights over and over. The fast version computes height and checks balance in the same single postorder pass, O(n) total.

> **Remember:** compute height bottom-up. Check balance in the same pass as computing height, don't call a separate height function per node.

```knowledge-check
{ "questions": [
    { "id": "dsa-trees-basics-height-balance-q1", "type": "mcq",
      "prompt": "Why is checking tree balance by calling a separate height function at every node slow?",
      "options": [
        {"id": "a", "text": "It recomputes overlapping subtree heights many times, giving O(n²) on a skewed tree"},
        {"id": "b", "text": "Height cannot be computed recursively"},
        {"id": "c", "text": "It only works on balanced trees"},
        {"id": "d", "text": "It requires level-order traversal, which needs extra memory"}
      ],
      "correct": "a",
      "explanation": "Calling height() at every node re-walks the subtrees below it again and again. Folding the balance check into one postorder pass that returns height avoids the repeated work, giving O(n)." }
] }
```

## Invert Binary Tree

[Invert Binary Tree (LeetCode 226)](https://leetcode.com/problems/invert-binary-tree/)

Flip a photo of the tree left to right: every left child becomes a right child and vice versa, all the way down. That is the whole problem. It is a postorder-shaped recursion: invert both subtrees, then swap them onto the node.

**Approach:** Base case: `None` inverts to `None`. Recursive case: swap `root.left` and `root.right`, after first inverting each of them.

```python
def invert_tree(root):
    if root is None:
        return None
    root.left, root.right = invert_tree(root.right), invert_tree(root.left)
    return root
```
```javascript +
function invertTree(root) {
    if (root === null) {
        return null;
    }
    [root.left, root.right] = [invertTree(root.right), invertTree(root.left)];
    return root;
}
```
```java +
public class Main {
    public static void main(String[] args) {
        TreeNode root = new TreeNode(1, new TreeNode(2), new TreeNode(3));
        TreeNode inverted = invertTree(root);
        System.out.println("New left: " + inverted.left.val + ", new right: " + inverted.right.val);
    }

    static TreeNode invertTree(TreeNode root) {
        if (root == null) {
            return null;
        }
        TreeNode newLeft = invertTree(root.right);
        TreeNode newRight = invertTree(root.left);
        root.left = newLeft;
        root.right = newRight;
        return root;
    }
}

class TreeNode {
    int val;
    TreeNode left;
    TreeNode right;

    TreeNode(int val) {
        this(val, null, null);
    }

    TreeNode(int val, TreeNode left, TreeNode right) {
        this.val = val;
        this.left = left;
        this.right = right;
    }
}
```

**Complexity:** Time O(n), visits every node once. Space O(h) for the recursion stack, where h is the tree's height (O(log n) if balanced, O(n) if it's a long chain).

**Common mistakes:**
- Swapping `root.left`/`root.right` before recursing on the original children. That inverts the wrong subtree. The simultaneous-assignment version above sidesteps this by finishing both recursive calls before either assignment happens.
- Forgetting the `None` base case, which causes infinite recursion.

> **Remember:** invert the children first, then swap them onto the parent, not the other way around.

```knowledge-check
{ "questions": [
    { "id": "dsa-trees-basics-invert-q1", "type": "mcq",
      "prompt": "What bug happens if you swap root.left and root.right before recursing into the original children?",
      "options": [
        {"id": "a", "text": "You end up inverting the wrong subtree, since the children were swapped before you descended into them"},
        {"id": "b", "text": "Nothing, order doesn't matter here"},
        {"id": "c", "text": "The tree becomes unbalanced"},
        {"id": "d", "text": "It only fails on trees with more than 100 nodes"}
      ],
      "correct": "a",
      "explanation": "If you swap first, the recursive calls that follow now walk into the swapped subtrees, not the original ones, corrupting the result. Evaluate both recursive calls first, then assign." }
] }
```

## Maximum Depth of Binary Tree

[Maximum Depth of Binary Tree (LeetCode 104)](https://leetcode.com/problems/maximum-depth-of-binary-tree/)

The depth of a tree is 1 (for the current node) plus whichever of its two subtrees goes deeper. That's the entire recursion, a textbook postorder shape.

**Approach:** Base case: an empty tree has depth 0. Recursive case: `1 + max(depth(left), depth(right))`.

```python
def max_depth(root) -> int:
    if root is None:
        return 0
    return 1 + max(max_depth(root.left), max_depth(root.right))
```
```javascript +
function maxDepth(root) {
    if (root === null) {
        return 0;
    }
    return 1 + Math.max(maxDepth(root.left), maxDepth(root.right));
}
```
```java +
public class Main {
    public static void main(String[] args) {
        TreeNode root = new TreeNode(1, new TreeNode(2, new TreeNode(4), null), new TreeNode(3));
        System.out.println(maxDepth(root));
    }

    static int maxDepth(TreeNode root) {
        if (root == null) {
            return 0;
        }
        return 1 + Math.max(maxDepth(root.left), maxDepth(root.right));
    }
}

class TreeNode {
    int val;
    TreeNode left;
    TreeNode right;

    TreeNode(int val) {
        this(val, null, null);
    }

    TreeNode(int val, TreeNode left, TreeNode right) {
        this.val = val;
        this.left = left;
        this.right = right;
    }
}
```

**Complexity:** Time O(n), space O(h) for the recursion stack.

**Common mistakes:**
- Off-by-one: forgetting the `+ 1` for the current node, or adding it twice.
- Writing an iterative BFS version without correctly counting levels; you need to count levels, not nodes.

> **Remember:** depth is 1 plus the deeper child's depth. An empty tree has depth 0.

```knowledge-check
{ "questions": [
    { "id": "dsa-trees-basics-max-depth-q1", "type": "mcq",
      "prompt": "What is the space complexity of the recursive max-depth solution, in terms of tree height h?",
      "options": [
        {"id": "a", "text": "O(h), for the recursion call stack"},
        {"id": "b", "text": "O(1), constant space"},
        {"id": "c", "text": "O(n), always, regardless of shape"},
        {"id": "d", "text": "O(log n), always"}
      ],
      "correct": "a",
      "explanation": "Every recursive call adds a frame to the call stack until it hits a leaf. The deepest that stack ever gets is the tree's height h, so space is O(h): O(log n) if balanced, O(n) on a skewed chain." }
] }
```

## Same Tree

[Same Tree (LeetCode 100)](https://leetcode.com/problems/same-tree/)

Two trees match if their roots hold the same value and both pairs of subtrees also match. That's a direct structural recursion comparing two trees side by side, step by step.

**Approach:** Base cases: both `None` means equal; exactly one `None` means not equal. Recursive case: values match AND left subtrees match AND right subtrees match.

```python
def is_same_tree(p, q) -> bool:
    if p is None and q is None:
        return True
    if p is None or q is None:
        return False
    return (
        p.val == q.val
        and is_same_tree(p.left, q.left)
        and is_same_tree(p.right, q.right)
    )
```
```javascript +
function isSameTree(p, q) {
    if (p === null && q === null) {
        return true;
    }
    if (p === null || q === null) {
        return false;
    }
    return (
        p.val === q.val &&
        isSameTree(p.left, q.left) &&
        isSameTree(p.right, q.right)
    );
}
```
```java +
public class Main {
    public static void main(String[] args) {
        TreeNode p = new TreeNode(1, new TreeNode(2), new TreeNode(3));
        TreeNode q = new TreeNode(1, new TreeNode(2), new TreeNode(3));
        System.out.println(isSameTree(p, q));
    }

    static boolean isSameTree(TreeNode p, TreeNode q) {
        if (p == null && q == null) {
            return true;
        }
        if (p == null || q == null) {
            return false;
        }
        return p.val == q.val
                && isSameTree(p.left, q.left)
                && isSameTree(p.right, q.right);
    }
}

class TreeNode {
    int val;
    TreeNode left;
    TreeNode right;

    TreeNode(int val) {
        this(val, null, null);
    }

    TreeNode(int val, TreeNode left, TreeNode right) {
        this.val = val;
        this.left = left;
        this.right = right;
    }
}
```

**Complexity:** Time O(min(n, m)), stops the instant the trees diverge. Space O(min(h_p, h_q)) recursion stack.

**Common mistakes:**
- Reading `p.val` before checking whether `p` is `None`. That crashes with an attribute error on `None`.

> **Remember:** check both-None and either-None first. Only then compare values and recurse into both children.

```knowledge-check
{ "questions": [
    { "id": "dsa-trees-basics-same-tree-q1", "type": "mcq",
      "prompt": "In Same Tree, why must you check for None before reading p.val or q.val?",
      "options": [
        {"id": "a", "text": "Reading a value on a None node crashes the program"},
        {"id": "b", "text": "None nodes always have value 0, which would give a wrong answer"},
        {"id": "c", "text": "It's only a style preference, not a correctness issue"},
        {"id": "d", "text": "Trees can never legally contain a None node"}
      ],
      "correct": "a",
      "explanation": "A None (or null) node has no .val attribute. Comparing values before ruling out None causes a crash, so the None checks must come first." }
] }
```

## Binary Tree Level Order Traversal

[Binary Tree Level Order Traversal (LeetCode 102)](https://leetcode.com/problems/binary-tree-level-order-traversal/)

"Group nodes by their depth" is exactly what BFS gives you for free, as long as you process the queue one full level at a time instead of one node at a time.

**Approach:** Use a queue. At each step, note the current queue length; that number is exactly how many nodes belong to the current level. Pop that many, collect their values, and enqueue their children for the next round.

```python
from collections import deque

def level_order_traversal(root):
    if root is None:
        return []
    result = []
    queue = deque([root])
    while queue:
        level_size = len(queue)
        level_values = []
        for _ in range(level_size):
            node = queue.popleft()
            level_values.append(node.val)
            if node.left:
                queue.append(node.left)
            if node.right:
                queue.append(node.right)
        result.append(level_values)
    return result
```
```javascript +
function levelOrderTraversal(root) {
    if (root === null) {
        return [];
    }
    const result = [];
    const queue = [root];
    while (queue.length > 0) {
        const levelSize = queue.length;
        const levelValues = [];
        for (let i = 0; i < levelSize; i++) {
            const node = queue.shift();
            levelValues.push(node.val);
            if (node.left) {
                queue.push(node.left);
            }
            if (node.right) {
                queue.push(node.right);
            }
        }
        result.push(levelValues);
    }
    return result;
}
```
```java +
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        TreeNode root = new TreeNode(3, new TreeNode(9), new TreeNode(20, new TreeNode(15), new TreeNode(7)));
        System.out.println(levelOrderTraversal(root));
    }

    static List<List<Integer>> levelOrderTraversal(TreeNode root) {
        List<List<Integer>> result = new ArrayList<>();
        if (root == null) {
            return result;
        }
        Deque<TreeNode> queue = new ArrayDeque<>();
        queue.add(root);
        while (!queue.isEmpty()) {
            int levelSize = queue.size();
            List<Integer> levelValues = new ArrayList<>();
            for (int i = 0; i < levelSize; i++) {
                TreeNode node = queue.poll();
                levelValues.add(node.val);
                if (node.left != null) {
                    queue.add(node.left);
                }
                if (node.right != null) {
                    queue.add(node.right);
                }
            }
            result.add(levelValues);
        }
        return result;
    }
}

class TreeNode {
    int val;
    TreeNode left;
    TreeNode right;

    TreeNode(int val) {
        this(val, null, null);
    }

    TreeNode(int val, TreeNode left, TreeNode right) {
        this.val = val;
        this.left = left;
        this.right = right;
    }
}
```

**Complexity:** Time O(n), every node is enqueued and dequeued exactly once. Space O(w) for the queue, where w is the widest level, plus O(n) for the output.

**Common mistakes:**
- Not snapshotting the queue's length before the inner loop. Checking the live length inside the loop lets it grow as you enqueue children, which merges levels together.
- Using `list.pop(0)` (O(n) per call) instead of `deque.popleft()` (O(1)), or using a stack where a queue is needed.

> **Remember:** snapshot the queue length before draining it. That number is exactly one level's worth of nodes.

```knowledge-check
{ "questions": [
    { "id": "dsa-trees-basics-level-order-q1", "type": "mcq",
      "prompt": "In the level-order BFS pattern, what does snapshotting len(queue) before the inner loop accomplish?",
      "options": [
        {"id": "a", "text": "It fixes exactly how many nodes belong to the current level, before their children start getting enqueued"},
        {"id": "b", "text": "It reduces the time complexity from O(n) to O(log n)"},
        {"id": "c", "text": "It prevents the queue from ever being empty"},
        {"id": "d", "text": "It is only a style choice with no effect on correctness"}
      ],
      "correct": "a",
      "explanation": "If you check the queue's length again mid-loop, newly enqueued children of the current level get counted into it, silently merging two levels into one. Snapshotting the count first keeps levels separate." }
] }
```

## Naming the shape before you code

Every problem in this lesson reduces to one of three shapes: does a node's answer depend only on its children's answers (postorder: Invert, Max Depth)? Does it depend on walking two trees in lockstep (Same Tree)? Or does it need to go level by level (Level Order)? Spend ten seconds naming which shape a new tree problem fits before writing any code. Guessing at the recursion instead of naming the shape first is where most tree bugs start.

> **Remember:** name the shape (postorder, lockstep comparison, or level-by-level) before you write a single line.

```knowledge-check
{ "questions": [
    { "id": "dsa-trees-basics-naming-shape-q1", "type": "mcq",
      "prompt": "What are the three recurring 'shapes' tree problems in this lesson fall into?",
      "options": [
        {"id": "a", "text": "Postorder (children answer first), lockstep comparison of two trees, and level-by-level (BFS)"},
        {"id": "b", "text": "Sorting, searching, and hashing"},
        {"id": "c", "text": "Recursive, iterative, and parallel"},
        {"id": "d", "text": "Insert, delete, and update"}
      ],
      "correct": "a",
      "explanation": "Invert and Max Depth build their answer from the children first (postorder). Same Tree walks two trees together. Level Order needs a queue instead of recursion. Naming which shape fits saves time before coding." }
] }
```
