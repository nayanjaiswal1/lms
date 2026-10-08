package labs

import "fmt"

// ResolveImageProfiles maps LABS_IMAGE_PROFILES entries (image -> profile name)
// to catalog profiles. Shared by the API server and the lab agent so both
// size and harden an image identically.
//
// The in-code catalog today holds "nested-docker" and "debug-ide" (see
// ImageProfileNestedDocker / docs/labs.md "Nested Docker labs"). Adding a
// profile means adding one entry here.
func ResolveImageProfiles(names map[string]string, nestedRuntime, nestedRuntimeClass string) (map[string]ImageProfile, error) {
	mechanism := "rootless-dind"
	if nestedRuntime == "sysbox-runc" {
		mechanism = "sysbox-runc"
	}
	catalog := map[string]ImageProfile{
		ImageProfileDebugIDE: DebugIDEProfile(),
		ImageProfileNestedDocker: {
			Name:                 ImageProfileNestedDocker,
			Elevated:             true,
			CPU:                  NestedContainerCPU,
			MemoryMB:             NestedContainerMemoryMB,
			PidsLimit:            NestedContainerPidsLimit,
			DiskGB:               NestedContainerDiskGB,
			Network:              NestedLabNetwork,
			SkipPreWarm:          true,
			RequiresOrgAllowlist: true,
			DockerMechanism:      mechanism,
			K8sRuntimeClass:      nestedRuntimeClass,
			K8sExtraVolume:       true,
			K8sExtraVolumeSizeGB: NestedContainerDiskGB,
		},
	}
	out := make(map[string]ImageProfile, len(names))
	for image, profileName := range names {
		profile, ok := catalog[profileName]
		if !ok {
			return nil, fmt.Errorf("labs: LABS_IMAGE_PROFILES image %q references unknown profile %q", image, profileName)
		}
		out[image] = profile
	}
	return out, nil
}
