package labs

import (
	"context"
	"errors"
	"testing"
	"time"
)

func TestGradeInterruption(t *testing.T) {
	canceled, cancel := context.WithCancel(context.Background())
	cancel()
	expired, cancelExp := context.WithTimeout(context.Background(), time.Nanosecond)
	defer cancelExp()
	<-expired.Done()

	tests := []struct {
		name string
		ctx  context.Context
		want error
	}{
		{"live", context.Background(), nil},
		{"canceled", canceled, ErrGradeInterrupted},
		{"deadline", expired, ErrGradeTimeout},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if got := gradeInterruption(tc.ctx); !errors.Is(got, tc.want) {
				t.Fatalf("got %v, want %v", got, tc.want)
			}
		})
	}
}
