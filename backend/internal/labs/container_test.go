package labs

import (
	"fmt"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// nestedDockerTestProfile builds the "nested-docker" ImageProfile a real
// deployment would assemble in main.go's profile catalog, with the given
// DockerMechanism ("rootless-dind" or "sysbox-runc") standing in for what
// today's tests passed as the nestedRuntime constructor argument.
func nestedDockerTestProfile(mechanism string) ImageProfile {
	return ImageProfile{
		Name:                 ImageProfileNestedDocker,
		Elevated:             true,
		CPU:                  NestedContainerCPU,
		MemoryMB:             NestedContainerMemoryMB,
		Network:              NestedLabNetwork,
		SkipPreWarm:          true,
		RequiresOrgAllowlist: true,
		DockerMechanism:      mechanism,
	}
}

// limitArgs is the H-12 block every container gets right after --memory.
func limitArgs(memMB, pids int) []string {
	mem := fmt.Sprintf("%dm", memMB)
	return []string{"--memory", mem, "--memory-swap", mem,
		"--pids-limit", fmt.Sprint(pids),
		"--ulimit", fmt.Sprintf("nofile=%d:%d", ContainerNofileLimit, ContainerNofileLimit),
		"--ulimit", "core=0"}
}

func concat(parts ...[]string) []string {
	var out []string
	for _, p := range parts {
		out = append(out, p...)
	}
	return out
}

func TestBuildRunArgs_NonNestedImageUnchanged(t *testing.T) {
	// An image NOT mapped to any profile gets the platform's normal args,
	// regardless of nested-Docker being configured for other images.
	svc := NewDockerContainerService(map[string]ImageProfile{
		"mindforge/lab-docker:27": nestedDockerTestProfile("rootless-dind"),
	})
	args := svc.buildRunArgs("mindforge-lab-abc-0", "mindforge/lab-k8s:1.31")

	require.Equal(t, concat(
		[]string{"run", "-d", "--name", "mindforge-lab-abc-0", "--cpus", ContainerCPU},
		limitArgs(ContainerMemoryMB, DefaultContainerPidsLimit),
		[]string{"--cap-drop", "ALL", "--security-opt", "no-new-privileges",
			"--network", "mindforge-labs", "--restart", "no", "mindforge/lab-k8s:1.31"},
	), args)
}

// The exact-args tests above and below already pin the absence of --privileged
// for both real mechanisms; this covers the empty-mechanism profile they don't.
func TestBuildRunArgs_NeverPrivileged(t *testing.T) {
	svc := NewDockerContainerService(map[string]ImageProfile{
		"img": nestedDockerTestProfile(""),
	})
	assert.NotContains(t, svc.buildRunArgs("n", "img"), "--privileged")
}

func TestBuildRunArgs_NestedImageRootlessDind(t *testing.T) {
	p := nestedDockerTestProfile("rootless-dind")
	p.PidsLimit = NestedContainerPidsLimit
	svc := NewDockerContainerService(map[string]ImageProfile{"mindforge/lab-docker:27": p})
	args := svc.buildRunArgs("mindforge-lab-abc-0", "mindforge/lab-docker:27")

	require.Equal(t, concat(
		[]string{"run", "-d", "--name", "mindforge-lab-abc-0", "--cpus", NestedContainerCPU},
		limitArgs(NestedContainerMemoryMB, NestedContainerPidsLimit),
		[]string{
			"--cap-drop", "ALL",
			"--cap-add", "SYS_ADMIN",
			"--cap-add", "SETUID",
			"--cap-add", "SETGID",
			"--cap-add", "NET_ADMIN",
			"--device", "/dev/fuse",
			"--device", "/dev/net/tun",
			"--security-opt", "seccomp=unconfined",
			"--security-opt", "apparmor=unconfined",
			"--network", NestedLabNetwork,
			"--restart", "no", "mindforge/lab-docker:27",
		},
	), args)
	assert.NotContains(t, args, "no-new-privileges", "no-new-privileges blocks rootless dind's newuidmap setuid")
}

func TestBuildRunArgs_NestedImageSysboxRuntime(t *testing.T) {
	svc := NewDockerContainerService(map[string]ImageProfile{
		"mindforge/lab-docker:27": nestedDockerTestProfile("sysbox-runc"),
	})
	args := svc.buildRunArgs("mindforge-lab-abc-0", "mindforge/lab-docker:27")

	require.Equal(t, concat(
		[]string{"run", "-d", "--name", "mindforge-lab-abc-0", "--cpus", NestedContainerCPU},
		limitArgs(NestedContainerMemoryMB, DefaultContainerPidsLimit),
		[]string{"--cap-drop", "ALL", "--runtime", "sysbox-runc",
			"--network", NestedLabNetwork, "--restart", "no", "mindforge/lab-docker:27"},
	), args)
	assert.NotContains(t, args, "SYS_ADMIN", "sysbox-runc needs no added capabilities")
}

func TestBuildRunArgs_ConfiguredPidsLimit(t *testing.T) {
	svc := NewDockerContainerService(nil)
	svc.SetHardening(RuntimeLimits{PidsLimit: 99}, NetworkPolicy{})
	assert.Contains(t, strings.Join(svc.buildRunArgs("n", "img"), " "), "--pids-limit 99")
}

func TestBuildRunArgs_PerSessionNetwork(t *testing.T) {
	svc := NewDockerContainerService(map[string]ImageProfile{
		"dind": nestedDockerTestProfile("rootless-dind"),
	})
	svc.SetHardening(RuntimeLimits{}, NetworkPolicy{PerSession: true, Internal: true, ProxyContainer: "proxy"})

	args := svc.buildRunArgs("mindforge-lab-x-0", "plain")
	assert.Contains(t, strings.Join(args, " "), "--network mindforge-lab-x-0")
	assert.True(t, svc.usesSessionNetwork("mindforge-lab-x-0", svc.Classify("plain")))
	// Profile-networked (nested) images keep their own network.
	assert.False(t, svc.usesSessionNetwork("mindforge-lab-x-0", svc.Classify("dind")))
	assert.Contains(t, strings.Join(svc.buildRunArgs("n", "dind"), " "), "--network "+NestedLabNetwork)

	assert.Equal(t, []string{"network", "create", "--label", SessionNetworkLabel, "--internal", "n"}, svc.sessionNetworkCreateArgs("n"))
	assert.Equal(t, []string{"network", "connect", "n", "proxy"}, svc.sessionNetworkConnectArgs("n"))

	svc.SetHardening(RuntimeLimits{}, NetworkPolicy{PerSession: true, ProxyContainer: "proxy"})
	assert.NotContains(t, svc.sessionNetworkCreateArgs("n"), "--internal")
}

func TestBuildRunArgs_StorageQuota(t *testing.T) {
	svc := NewDockerContainerService(map[string]ImageProfile{"dbg": DebugIDEProfile()})
	assert.NotContains(t, svc.buildRunArgs("n", "plain"), "--storage-opt", "quota is opt-in")

	svc.SetHardening(RuntimeLimits{StorageQuota: true}, NetworkPolicy{})
	assert.Contains(t, strings.Join(svc.buildRunArgs("n", "plain"), " "), "--storage-opt size=3G")
	assert.Contains(t, strings.Join(svc.buildRunArgs("n", "dbg"), " "), "--storage-opt size=5G")
}
