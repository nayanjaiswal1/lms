package labs

import (
	"context"
	"fmt"
	"log/slog"
	"sort"
	"strconv"
	"strings"
	"time"
)

const portsExecTimeoutSec = 5

// portsRateLimitSeconds is the per-session cooldown between port scans —
// tighter than the 5s client poll interval so a caller hitting this directly
// (bypassing the poll) can't drive repeated container exec calls.
const portsRateLimitSeconds = 3

// ttydContainerPort is the in-container port ttyd always listens on; it is
// infrastructure, never a student app, so port listings exclude it.
const ttydContainerPort = 7681

// LabPort is one listening TCP port detected inside the session container.
// ProcessName is best-effort: empty when the port->pid->comm resolution
// below couldn't identify (or wasn't permitted to read) the owning process.
type LabPort struct {
	Port        int    `json:"port"`
	ProcessName string `json:"process_name,omitempty"`
}

// LabPortsData is the response shape for ListPorts.
type LabPortsData struct {
	Ports []LabPort `json:"ports"`
}

// portScanScript prints every listening TCP port inside the container, one
// "port\tprocess_name" pair per line (process_name empty when unresolved),
// by parsing /proc/net/tcp{,6} (state 0A = LISTEN) for the port->inode
// mapping and then walking /proc/[pid]/fd/* to match each inode's
// "socket:[N]" symlink target back to the owning pid, whose name comes from
// /proc/[pid]/comm. Uses only bash builtins + coreutils — lab images ship no
// ss/lsof/fuser. The fd walk is best-effort: a pid whose fd directory this
// script can't read (owned by a different container user) simply yields no
// name for that port rather than failing the whole scan.
// Only wildcard binds (0.0.0.0 / ::) are listed: labproxy dials the
// container's network IP, so loopback-bound listeners (e.g. Docker's
// embedded DNS on 127.0.0.11) are unreachable through the preview anyway
// and only confuse the port list.
const portScanScript = `declare -A port_inode
while read -r sl local rem st txrx trtm retr uid timeout inode _; do
  [ "$st" = "0A" ] || continue
  ip=${local%%:*}
  [ -z "${ip//0/}" ] || continue
  port=$((16#${local##*:}))
  [ "$port" -gt 0 ] && port_inode[$port]=$inode
done < <(cat /proc/net/tcp /proc/net/tcp6 2>/dev/null)

declare -A inode_pid
for fd in /proc/[0-9]*/fd/*; do
  target=$(readlink "$fd" 2>/dev/null) || continue
  case "$target" in
    socket:\[*\])
      inode=${target#socket:[}
      inode=${inode%]}
      pid=${fd#/proc/}
      pid=${pid%%/*}
      inode_pid[$inode]=$pid
      ;;
  esac
done

for port in "${!port_inode[@]}"; do
  pid=${inode_pid[${port_inode[$port]}]:-}
  name=""
  [ -n "$pid" ] && name=$(cat "/proc/$pid/comm" 2>/dev/null)
  printf '%d\t%s\n' "$port" "$name"
done | sort -n`

// parseListeningPorts converts portScanScript stdout (newline-delimited
// "port\tprocess_name" pairs) into a deduplicated, sorted port list with the
// ttyd infrastructure port removed.
func parseListeningPorts(raw string) []LabPort {
	seen := map[int]string{}
	for _, line := range strings.Split(raw, "\n") {
		line = strings.TrimRight(line, "\r")
		if line == "" {
			continue
		}
		portField, name, _ := strings.Cut(line, "\t")
		port, err := strconv.Atoi(strings.TrimSpace(portField))
		if err != nil || port <= 0 || port > 65535 || port == ttydContainerPort {
			continue
		}
		name = strings.TrimSpace(name)
		if existing, ok := seen[port]; !ok || (existing == "" && name != "") {
			seen[port] = name
		}
	}
	ports := make([]LabPort, 0, len(seen))
	for port, name := range seen {
		ports = append(ports, LabPort{Port: port, ProcessName: name})
	}
	sort.Slice(ports, func(i, j int) bool { return ports[i].Port < ports[j].Port })
	return ports
}

// ListPorts returns the TCP ports currently listening inside the session's
// container, for the sandbox workspace's port list / preview picker.
func (s *Service) ListPorts(ctx context.Context, sessionID, userID string) (*LabPortsData, error) {
	// Rate limit before touching the container. Fail open on Redis errors
	// (same policy as RunScript/SubmitAll/VerifyTask).
	rateLimitKey := fmt.Sprintf("lab:ports:rate:%s", sessionID)
	set, rErr := s.rdb.SetNX(ctx, rateLimitKey, 1, portsRateLimitSeconds*time.Second).Result()
	if rErr != nil {
		slog.Error("labs.Service.ListPorts: rate limit check", "error", rErr)
	} else if !set {
		return nil, ErrRateLimited
	}

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
