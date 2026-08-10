package labs

import "testing"

func TestParseListeningPorts(t *testing.T) {
	tests := []struct {
		name      string
		raw       string
		want      []int
		wantNames []string
	}{
		{
			name:      "sorted deduped with ttyd excluded",
			raw:       "8000\n3000\n7681\n3000\n",
			want:      []int{3000, 8000},
			wantNames: []string{"", ""},
		},
		{
			name:      "garbage lines skipped",
			raw:       "3000\nnot-a-port\n\n  \n70000\n-5\n0\n",
			want:      []int{3000},
			wantNames: []string{""},
		},
		{
			name:      "only ttyd listening",
			raw:       "7681\n",
			want:      []int{},
			wantNames: []string{},
		},
		{
			name:      "empty output",
			raw:       "",
			want:      []int{},
			wantNames: []string{},
		},
		{
			name:      "process name resolved via the port/inode/fd/comm columns",
			raw:       "8080\tnode\n5432\tpostgres\n",
			want:      []int{5432, 8080},
			wantNames: []string{"postgres", "node"},
		},
		{
			name:      "process name unresolved (empty second column) stays empty",
			raw:       "8080\t\n",
			want:      []int{8080},
			wantNames: []string{""},
		},
		{
			name:      "duplicate port lines prefer the resolved name",
			raw:       "8080\t\n8080\tnode\n",
			want:      []int{8080},
			wantNames: []string{"node"},
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
				if p.ProcessName != tt.wantNames[i] {
					t.Errorf("port[%d] name = %q, want %q", i, p.ProcessName, tt.wantNames[i])
				}
			}
		})
	}
}
