package labs

import (
	"context"
	"errors"
	"testing"
	"time"

	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/client-go/kubernetes/fake"
	k8stesting "k8s.io/client-go/testing"
)

const testNS = "labs-test"

// fakeK8s returns a runtime over a fake clientset whose created Pods get
// status (on create, before the tracker stores them).
func fakeK8s(grace time.Duration, status corev1.PodStatus, existing ...runtime.Object) (*KubernetesContainerService, *fake.Clientset) {
	cs := fake.NewSimpleClientset(existing...)
	cs.PrependReactor("create", "pods", func(a k8stesting.Action) (bool, runtime.Object, error) {
		a.(k8stesting.CreateAction).GetObject().(*corev1.Pod).Status = status
		return false, nil, nil
	})
	return &KubernetesContainerService{clientset: cs, namespace: testNS, profiles: map[string]ImageProfile{}, unschedulableGrace: grace}, cs
}

// Regression: a validation Pod the scheduler cannot place (1-node cluster out
// of CPU) used to be waited on until the caller's whole deadline (15 min for a
// render), holding a worker slot. It must fail fast with ErrUnschedulable and
// the Pod must be deleted.
func TestStartValidationFailsFastWhenUnschedulable(t *testing.T) {
	k, cs := fakeK8s(time.Second, corev1.PodStatus{
		Phase: corev1.PodPending,
		Conditions: []corev1.PodCondition{{Type: corev1.PodScheduled, Status: corev1.ConditionFalse,
			Reason: corev1.PodReasonUnschedulable, Message: "0/1 nodes are available: 1 Insufficient cpu."}},
	})
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	start := time.Now()
	_, _, err := k.StartValidation(ctx, "build-abc", "lab-debug")
	if !errors.Is(err, ErrUnschedulable) {
		t.Fatalf("err = %v, want ErrUnschedulable", err)
	}
	if took := time.Since(start); took > 5*time.Second {
		t.Fatalf("took %s, want ~grace (1s)", took)
	}
	_, gerr := cs.CoreV1().Pods(testNS).Get(context.Background(), ValidationContainerNamePrefix+"build-abc", metav1.GetOptions{})
	if !apierrors.IsNotFound(gerr) {
		t.Fatalf("unschedulable pod not deleted: get err = %v", gerr)
	}
}

// Regression: a retry of a build whose earlier attempt left its Pod behind
// failed every time with AlreadyExists (Pod names are fixed per build). The
// stale Pod must be replaced.
func TestStartValidationReplacesStalePod(t *testing.T) {
	name := ValidationContainerNamePrefix + "build-abc"
	stale := &corev1.Pod{ObjectMeta: metav1.ObjectMeta{Name: name, Namespace: testNS, Labels: map[string]string{"stale": "yes"}}}
	k, cs := fakeK8s(time.Second, corev1.PodStatus{Phase: corev1.PodRunning, PodIP: "10.0.0.7"}, stale)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	id, host, err := k.StartValidation(ctx, "build-abc", "lab-debug")
	if err != nil {
		t.Fatalf("StartValidation: %v", err)
	}
	if id != name || host != "10.0.0.7:7681" {
		t.Fatalf("got (%s, %s)", id, host)
	}
	pod, err := cs.CoreV1().Pods(testNS).Get(context.Background(), name, metav1.GetOptions{})
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if pod.Labels["stale"] == "yes" {
		t.Fatal("the stale pod was kept instead of replaced")
	}
}

// Student/warm Pods (grace 0) keep waiting for their caller's ctx: an
// autoscaler may need minutes to add a node for them.
func TestStartWaitsOnUnschedulableWithoutGrace(t *testing.T) {
	k, _ := fakeK8s(0, corev1.PodStatus{
		Phase: corev1.PodPending,
		Conditions: []corev1.PodCondition{{Type: corev1.PodScheduled, Status: corev1.ConditionFalse,
			Reason: corev1.PodReasonUnschedulable}},
	})
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	_, _, err := k.Start(ctx, "sess", 0, "lab-debug")
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("err = %v, want the caller's deadline", err)
	}
}
