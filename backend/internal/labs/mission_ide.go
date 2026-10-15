package labs

import (
	"context"
	"fmt"
	"strings"
)

// missionIDESettings is merged into the workspace settings for mission-mode
// sessions: a dense editor (no activity bar, minimap, breadcrumbs, status bar or
// layout chrome) and a read-only incident evidence folder. The path pattern
// matches mf-build's EVIDENCE_DIR; the ticket stays read-only too. Sessions of
// orgs on the old debug UI never get this, so their IDE is unchanged.
//
// These go in the workspace's .vscode/settings.json, not the IDE's user settings:
// the web client keeps user settings in the browser (IndexedDB) and ignores the
// server's User/settings.json. Only window/resource-scoped keys apply here, so the
// application-scoped window.* chrome settings are left out.
const missionIDESettings = `{
  "workbench.activityBar.location": "hidden",
  "workbench.statusBar.visible": false,
  "workbench.layoutControl.enabled": false,
  "editor.minimap.enabled": false,
  "editor.scrollBeyondLastLine": false,
  "editor.fontSize": 13,
  "breadcrumbs.enabled": false,
  "workbench.tree.indent": 12,
  "explorer.compactFolders": false,
  "files.readonlyInclude": {"**/evidence/**": true, "**/TICKET.md": true}
}`

// ideWorkspaceSettingsPath is the workspace settings file mf-build writes (docs.py
// _vscode); the IDE re-reads it on change, so this works after the IDE has booted.
const ideWorkspaceSettingsPath = "/home/labuser/work/.vscode/settings.json"

// mergeIDESettingsScript merges the JSON on stdin into the workspace settings.
const mergeIDESettingsScript = `python3 -c 'import json,sys; p="` + ideWorkspaceSettingsPath + `"; d=json.load(open(p)); d.update(json.load(sys.stdin)); json.dump(d,open(p,"w"),indent=2)'`

// applyMissionIDESettings writes the mission editor settings into the container's workspace settings.
func (s *Service) applyMissionIDESettings(ctx context.Context, containerID string) error {
	_, stderr, exitCode, err := s.container.ExecStdin(ctx, containerID, mergeIDESettingsScript, []byte(missionIDESettings), SetupScriptTimeoutSeconds)
	if err != nil {
		return fmt.Errorf("labs.Service.applyMissionIDESettings: exec: %w", err)
	}
	if exitCode != 0 {
		return fmt.Errorf("labs.Service.applyMissionIDESettings: exited %d: %s", exitCode, strings.TrimSpace(stderr))
	}
	return nil
}
