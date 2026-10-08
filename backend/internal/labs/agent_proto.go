package labs

// Wire contract between AgentClient (API server) and the lab agent
// (internal/labagent). Deliberately carries no Docker flags: the agent derives
// every security-relevant option itself, so a compromised API server can only
// ask for "start allowed image X".
const (
	AgentPathContainers = "/v1/containers"
	// A single container is addressed as AgentPathContainers + "/{id}" + suffix.
	AgentSuffixExec        = "/exec"
	AgentSuffixExecCapture = "/exec-capture"
	AgentSuffixRunning     = "/running"
	AgentSuffixPause       = "/pause"
	AgentSuffixUnpause     = "/unpause"
)

// Container start kinds; they select the name prefix on the agent.
const (
	AgentKindLab        = "lab"
	AgentKindWarm       = "warm"
	AgentKindValidation = "validation"
)

// Exec modes.
const (
	AgentExecUser  = "user"
	AgentExecSetup = "setup"
)

// Bounds the agent enforces on every request.
const (
	AgentMaxExecTimeoutSec = 600
	AgentMaxCaptureBytes   = 64 * 1024 * 1024
	AgentMaxRequestBytes   = 8 * 1024 * 1024
)

type AgentStartRequest struct {
	Kind       string `json:"kind"`
	ID         string `json:"id"`
	ResetCount int    `json:"reset_count"`
	Image      string `json:"image"`
}

type AgentStartResponse struct {
	ContainerID   string `json:"container_id"`
	ContainerHost string `json:"container_host"`
}

type AgentExecRequest struct {
	Mode       string `json:"mode"`
	Script     string `json:"script"`
	Stdin      []byte `json:"stdin,omitempty"`
	TimeoutSec int    `json:"timeout_sec"`
}

type AgentExecCaptureRequest struct {
	Script   string `json:"script"`
	MaxBytes int    `json:"max_bytes"`
}

// AgentExecResponse carries raw bytes so binary output (tar bundles) survives JSON.
type AgentExecResponse struct {
	Stdout   []byte `json:"stdout"`
	Stderr   []byte `json:"stderr"`
	ExitCode int    `json:"exit_code"`
}

type AgentRunningResponse struct {
	Running bool `json:"running"`
}

type AgentContainerInfo struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	CreatedAt string `json:"created_at"`
}

type AgentErrorResponse struct {
	Error string `json:"error"`
}
