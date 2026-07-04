export interface LabFileEntry {
  path: string
  type: "file" | "dir"
}

export interface ValidateResult {
  valid: boolean
  stdout?: string
  stderr?: string
}

export interface FileTreeNode {
  name: string
  path: string
  type: "file" | "dir"
  children?: FileTreeNode[]
}

// Turns the flat, recursive `find`-style listing the backend returns into a
// nested tree for the VS Code-style explorer. Synthesizes any intermediate
// directory the backend didn't list explicitly, so the tree is always
// well-formed even if a "dir" entry is missing for some ancestor.
export function buildFileTree(entries: LabFileEntry[]): FileTreeNode[] {
  const root: FileTreeNode[] = []
  const dirs = new Map<string, FileTreeNode>()

  function ensureDir(dirPath: string): FileTreeNode[] {
    if (dirPath === "") return root
    const existing = dirs.get(dirPath)
    if (existing) return (existing.children ??= [])

    const lastSlash = dirPath.lastIndexOf("/")
    const name = lastSlash === -1 ? dirPath : dirPath.slice(lastSlash + 1)
    const parentPath = lastSlash === -1 ? "" : dirPath.slice(0, lastSlash)
    const node: FileTreeNode = { name, path: dirPath, type: "dir", children: [] }
    dirs.set(dirPath, node)
    ensureDir(parentPath).push(node)
    return node.children as FileTreeNode[]
  }

  for (const entry of [...entries].sort((a, b) => a.path.localeCompare(b.path))) {
    const lastSlash = entry.path.lastIndexOf("/")
    const name = lastSlash === -1 ? entry.path : entry.path.slice(lastSlash + 1)
    const parentPath = lastSlash === -1 ? "" : entry.path.slice(0, lastSlash)
    const siblings = ensureDir(parentPath)

    if (entry.type === "dir") {
      if (!dirs.has(entry.path)) {
        const node: FileTreeNode = { name, path: entry.path, type: "dir", children: [] }
        dirs.set(entry.path, node)
        siblings.push(node)
      }
    } else {
      siblings.push({ name, path: entry.path, type: "file" })
    }
  }

  function sortTree(nodes: FileTreeNode[]) {
    nodes.sort((a, b) => (a.type === b.type ? a.name.localeCompare(b.name) : a.type === "dir" ? -1 : 1))
    for (const node of nodes) if (node.children) sortTree(node.children)
  }
  sortTree(root)

  return root
}

// Raw passthrough of `kubectl get all,ns,pv,pvc,cm,secret -A -o json` — shape
// is whatever the apiserver returns, rendered generically rather than typed
// item-by-item.
export type LabResourcesData = Record<string, unknown>
