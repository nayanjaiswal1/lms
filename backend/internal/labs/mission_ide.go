package labs

import (
	"context"
	"fmt"
	"strings"
)

// missionIDESettings is merged into the lab IDE's user settings for mission-mode
// sessions: a dense editor (no activity bar, minimap, breadcrumbs, status bar or
// layout chrome) and a read-only incident evidence folder. The path pattern
// matches mf-build's EVIDENCE_DIR; the ticket stays read-only too. Sessions of
// orgs on the old debug UI never get this, so their IDE is unchanged.
const missionIDESettings = `{
  "workbench.activityBar.location": "hidden",
  "workbench.statusBar.visible": false,
  "workbench.layoutControl.enabled": false,
  "window.commandCenter": false,
  "window.menuBarVisibility": "hidden",
  "editor.minimap.enabled": false,
  "editor.scrollBeyondLastLine": false,
  "editor.fontSize": 13,
  "breadcrumbs.enabled": false,
  "workbench.tree.indent": 12,
  "explorer.compactFolders": false,
  "files.readonlyInclude": {"**/evidence/**": true, "**/TICKET.md": true}
}`

// ideUserSettingsPath is the IDE's user settings file (lab-debug/Dockerfile).
const ideUserSettingsPath = "/opt/ide/data/User/settings.json"

// mergeIDESettingsScript merges the JSON on stdin into the IDE user settings.
// The IDE watches the file, so this works after the IDE has booted.
const mergeIDESettingsScript = `python3 -c 'import json,sys; p="` + ideUserSettingsPath + `"; d=json.load(open(p)); d.update(json.load(sys.stdin)); json.dump(d,open(p,"w"),indent=2)'`

// applyMissionIDESettings writes the mission editor settings into the container.
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
