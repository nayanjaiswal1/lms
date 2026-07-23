package assessment

import "testing"

const pytestJUnitFixture = `<?xml version="1.0" encoding="utf-8"?>
<testsuites>
<testsuite name="pytest" tests="3" failures="1" errors="1">
<testcase classname="test_app" name="test_create_item" time="0.012"/>
<testcase classname="test_app" name="test_reject_bad_payload" time="0.004">
<failure message="assert 500 == 422">assert 500 == 422</failure>
</testcase>
<testcase classname="test_app" name="test_list_items" time="0.008">
<error message="ConnectionRefusedError">Traceback...</error>
</testcase>
</testsuite>
</testsuites>`

const vitestJUnitFixture = `<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="Counter.test.jsx" tests="1" failures="0">
<testcase classname="Counter" name="increments on click" time="0.021"/>
</testsuite>`

func TestParseJUnit_PytestMixedResults(t *testing.T) {
	expected := []TestCase{
		{ID: "test_create_item", Weight: 1},
		{ID: "test_reject_bad_payload", Weight: 1, Hidden: true},
		{ID: "test_list_items", Weight: 2},
	}
	res, err := parseJUnit(pytestJUnitFixture, expected)
	if err != nil {
		t.Fatal(err)
	}
	if res.TestsTotal != 3 || res.TestsPassed != 1 {
		t.Fatalf("want 1/3 passed, got %d/%d", res.TestsPassed, res.TestsTotal)
	}
	if res.Status != "failed" {
		t.Fatalf("want overall status failed, got %q", res.Status)
	}
	byID := make(map[string]CaseResult, len(res.Cases))
	for _, c := range res.Cases {
		byID[c.CaseID] = c
	}
	if !byID["test_create_item"].Passed {
		t.Fatal("test_create_item should pass (no failure/error child)")
	}
	if byID["test_reject_bad_payload"].Passed || byID["test_reject_bad_payload"].Status != "wrong_answer" {
		t.Fatalf("test_reject_bad_payload should be wrong_answer, got %+v", byID["test_reject_bad_payload"])
	}
	if !byID["test_reject_bad_payload"].Hidden {
		t.Fatal("Hidden must carry over from the expected TestCase")
	}
	if byID["test_list_items"].Passed || byID["test_list_items"].Status != "runtime_error" {
		t.Fatalf("test_list_items should be runtime_error, got %+v", byID["test_list_items"])
	}
	if byID["test_list_items"].Weight != 2 {
		t.Fatalf("Weight must carry over from the expected TestCase, got %v", byID["test_list_items"].Weight)
	}
}

func TestParseJUnit_VitestBareTestsuiteRoot(t *testing.T) {
	// vitest's junit reporter emits a bare <testsuite> root (no wrapping
	// <testsuites>) when there is only one suite — the parser must handle both.
	expected := []TestCase{{ID: "increments on click", Weight: 1}}
	res, err := parseJUnit(vitestJUnitFixture, expected)
	if err != nil {
		t.Fatal(err)
	}
	if res.TestsTotal != 1 || res.TestsPassed != 1 || res.Status != "passed" {
		t.Fatalf("want 1/1 passed, got %+v", res)
	}
}

func TestParseJUnit_MissingTestFailsClosed(t *testing.T) {
	// A test the question expects but the report never mentions (e.g. the
	// candidate's code crashed before pytest could even collect it) must be
	// recorded as failed, not silently dropped from scoring.
	expected := []TestCase{{ID: "test_never_ran", Weight: 1}}
	res, err := parseJUnit(`<testsuite name="x"></testsuite>`, expected)
	if err != nil {
		t.Fatal(err)
	}
	if res.TestsTotal != 1 || res.TestsPassed != 0 || res.Status != "failed" {
		t.Fatalf("want 0/1 failed, got %+v", res)
	}
	if len(res.Cases) != 1 || res.Cases[0].Passed {
		t.Fatalf("missing test must appear as a failed case, got %+v", res.Cases)
	}
}

func TestSandboxExecutor_UnavailableWhenRuntimeNil(t *testing.T) {
	exec := NewSandboxExecutor(nil)
	if exec.Available() {
		t.Fatal("sandbox executor with a nil runtime must report unavailable")
	}
}
