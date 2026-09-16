---
kind: lesson
id_key: interview-prep-45/day-06
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Trees - Basics"
position: 6
estimated_minutes: 120
source:
    - 45-day-interview-roadmap.md
---
Trees are where recursion stops being optional and becomes the natural tool. Most tree problems have a one-to-one mapping between the recursive structure of the tree and the recursive structure of the solution. Today builds the traversal vocabulary (inorder, preorder, postorder, level-order) that every later tree and graph problem assumes you already have automatic.

## Tree traversal: inorder, preorder, postorder, level-order

For a binary tree node with `left` and `right` children, the three depth-first traversals differ only in *when* you visit the node relative to its children:

- **Preorder**: node, left, right. Visit the node before its subtrees. Useful for copying/serializing a tree top-down.
- **Inorder**: left, node, right. Visit the node between its subtrees. For a BST, this produces sorted output (see Day 8).
- **Postorder**: left, right, node. Visit the node after its subtrees. Useful when children must be fully processed first (deleting a tree, computing subtree aggregates).

**Level-order** (BFS) is different in kind: it visits nodes level by level, left to right, using a queue instead of recursion/stack.

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

The list-concatenation versions above are readable but build intermediate lists; production code should pass an accumulator list by reference instead. Know both forms.

## Recursive vs iterative traversal

Every DFS traversal has an iterative form using an explicit stack (see the stack-vs-recursion section). The tricky one is inorder, because you can't just push both children like preorder. You have to go all the way left first, then process, then go right:

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

Interviewers ask for the iterative version to check whether you actually understand what the recursion is doing, rather than whether you memorized the three-line recursive function.

Preorder is the easiest to make iterative: push right before left so left pops first.

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

Postorder iteratively is the fiddly one: compute preorder-but-"node, right, left" (swap the push order above) and reverse the result. That produces "left, right, node" for free.

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

## Tree properties

Two properties worth having cold since they recur constantly:

- **Height/depth**: height of a node is the number of edges on the longest path to a leaf below it; `height(None) = -1` (or 0, depending on convention, so state which you're using). Computing height bottom-up is a natural postorder recursion.
- **Balanced**: a tree is height-balanced if, for every node, the heights of its left and right subtrees differ by at most 1. Checking balance naively (`height` at every node) is O(n²) in the worst case (skewed tree); the efficient version returns height and computes balance in a single postorder pass, O(n).

## Invert Binary Tree

[Invert Binary Tree (LeetCode 226)](https://leetcode.com/problems/invert-binary-tree/)

**Intuition:** Inverting means every node's left and right children swap, recursively, all the way down. This is a direct postorder-shaped recursion: invert both subtrees, then swap.

**Approach:** Base case: `None` inverts to `None`. Recursive case: swap `root.left` and `root.right`, having first recursively inverted each.

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

**Complexity:** Time O(n): visits every node once. Space O(h) for the recursion stack, where h is tree height (O(log n) balanced, O(n) skewed).

**Common mistakes:**
- Swapping `root.left`/`root.right` *before* recursing on the original children: this leads to inverting the wrong subtree or double-swapping. The simultaneous-assignment version above sidesteps this by evaluating both recursive calls before either assignment happens.
- Forgetting the `None` base case, causing infinite recursion or an `AttributeError`.

## Maximum Depth of Binary Tree

[Maximum Depth of Binary Tree (LeetCode 104)](https://leetcode.com/problems/maximum-depth-of-binary-tree/)

**Intuition:** The depth of a tree is 1 (for the current node) plus the deeper of its two subtrees' depths, a textbook postorder recursion.

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

**Complexity:** Time O(n), space O(h) recursion stack.

**Common mistakes:**
- Off-by-one: forgetting the `+ 1` for the current node, or double-counting it.
- Attempting an iterative BFS solution without tracking level count correctly, since you must count levels, not nodes.

## Same Tree

[Same Tree (LeetCode 100)](https://leetcode.com/problems/same-tree/)

**Intuition:** Two trees are identical if their roots have the same value and both subtree pairs are also identical, a direct structural recursion comparing two trees in lockstep.

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

**Complexity:** Time O(min(n, m)): short-circuits as soon as trees diverge. Space O(min(h_p, h_q)) recursion stack.

**Common mistakes:**
- Checking `p.val == q.val` before checking either is `None`, causing an `AttributeError` on `None.val`.
- Relying on `and` short-circuiting correctly is fine here; forgetting it and evaluating all three conditions unconditionally still works, just less efficiently on divergent trees. Not a correctness bug.

## Binary Tree Level Order Traversal

[Binary Tree Level Order Traversal (LeetCode 102)](https://leetcode.com/problems/binary-tree-level-order-traversal/)

**Intuition:** "Group nodes by depth level" is exactly what BFS naturally gives you if you process the queue one full level at a time instead of one node at a time.

**Approach:** Use a queue. At each iteration, snapshot the current queue length (`len(queue)`), which is exactly how many nodes belong to the current level, pop that many, and collect their values while enqueuing their children.

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

**Complexity:** Time O(n): every node enqueued and dequeued once. Space O(w) for the queue, where w is the maximum tree width, plus O(n) for the output.

**Common mistakes:**
- Not snapshotting `len(queue)` before the inner loop. Checking `len(queue)` on each inner iteration instead lets it change as you enqueue children, merging levels together.
- Using a stack instead of a `deque` for the queue, or using `list.pop(0)` (O(n) per call) instead of `deque.popleft()` (O(1)).

## Reading the shape before you code

Every problem in this lesson reduces to the same question: does this node's answer depend only on its children's answers (postorder: Invert, Max Depth), or does it depend on comparing two trees in lockstep (Same Tree), or does it need to process the tree breadth-first (Level Order)? Spend ten seconds naming which of those three shapes a new tree problem fits before writing any code. Guessing at the recursion instead of naming the shape first is where most tree bugs start.
