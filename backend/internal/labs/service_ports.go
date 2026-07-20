package labs

import (
	"context"
	"fmt"
	"sort"
	"strconv"
	"strings"
)

const portsExecTimeoutSec = 5

// ttydContainerPort is the in-container port ttyd always listens on; it is
// infrastructure, never a student app, so port listings exclude it.
const ttydContainerPort = 7681

// LabPort is one listening TCP port detected inside the session container.
type LabPort struct {
	Port int `json:"port"`
}

// LabPortsData is the response shape for ListPorts.
type LabPortsData struct {
	Ports []LabPort `json:"ports"`
}

// portScanScript prints every listening TCP port inside the container, one
// decimal per line, by parsing /proc/net/tcp{,6} (state 0A = LISTEN). Uses
// only bash builtins + coreutils — lab images ship no ss/lsof.
// Only wildcard binds (0.0.0.0 / ::) are listed: labproxy dials the
// container's network IP, so loopback-bound listeners (e.g. Docker's
// embedded DNS on 127.0.0.11) are unreachable through the preview anyway
// and only confuse the port list.
// ponytail: ports only, no process names — port→pid needs a /proc fd inode
// walk; add it when a user actually asks for it.
const portScanScript = `cat /proc/net/tcp /proc/net/tcp6 2>/dev/null | while read -r _ local _ st _; do
  [ "$st" = "0A" ] || continue
  ip=${local%%:*}
  [ -z "${ip//0/}" ] || continue
  printf '%d\n' "0x${local##*:}" 2>/dev/null
done | sort -un`

// parseListeningPorts converts portScanScript stdout (newline-delimited
// decimal ports) into a deduplicated, sorted port list with the ttyd
// infrastructure port removed.
func parseListeningPorts(raw string) []LabPort {
	seen := map[int]bool{}
	for _, line := range strings.Split(raw, "\n") {
		port, err := strconv.Atoi(strings.TrimSpace(line))
		if err != nil || port <= 0 || port > 65535 || port == ttydContainerPort {
			continue
		}
		seen[port] = true
	}
	ports := make([]LabPort, 0, len(seen))
	for port := range seen {
		ports = append(ports, LabPort{Port: port})
	}
	sort.Slice(ports, func(i, j int) bool { return ports[i].Port < ports[j].Port })
	return ports
}

// ListPorts returns the TCP ports currently listening inside the session's
// container, for the sandbox workspace's port list / preview picker.
// ponytail: no server-side rate limit — the 5s client poll plus the exec cost
// is the ceiling; add a Redis token bucket only if abuse shows up.
func (s *Service) ListPorts(ctx context.Context, sessionID, userID string) (*LabPortsData, error) {
	session, err := s.loadRunnableSession(ctx, sessionID, userID)
	if err != nil {
		return nil, err
	}

	stdout, stderr, exitCode, err := s.container.Exec(ctx, *session.ContainerID, portScanScript, portsExecTimeoutSec)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.ListPorts: exec: %w", err)
	}
	if exitCode != 0 {
		return nil, fmt.Errorf("labs.Service.ListPorts: scan failed: %s", stderr)
	}
	return &LabPortsData{Ports: parseListeningPorts(stdout)}, nil
}
