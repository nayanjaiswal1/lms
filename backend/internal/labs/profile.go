package labs

// ImageProfile describes the container configuration a lab environment image
// gets, resolved once per image via ContainerRuntime.Classify against the
// operator's LABS_IMAGE_PROFILES mapping (config.LabsImageProfiles). The zero
// value is the "standard" profile — every image with no entry in that
// mapping resolves to it, preserving the platform default: normal CPU/mem
// (ContainerCPU/ContainerMemoryMB), no elevation, no org-allowlist
// requirement, pre-warm eligible.
//
// Adding a second real profile (e.g. a future "gpu" type) means adding one
// named ImageProfile value to the catalog in main.go and mapping images to
// its name via LABS_IMAGE_PROFILES — no new interface method and no new
// branch in either runtime file.
type ImageProfile struct {
	// Name identifies the profile ("" = standard/zero-value default,
	// otherwise a name from the in-code catalog built in main.go, e.g.
	// "nested-docker"). A non-empty Name is what both runtimes treat as
	// "this image is elevated" — see KubernetesContainerService.startPod's
	// RuntimeClass requirement below.
	Name string

	// CPU/MemoryMB size the container/Pod. Empty/zero falls back to
	// ContainerCPU/ContainerMemoryMB (the standard profile's implicit
	// values) — a named profile only needs to set these when it wants
	// something other than the default.
	CPU      string
	MemoryMB int
	// Network is the Docker network the container joins. Empty falls back to
	// the shared "mindforge-labs" network. Ignored by the Kubernetes
	// runtime, which has no equivalent per-container network selection.
	Network string

	// SkipPreWarm, when true, tells the warm-pool planner to never
	// pre-provision this image unclaimed — e.g. an idle elevated container
	// is pure risk with no student waiting on it, and a nested dockerd's
	// 30s+ boot means "ready" can't be verified the way it is for an
	// ordinary image. Zero value (false) = eligible, matching the standard
	// profile.
	SkipPreWarm bool
	// RequiresOrgAllowlist, when true, tells Service.StartSession this image
	// is never a platform default — it requires an explicit entry in the
	// requesting org's lab_org_config.allowed_images regardless of how that
	// list is otherwise configured. Zero value (false) = ordinary allowlist
	// rules apply (empty list = unrestricted).
	RequiresOrgAllowlist bool

	// DockerMechanism selects the Docker-specific elevation applied by
	// DockerContainerService.buildRunArgs. Ignored by the Kubernetes
	// runtime.
	//   ""             — normal container: --cap-drop ALL, no-new-privileges
	//   "sysbox-runc"  — --cap-drop ALL --runtime sysbox-runc, no added caps
	//   "rootless-dind" — scoped --cap-add grant for rootless dockerd; may
	//                     retry once with --privileged if the scoped grant
	//                     fails (see DockerContainerService.startNamed)
	DockerMechanism string

	// K8sRuntimeClass sets Pod.Spec.RuntimeClassName for images using this
	// profile. Kubernetes has no equivalent of Docker's --cap-add flags, so
	// any profile with a non-empty Name (i.e. anything but the standard
	// profile) REQUIRES this to be set — KubernetesContainerService.startPod
	// fails the session loudly rather than approximate elevated capabilities
	// on a shared node pool with no RuntimeClass isolation.
	K8sRuntimeClass string
	// K8sExtraVolume, when true, mounts an emptyDir at /var/lib/docker —
	// today's nested-Docker-only requirement (dockerd's own storage), kept
	// as an independent knob from K8sRuntimeClass since a future elevated
	// profile might need a RuntimeClass without this particular volume.
	K8sExtraVolume bool
	// K8sExtraVolumeSizeGB caps that emptyDir (and the container's
	// ephemeral-storage request/limit, so the scheduler accounts for it too)
	// — see NestedContainerDiskGB. Zero falls back to that constant, same as
	// CPU/MemoryMB falling back to ContainerCPU/ContainerMemoryMB. Ignored
	// when K8sExtraVolume is false.
	K8sExtraVolumeSizeGB int
}

// ImageProfileNestedDocker names the one real non-standard profile that
// exists today (Docker-in-Docker nested labs, e.g. mindforge/lab-docker) —
// the in-code catalog entry LABS_IMAGE_PROFILES entries resolve against is
// built in main.go.
const ImageProfileNestedDocker = "nested-docker"
