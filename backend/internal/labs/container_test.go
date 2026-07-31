package labs

import (
	"fmt"
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
		CPU:                  NestedContainerCPU,
		MemoryMB:             NestedContainerMemoryMB,
		Network:              NestedLabNetwork,
		SkipPreWarm:          true,
		RequiresOrgAllowlist: true,
		DockerMechanism:      mechanism,
	}
}

func TestBuildRunArgs_NonNestedImageUnchanged(t *testing.T) {
	// A container for an image NOT mapped to any profile must get exactly
	// the platform's normal args, regardless of whether nested-Docker is
	// configured at all for other images — enabling the feature for one
	// image must never change behavior for every other lab.
	svc := NewDockerContainerService(map[string]ImageProfile{
		"mindforge/lab-docker:27": nestedDockerTestProfile("rootless-dind"),
	})
	args := svc.buildRunArgs("mindforge-lab-abc-0", "mindforge/lab-k8s:1.31", false)

	require.Equal(t, []string{
		"run", "-d", "--name", "mindforge-lab-abc-0",
		"--cpus", ContainerCPU, "--memory", fmt.Sprintf("%dm", ContainerMemoryMB),
		"--cap-drop", "ALL",
		"--security-opt", "no-new-privileges",
		"--network", "mindforge-labs",
		"--restart", "no", "mindforge/lab-k8s:1.31",
	}, args)
}

func TestBuildRunArgs_FeatureOffByDefault(t *testing.T) {
	// Zero-value construction (as if LABS_IMAGE_PROFILES were unset) must
	// never elevate any image.
	svc := NewDockerContainerService(nil)
	args := svc.buildRunArgs("mindforge-lab-abc-0", "mindforge/lab-docker:27", false)
	assert.NotContains(t, args, "SYS_ADMIN")
	assert.Contains(t, args, "no-new-privileges")
	assert.Contains(t, args, "mindforge-labs")
}

func TestBuildRunArgs_NestedImageRootlessDind(t *testing.T) {
	svc := NewDockerContainerService(map[string]ImageProfile{
		"mindforge/lab-docker:27": nestedDockerTestProfile("rootless-dind"),
	})
	args := svc.buildRunArgs("mindforge-lab-abc-0", "mindforge/lab-docker:27", false)

	require.Equal(t, []string{
		"run", "-d", "--name", "mindforge-lab-abc-0",
		"--cpus", NestedContainerCPU, "--memory", fmt.Sprintf("%dm", NestedContainerMemoryMB),
		"--cap-drop", "ALL",
		"--cap-add", "SYS_ADMIN",
		"--cap-add", "SETUID",
		"--cap-add", "SETGID",
		"--device", "/dev/fuse",
		"--device", "/dev/net/tun",
		"--security-opt", "seccomp=unconfined",
		"--security-opt", "apparmor=unconfined",
		"--network", NestedLabNetwork,
		"--restart", "no", "mindforge/lab-docker:27",
	}, args)
	assert.NotContains(t, args, "no-new-privileges", "no-new-privileges blocks rootless dind's newuidmap setuid")
	assert.NotContains(t, args, "--privileged", "the scoped (non-fallback) attempt must never use bare --privileged")
}

func TestBuildRunArgs_NestedImagePrivilegedFallback(t *testing.T) {
	// Only ever requested by startNamed's own retry, after the scoped
	// attempt above has already failed to produce a running container — see
	// startNamed's doc comment for when/why.
	svc := NewDockerContainerService(map[string]ImageProfile{
		"mindforge/lab-docker:27": nestedDockerTestProfile("rootless-dind"),
	})
	args := svc.buildRunArgs("mindforge-lab-abc-0", "mindforge/lab-docker:27", true)

	require.Equal(t, []string{
		"run", "-d", "--name", "mindforge-lab-abc-0",
		"--cpus", NestedContainerCPU, "--memory", fmt.Sprintf("%dm", NestedContainerMemoryMB),
		"--privileged",
		"--network", NestedLabNetwork,
		"--restart", "no", "mindforge/lab-docker:27",
	}, args)
}

func TestBuildRunArgs_NestedImageSysboxRuntime(t *testing.T) {
	svc := NewDockerContainerService(map[string]ImageProfile{
		"mindforge/lab-docker:27": nestedDockerTestProfile("sysbox-runc"),
	})
	args := svc.buildRunArgs("mindforge-lab-abc-0", "mindforge/lab-docker:27", false)

	require.Equal(t, []string{
		"run", "-d", "--name", "mindforge-lab-abc-0",
		"--cpus", NestedContainerCPU, "--memory", fmt.Sprintf("%dm", NestedContainerMemoryMB),
		"--cap-drop", "ALL",
		"--runtime", "sysbox-runc",
		"--network", NestedLabNetwork,
		"--restart", "no", "mindforge/lab-docker:27",
	}, args)
	assert.NotContains(t, args, "SYS_ADMIN", "sysbox-runc needs no added capabilities")
}

func TestBuildRunArgs_SysboxIgnoresPrivilegedFallback(t *testing.T) {
	// sysbox-runc already avoids the whole scoped-capability problem cleanly
	// and startNamed never requests a privileged retry for it (see
	// startNamed) — but buildRunArgs itself should still be defensive: a
	// sysbox host must never end up privileged even if asked.
	svc := NewDockerContainerService(map[string]ImageProfile{
		"mindforge/lab-docker:27": nestedDockerTestProfile("sysbox-runc"),
	})
	args := svc.buildRunArgs("mindforge-lab-abc-0", "mindforge/lab-docker:27", true)
	assert.NotContains(t, args, "--privileged")
	assert.Contains(t, args, "sysbox-runc")
}
