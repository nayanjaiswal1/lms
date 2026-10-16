package labs

import (
	"testing"

	corev1 "k8s.io/api/core/v1"
)

func TestPullPolicy(t *testing.T) {
	if got := (&KubernetesContainerService{registry: "localhost:5000"}).pullPolicy(); got != corev1.PullAlways {
		t.Fatalf("registry-backed image: policy = %q, want Always", got)
	}
	if got := (&KubernetesContainerService{}).pullPolicy(); got != "" {
		t.Fatalf("no registry: policy = %q, want the Kubernetes default", got)
	}
}
