// Appends one JSON line per signal to the lab activity log:
//   {"type":"file_open","detail":"<workspace-relative path>","value":0}
//   {"type":"paste","detail":"","value":<characters inserted>}
// The platform reads and validates the log when the session closes
// (backend/internal/labs/activity_capture.go). Best-effort: a failed write
// never disturbs the editor.
const vscode = require("vscode");
const fs = require("fs");

const LOG_PATH = "/var/log/mindforge-lab/activity.jsonl";
// Hard cap so a runaway editor cannot fill the sandbox disk.
const MAX_LOG_BYTES = 256 * 1024;
// One edit inserting this many characters at once is counted as a paste: typing
// and snippet expansion stay below it.
const PASTE_MIN_CHARS = 30;

function record(type, detail, value) {
  try {
    let size = 0;
    try {
      size = fs.statSync(LOG_PATH).size;
    } catch {
      // first write creates the file
    }
    if (size > MAX_LOG_BYTES) return;
    fs.appendFileSync(LOG_PATH, JSON.stringify({ type, detail, value }) + "\n");
  } catch {
    // best-effort
  }
}

function activate(context) {
  let lastOpened = "";
  context.subscriptions.push(
    vscode.window.onDidChangeActiveTextEditor((editor) => {
      const uri = editor && editor.document.uri;
      if (!uri || uri.scheme !== "file") return;
      const rel = vscode.workspace.asRelativePath(uri, false);
      if (rel === lastOpened) return;
      lastOpened = rel;
      record("file_open", rel, 0);
    }),
    vscode.workspace.onDidChangeTextDocument((event) => {
      if (event.document.uri.scheme !== "file" || event.reason !== undefined) return; // undo/redo
      if (event.contentChanges.length !== 1) return;
      const inserted = event.contentChanges[0].text.length;
      if (inserted >= PASTE_MIN_CHARS) record("paste", "", inserted);
    }),
  );
}

module.exports = { activate };
