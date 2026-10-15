package labs

import (
	"testing"

	"github.com/stretchr/testify/require"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
)

func TestPodResources(t *testing.T) {
	cpu, mem := resource.MustParse("1"), resource.MustParse("512Mi")

	r := podResources(cpu, mem, RequestPct{CPU: 25, Memory: 50})
	require.Equal(t, int64(250), r.Requests.Cpu().MilliValue())
	require.Equal(t, int64(256<<20), r.Requests.Memory().Value())
	require.Equal(t, int64(1000), r.Limits.Cpu().MilliValue(), "limits unchanged")
	require.Equal(t, int64(512<<20), r.Limits.Memory().Value())

	full := podResources(cpu, mem, FullRequests)
	for _, name := range []corev1.ResourceName{corev1.ResourceCPU, corev1.ResourceMemory} {
		req, lim := full.Requests[name], full.Limits[name]
		require.Zero(t, req.Cmp(lim), "session pods stay Guaranteed: %s", name)
	}
}
