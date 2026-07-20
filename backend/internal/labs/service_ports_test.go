package labs

import "testing"

func TestParseListeningPorts(t *testing.T) {
	tests := []struct {
		name string
		raw  string
		want []int
	}{
		{
			name: "sorted deduped with ttyd excluded",
			raw:  "8000\n3000\n7681\n3000\n",
			want: []int{3000, 8000},
		},
		{
			name: "garbage lines skipped",
			raw:  "3000\nnot-a-port\n\n  \n70000\n-5\n0\n",
			want: []int{3000},
		},
		{
			name: "only ttyd listening",
			raw:  "7681\n",
			want: []int{},
		},
		{
			name: "empty output",
			raw:  "",
			want: []int{},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := parseListeningPorts(tt.raw)
			if len(got) != len(tt.want) {
				t.Fatalf("parseListeningPorts(%q) = %v, want ports %v", tt.raw, got, tt.want)
			}
			for i, p := range got {
				if p.Port != tt.want[i] {
					t.Errorf("port[%d] = %d, want %d", i, p.Port, tt.want[i])
				}
			}
		})
	}
}
