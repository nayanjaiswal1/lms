package labs

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"strings"
	"time"

	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/kubernetes/scheme"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/tools/remotecommand"
	utilexec "k8s.io/client-go/util/exec"
)

// podPollInterval bounds how often Start polls for a lab Pod to reach Running
// with an assigned IP. The overall wait is bounded by the caller's ctx
// (labs.ProvisionTimeoutSeconds).
const podPollInterval = 500 * time.Millisecond

// KubernetesContainerService implements ContainerRuntime by running each lab
// sandbox as its own Pod in a dedicated namespace, via the in-cluster
// Kubernetes API. See DockerContainerService (container.go) for the
// VPS/Compose equivalent.
//
// Kubernetes Pod exec has no equivalent of `docker exec --user root`: exec
// always runs as the container's own configured user (whatever the image's
// Dockerfile USER sets), never an override. So under this runtime, a lab's
// setup_script runs as the image's default user, not root. lab-images/lab-k8s
// already self-provisions everything internally as labuser at container boot
// and is unaffected; any future lab image whose setup_script assumes root
// needs that logic moved into the image's own entrypoint instead.
type KubernetesContainerService struct {
	clientset  *kubernetes.Clientset
	restConfig *rest.Config
	namespace  string
	// profiles mirrors DockerContainerService's field (see container.go) —
	// the Kubernetes runtime's equivalent operator-configured image ->
	// ImageProfile mapping. Unlike Docker there is no --cap-add escape
	// hatch here: startPod requires ImageProfile.K8sRuntimeClass to be set
	// for any profile with a non-empty Name, and fails the session rather
	// than approximate elevated capabilities on a shared node pool with no
	// RuntimeClass isolation.
	profiles map[string]ImageProfile
	// registry is config.LabsImageRegistry — see its doc comment. Empty
	// means Pod specs use the bare image name unchanged.
	registry string
}

// NewKubernetesContainerService returns a KubernetesContainerService using
// the Pod's own in-cluster service account credentials. namespace is where
// lab sandbox Pods are created — must match the Role/RoleBinding granting
// this service account pods (create/get/list/watch/delete) and pods/exec
// (create) in that namespace. profiles maps an environment image to the
// ImageProfile deciding its Pod config — see profile.go and docs/labs.md
// "Nested Docker labs". registry is config.LabsImageRegistry (may be empty).
func NewKubernetesContainerService(namespace string, profiles map[string]ImageProfile, registry string) (*KubernetesContainerService, error) {
	restConfig, err := loadRestConfig()
	if err != nil {
		return nil, fmt.Errorf("labs.NewKubernetesContainerService: %w", err)
	}
	clientset, err := kubernetes.NewForConfig(restConfig)
	if err != nil {
		return nil, fmt.Errorf("labs.NewKubernetesContainerService: build clientset: %w", err)
	}
	if profiles == nil {
		profiles = map[string]ImageProfile{}
	}
	return &KubernetesContainerService{
		clientset: clientset, restConfig: restConfig, namespace: namespace,
		profiles: profiles, registry: registry,
	}, nil
}

// loadRestConfig returns the in-cluster service account config when running
// as a Pod, falling back to the standard kubeconfig loading rules ($KUBECONFIG,
// then ~/.kube/config) when not — the same fallback kubectl itself uses. This
// lets the backend run natively (e.g. on the dev host, hot-reloading outside
// the cluster) against a real cluster's Kubernetes API, same as in prod,
// rather than a separate non-Kubernetes runtime standing in for it locally.
func loadRestConfig() (*rest.Config, error) {
	if cfg, err := rest.InClusterConfig(); err == nil {
		return cfg, nil
	}
	loadingRules := clientcmd.NewDefaultClientConfigLoadingRules()
	cfg, err := clientcmd.NewNonInteractiveDeferredLoadingClientConfig(loadingRules, &clientcmd.ConfigOverrides{}).ClientConfig()
	if err != nil {
		return nil, fmt.Errorf("no in-cluster config and no usable kubeconfig (checked $KUBECONFIG and ~/.kube/config): %w", err)
	}
	return cfg, nil
}

// Classify implements ContainerRuntime — see DockerContainerService.Classify
// for why this, and never the environment string's contents, is the
// security boundary.
func (k *KubernetesContainerService) Classify(image string) ImageProfile {
	return k.profiles[image]
}

// Start creates a Pod for the given lab session. See ContainerRuntime.Start —
// readiness waiting and lab setup are the caller's, not this method's.
func (k *KubernetesContainerService) Start(ctx context.Context, sessionID string, resetCount int, image string) (containerID, containerHost string, err error) {
	name := fmt.Sprintf("mindforge-lab-%s-%d", sessionID, resetCount)
	return k.startPod(ctx, name, map[string]string{"app": "mindforge-lab", "session-id": sessionID}, image)
}

// StartWarm creates an unbound warm-pool Pod. See ContainerRuntime.
func (k *KubernetesContainerService) StartWarm(ctx context.Context, warmID string, image string) (containerID, containerHost string, err error) {
	return k.startPod(ctx, WarmContainerNamePrefix+warmID, map[string]string{"app": "mindforge-lab-warm", "warm-id": warmID}, image)
}

// ExecSetup runs a lab's setup_script. Kubernetes Pod exec cannot override the
// container's user, so unlike Docker this is NOT privileged — see
// ContainerRuntime.ExecSetup and this type's own doc comment.
func (k *KubernetesContainerService) ExecSetup(ctx context.Context, containerID, script string, timeoutSec int) (stdout, stderr string, exitCode int, err error) {
	return k.execWithStdin(ctx, containerID, script, nil, timeoutSec)
}

// qualifyImage prepends the configured registry to a bare image name for the
// Pod spec. Must run AFTER Classify/profile lookup — profiles are keyed by
// the bare name from LABS_IMAGE_PROFILES, which never includes a registry.
func (k *KubernetesContainerService) qualifyImage(image string) string {
	if k.registry == "" {
		return image
	}
	return k.registry + "/" + image
}

func (k *KubernetesContainerService) startPod(ctx context.Context, name string, labels map[string]string, image string) (containerID, containerHost string, err error) {
	profile := k.Classify(image)
	// Any non-standard profile (Name != "") is, by definition, elevated —
	// the standard (zero-value) profile is the only one that ever runs
	// without a RuntimeClass. Kubernetes has no --cap-add escape hatch, so
	// an elevated profile with no configured RuntimeClass must hard-fail
	// rather than silently run unisolated on a shared node pool.
	if profile.Name != "" && profile.K8sRuntimeClass == "" {
		return "", "", fmt.Errorf("labs.KubernetesContainerService.Start: image %q uses profile %q which requires a Kubernetes RuntimeClassName but none is configured (LABS_NESTED_DOCKER_RUNTIME_CLASS unset?)", image, profile.Name)
	}

	cpuStr, memMB := ContainerCPU, ContainerMemoryMB
	if profile.CPU != "" {
		cpuStr = profile.CPU
	}
	if profile.MemoryMB != 0 {
		memMB = profile.MemoryMB
	}
	cpuQty, err := resource.ParseQuantity(cpuStr)
	if err != nil {
		return "", "", fmt.Errorf("labs.KubernetesContainerService.Start: parse cpu quantity: %w", err)
	}
	memQty, err := resource.ParseQuantity(fmt.Sprintf("%dMi", memMB))
	if err != nil {
		return "", "", fmt.Errorf("labs.KubernetesContainerService.Start: parse memory quantity: %w", err)
	}

	pod := &corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			Name:      name,
			Namespace: k.namespace,
			Labels:    labels,
		},
		Spec: corev1.PodSpec{
			RestartPolicy:                corev1.RestartPolicyNever,
			AutomountServiceAccountToken: boolPtr(false),
			Containers: []corev1.Container{{
				Name:  "sandbox",
				Image: k.qualifyImage(image),
				Resources: corev1.ResourceRequirements{
					Requests: corev1.ResourceList{
						corev1.ResourceCPU:    cpuQty,
						corev1.ResourceMemory: memQty,
					},
					Limits: corev1.ResourceList{
						corev1.ResourceCPU:    cpuQty,
						corev1.ResourceMemory: memQty,
					},
				},
				SecurityContext: &corev1.SecurityContext{
					Capabilities:             &corev1.Capabilities{Drop: []corev1.Capability{"ALL"}},
					AllowPrivilegeEscalation: boolPtr(false),
					SeccompProfile:           &corev1.SeccompProfile{Type: corev1.SeccompProfileTypeRuntimeDefault},
				},
			}},
		},
	}
	if profile.K8sRuntimeClass != "" {
		// The RuntimeClass (sysbox-runc/kata-containers) is the entire
		// isolation story here — SecurityContext stays exactly as it is for
		// every other lab. Do not attempt to reproduce the Docker runtime's
		// --cap-add flags on a shared node pool: SYS_ADMIN + unconfined
		// seccomp with no RuntimeClass sandbox is strictly worse than on the
		// single-host Docker deploy where it's at least the sole tenant of
		// the elevated network segment (see docs/labs.md).
		pod.Spec.RuntimeClassName = &profile.K8sRuntimeClass
		if profile.K8sRuntimeClass == "sysbox-runc" {
			// Sysbox virtualizes the container's root user via its own user
			// namespace; without hostUsers: false the kubelet still maps the
			// pod to the host's root UID before sysbox ever sees it, which
			// defeats that isolation (see docs.k3s.io "Sysbox Runtime With
			// K3s"). kata-containers has no such requirement.
			pod.Spec.HostUsers = boolPtr(false)
		}
	}
	if profile.K8sExtraVolume {
		diskGB := profile.K8sExtraVolumeSizeGB
		if diskGB == 0 {
			diskGB = NestedContainerDiskGB
		}
		diskQty, err := resource.ParseQuantity(fmt.Sprintf("%dGi", diskGB))
		if err != nil {
			return "", "", fmt.Errorf("labs.KubernetesContainerService.Start: parse disk quantity: %w", err)
		}
		// SizeLimit bounds the emptyDir itself; the container's own
		// ephemeral-storage limit makes the scheduler and kubelet eviction
		// both aware of the same budget (otherwise a full emptyDir just
		// triggers disk pressure on the node instead of a clean per-pod
		// limit). Without either, a student's `docker build`/image pulls
		// share the node's disk unbounded — see NestedContainerDiskGB.
		pod.Spec.Volumes = append(pod.Spec.Volumes, corev1.Volume{
			Name: "docker-lib",
			VolumeSource: corev1.VolumeSource{
				EmptyDir: &corev1.EmptyDirVolumeSource{SizeLimit: &diskQty},
			},
		})
		pod.Spec.Containers[0].VolumeMounts = append(pod.Spec.Containers[0].VolumeMounts, corev1.VolumeMount{
			Name: "docker-lib", MountPath: "/var/lib/docker",
		})
		pod.Spec.Containers[0].Resources.Requests[corev1.ResourceEphemeralStorage] = diskQty
		pod.Spec.Containers[0].Resources.Limits[corev1.ResourceEphemeralStorage] = diskQty
	}

	created, err := k.clientset.CoreV1().Pods(k.namespace).Create(ctx, pod, metav1.CreateOptions{})
	if err != nil {
		return "", "", fmt.Errorf("labs.KubernetesContainerService.Start: create pod: %w", err)
	}
	containerID = created.Name

	podIP, err := k.waitForRunning(ctx, containerID)
	if err != nil {
		_ = k.Kill(context.Background(), containerID)
		return "", "", fmt.Errorf("labs.KubernetesContainerService.Start: wait for running: %w", err)
	}

	containerHost = fmt.Sprintf("%s:7681", podIP)
	return containerID, containerHost, nil
}

// waitForRunning polls until the Pod reaches phase Running with an assigned
// IP, or ctx is done.
func (k *KubernetesContainerService) waitForRunning(ctx context.Context, podName string) (podIP string, err error) {
	ticker := time.NewTicker(podPollInterval)
	defer ticker.Stop()
	for {
		pod, getErr := k.clientset.CoreV1().Pods(k.namespace).Get(ctx, podName, metav1.GetOptions{})
		if getErr == nil && pod.Status.Phase == corev1.PodRunning && pod.Status.PodIP != "" {
			return pod.Status.PodIP, nil
		}
		if getErr == nil && pod.Status.Phase == corev1.PodFailed {
			return "", fmt.Errorf("pod %s failed to schedule: %s", podName, pod.Status.Reason)
		}
		select {
		case <-ctx.Done():
			return "", ctx.Err()
		case <-ticker.C:
		}
	}
}

// Kill force-deletes a Pod by name.
func (k *KubernetesContainerService) Kill(ctx context.Context, containerID string) error {
	gracePeriod := int64(0)
	err := k.clientset.CoreV1().Pods(k.namespace).Delete(ctx, containerID, metav1.DeleteOptions{
		GracePeriodSeconds: &gracePeriod,
	})
	if err != nil && !apierrors.IsNotFound(err) {
		return fmt.Errorf("labs.KubernetesContainerService.Kill: %w", err)
	}
	return nil
}

// Pause reports ErrPauseUnsupported: a Kubernetes Pod has no freezer-cgroup
// equivalent exposed through the API, and the alternatives (deleting the Pod,
// scaling to zero) all destroy exactly the container state pausing exists to
// preserve. lab.expire_sessions treats this as "leave it running" and lets
// IdleReapMinutes/expires_at close the session out instead — see
// ContainerRuntime.Pause.
func (k *KubernetesContainerService) Pause(ctx context.Context, containerID string) error {
	return ErrPauseUnsupported
}

// Unpause is a no-op: this runtime never pauses (see Pause above), so there
// is never anything to resume.
func (k *KubernetesContainerService) Unpause(ctx context.Context, containerID string) error {
	return nil
}

// Exec runs a script inside the Pod as its default (non-root) user. Output is
// bounded at MaxExecOutputBytes per stream (see boundedBuffer). exitCode is 0
// on success; a remote command exit error yields the real exit code without
// propagating an error value.
func (k *KubernetesContainerService) Exec(ctx context.Context, containerID, script string, timeoutSec int) (stdout, stderr string, exitCode int, err error) {
	return k.execWithStdin(ctx, containerID, script, nil, timeoutSec)
}

// ExecStdin is Exec plus a piped stdin payload — see ContainerRuntime's doc
// comment for why WriteFile uses this instead of embedding content in the
// script string.
func (k *KubernetesContainerService) ExecStdin(ctx context.Context, containerID, script string, stdin []byte, timeoutSec int) (stdout, stderr string, exitCode int, err error) {
	return k.execWithStdin(ctx, containerID, script, stdin, timeoutSec)
}

func (k *KubernetesContainerService) execWithStdin(ctx context.Context, containerID, script string, stdin []byte, timeoutSec int) (stdout, stderr string, exitCode int, err error) {
	escaped := strings.ReplaceAll(script, "'", "'\\''")
	cmd := fmt.Sprintf("timeout %d bash -c '%s'", timeoutSec, escaped)
	var stdinReader io.Reader
	if stdin != nil {
		stdinReader = bytes.NewReader(stdin)
	}
	return k.execPod(ctx, containerID, []string{"bash", "-c", cmd}, stdinReader)
}

// execPod runs command inside the named Pod's sole container via the
// Kubernetes exec subresource. stdin may be nil.
func (k *KubernetesContainerService) execPod(ctx context.Context, podName string, command []string, stdin io.Reader) (stdout, stderr string, exitCode int, err error) {
	req := k.clientset.CoreV1().RESTClient().Post().
		Resource("pods").
		Name(podName).
		Namespace(k.namespace).
		SubResource("exec").
		VersionedParams(&corev1.PodExecOptions{
			Container: "sandbox",
			Command:   command,
			Stdin:     stdin != nil,
			Stdout:    true,
			Stderr:    true,
		}, scheme.ParameterCodec)

	executor, err := remotecommand.NewSPDYExecutor(k.restConfig, "POST", req.URL())
	if err != nil {
		return "", "", -1, fmt.Errorf("labs.KubernetesContainerService.execPod: build executor: %w", err)
	}

	outBuf, errBuf := newBoundedBuffer(), newBoundedBuffer()
	streamErr := executor.StreamWithContext(ctx, remotecommand.StreamOptions{
		Stdin:  stdin,
		Stdout: outBuf,
		Stderr: errBuf,
	})
	stdout = outBuf.String()
	stderr = errBuf.String()
	if streamErr != nil {
		var codeErr utilexec.ExitError
		if errors.As(streamErr, &codeErr) {
			return stdout, stderr, codeErr.ExitStatus(), nil
		}
		return stdout, stderr, -1, fmt.Errorf("labs.KubernetesContainerService.execPod: %w", streamErr)
	}
	return stdout, stderr, 0, nil
}

// IsRunning reports whether the Pod is currently in phase Running.
func (k *KubernetesContainerService) IsRunning(ctx context.Context, containerID string) bool {
	pod, err := k.clientset.CoreV1().Pods(k.namespace).Get(ctx, containerID, metav1.GetOptions{})
	if err != nil {
		return false
	}
	return pod.Status.Phase == corev1.PodRunning
}

// List returns every Pod whose name starts with namePrefix, for
// LabCleanupHandler's orphan scan.
func (k *KubernetesContainerService) List(ctx context.Context, namePrefix string) ([]ContainerInfo, error) {
	pods, err := k.clientset.CoreV1().Pods(k.namespace).List(ctx, metav1.ListOptions{})
	if err != nil {
		return nil, fmt.Errorf("labs.KubernetesContainerService.List: %w", err)
	}
	var infos []ContainerInfo
	for _, pod := range pods.Items {
		if !strings.HasPrefix(pod.Name, namePrefix) {
			continue
		}
		infos = append(infos, ContainerInfo{
			ID:        pod.Name,
			Name:      pod.Name,
			CreatedAt: pod.CreationTimestamp.Time,
		})
	}
	return infos, nil
}

func boolPtr(b bool) *bool { return &b }
