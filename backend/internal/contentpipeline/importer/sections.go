package importer

// courseSlug is the fixed course slug for every document this importer
// produces. This package only ever imports the fast-kubernetes course.
const courseSlug = "fast-kubernetes"

// LabMeta pairs an upstream labs/<Dir> subdirectory name (in the vendored
// content/fast-kubernetes/labs/ tree) with the human-readable title used in
// the generated lab stub's title and id_key.
type LabMeta struct {
	Dir   string // labs/<Dir> subdirectory name in the vendored snapshot
	Title string // human-readable title, e.g. "Deployment" for Dir "deployment"
}

// Section describes one course section's upstream-to-canonical mapping:
// which upstream lesson markdown files merge into the section's single
// lesson.md, and which labs/* subdirectories become lab stubs for it.
//
// This table is a hardcoded, one-off mapping specific to the fast-kubernetes
// course's upstream repository layout — it is intentionally not a general
// content-import mechanism.
type Section struct {
	Slug     string // section slug, e.g. "workloads"
	Title    string // section_title in canonical frontmatter
	Position int    // section_position in canonical frontmatter

	// LessonSources lists upstream root-level lesson markdown filenames (in
	// content/fast-kubernetes/) whose full content is concatenated, in
	// order, into this section's single lesson.md body. When more than one
	// file is listed, each is preceded by a "## <filename>" heading so the
	// merge point is legible; a single source file is included as-is.
	LessonSources []string

	// SourceOnly lists upstream filenames that belong to this section for
	// coverage-tracking purposes only: the filename is recorded in the
	// generated lesson's source: list but its content is NOT concatenated
	// into the body. Used for README.md, which is the upstream repo's own
	// table-of-contents/overview — redundant with the section structure
	// this importer already builds, but still owed a coverage citation.
	SourceOnly []string

	// IncludeClusterScripts, when true, appends every file under
	// create_real_cluster/** to this section's lesson body as fenced,
	// read-only reference code blocks, and lists each one in source:. Used
	// only by cluster-ops — kubeadm cluster provisioning is out of scope
	// for the single-container lab sandbox, so this content is reference
	// material rather than a graded lab.
	IncludeClusterScripts bool

	// Labs lists the labs/<dir> subdirectories that become one lab stub
	// each for this section, in position order. Empty means this section
	// is notes-only (no interactive lab).
	Labs []LabMeta
}

// Sections is the hardcoded course/section grouping table for the
// fast-kubernetes course, derived from the approved content-pipeline plan
// (section B) and the importer workstream brief. Order matters: it
// determines section_position and the order sections are emitted in.
var Sections = []Section{
	{
		Slug: "pod-fundamentals", Title: "Pod Fundamentals", Position: 1,
		LessonSources: []string{
			"K8s-CreatingPod-Imperative.md",
			"K8-CreatingPod-Declerative.md",
			"K8s-Multicontainer-Sidecar.md",
		},
		Labs: []LabMeta{
			{Dir: "pod", Title: "Pod"},
		},
	},
	{
		Slug: "workloads", Title: "Workloads & Controllers", Position: 2,
		LessonSources: []string{
			"K8s-Deployment.md",
			"K8s-Rollout-Rollback.md",
			"K8s-Daemon-Sets.md",
			"K8s-Statefulset.md",
			"K8s-Job.md",
			"K8s-CronJob.md",
		},
		Labs: []LabMeta{
			{Dir: "deployment", Title: "Deployment"},
			{Dir: "daemonset", Title: "DaemonSet"},
			{Dir: "statefulset", Title: "StatefulSet"},
			{Dir: "job", Title: "Job"},
			{Dir: "cronjob", Title: "CronJob"},
		},
	},
	{
		Slug: "networking", Title: "Networking", Position: 3,
		LessonSources: []string{
			"K8s-Service-App.md",
			"K8s-Ingress.md",
		},
		Labs: []LabMeta{
			{Dir: "service", Title: "Service"},
			{Dir: "ingress", Title: "Ingress"},
		},
	},
	{
		Slug: "config-secrets", Title: "Configuration & Secrets", Position: 4,
		LessonSources: []string{
			"K8s-Configmap.md",
			"K8s-Secret.md",
		},
		Labs: []LabMeta{
			{Dir: "configmap", Title: "ConfigMap"},
			{Dir: "secret", Title: "Secret"},
		},
	},
	{
		Slug: "storage", Title: "Storage", Position: 5,
		LessonSources: []string{
			"K8s-PersistantVolume.md",
		},
		Labs: []LabMeta{
			{Dir: "persistentvolume", Title: "Persistent Volume"},
		},
	},
	{
		Slug: "scheduling", Title: "Health & Scheduling", Position: 6,
		LessonSources: []string{
			"K8s-Liveness-App.md",
			"K8s-Node-Affinity.md",
			"K8s-Taint-Toleration.md",
		},
		Labs: []LabMeta{
			{Dir: "liveness", Title: "Liveness Probe"},
			{Dir: "affinity", Title: "Node Affinity"},
			{Dir: "tainttoleration", Title: "Taint & Toleration"},
		},
	},
	{
		Slug: "cluster-ops", Title: "Cluster Setup & Operations", Position: 7,
		LessonSources: []string{
			"K8s-Kubeadm-Cluster-Setup.md",
			"K8s-Kubeadm-Cluster-Docker.md",
			"K8s-Enable-Dashboard-On-Cluster.md",
		},
		IncludeClusterScripts: true,
		// No labs: kubeadm needs real multi-VM bare metal, which the
		// single-container lab sandbox cannot provide.
	},
	{
		Slug: "helm", Title: "Helm & Packaging", Position: 8,
		LessonSources: []string{
			"Helm.md",
			"HelmCheatsheet.md",
			"K8s-Helm-Jenkins.md",
		},
		// No labs: Helm/Jenkins binaries aren't in the lab-k8s image.
	},
	{
		Slug: "observability", Title: "Observability", Position: 9,
		LessonSources: []string{
			"K8s-Monitoring-Prometheus-Grafana.md",
		},
		// No labs: Prometheus/Grafana aren't in the lab-k8s image.
	},
	{
		Slug: "reference", Title: "Reference", Position: 10,
		LessonSources: []string{
			"KubernetesCommandCheatSheet.md",
		},
		// README.md is the upstream repo's own TOC/overview — not imported
		// as standalone content (redundant with the section structure
		// above), but still cited here for 100%-coverage bookkeeping.
		SourceOnly: []string{"README.md"},
		// No labs: a command cheat sheet has no graded exercise.
	},
}
