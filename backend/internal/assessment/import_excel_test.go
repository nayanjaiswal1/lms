package assessment

import (
	"bytes"
	"context"
	"os"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/xuri/excelize/v2"
)

// testPool connects to TEST_DATABASE_URL for tests that exercise DB-backed
// status detection; skips (rather than fails) when unset, matching the
// convention in internal/jobs/e2e_test.go.
func testPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set")
	}
	pool, err := pgxpool.New(context.Background(), dsn)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	t.Cleanup(func() { pool.Close() })
	return pool
}

func buildTestXLSX(t *testing.T, header []string, dataRows [][]string) *bytes.Reader {
	t.Helper()
	f := excelize.NewFile()
	sheet := f.GetSheetName(0)
	for col, h := range header {
		cell, _ := excelize.CoordinatesToCellName(col+1, 1)
		if err := f.SetCellValue(sheet, cell, h); err != nil {
			t.Fatalf("set header: %v", err)
		}
	}
	for r, row := range dataRows {
		for col, v := range row {
			cell, _ := excelize.CoordinatesToCellName(col+1, r+2)
			if err := f.SetCellValue(sheet, cell, v); err != nil {
				t.Fatalf("set cell: %v", err)
			}
		}
	}
	var buf bytes.Buffer
	if err := f.Write(&buf); err != nil {
		t.Fatalf("write xlsx: %v", err)
	}
	return bytes.NewReader(buf.Bytes())
}

func TestParseStudentExcel_FixedAndOtherFields(t *testing.T) {
	header := []string{"Full Name", "Email", "Roll Number", "Phone Number", "Department", "Blood Group"}
	data := [][]string{
		{"Asha Rao", "asha@example.com", "R101", "9990001111", "CSE", "O+"},
	}
	r := buildTestXLSX(t, header, data)

	rows, err := ParseStudentExcel(r)
	if err != nil {
		t.Fatalf("ParseStudentExcel: %v", err)
	}
	if len(rows) != 1 {
		t.Fatalf("expected 1 row, got %d", len(rows))
	}
	row := rows[0]
	if row.FullName != "Asha Rao" || row.Email != "asha@example.com" || row.RollNumber != "R101" {
		t.Fatalf("unexpected fixed fields: %+v", row)
	}
	if row.OtherFields["Blood Group"] != "O+" {
		t.Fatalf("expected other_fields to capture Blood Group, got %+v", row.OtherFields)
	}
}

func TestParseStudentExcel_SkipsBlankRows(t *testing.T) {
	header := []string{"Full Name", "Email"}
	data := [][]string{
		{"Asha Rao", "asha@example.com"},
		{"", ""},
		{"Ravi Kumar", "ravi@example.com"},
	}
	r := buildTestXLSX(t, header, data)

	rows, err := ParseStudentExcel(r)
	if err != nil {
		t.Fatalf("ParseStudentExcel: %v", err)
	}
	if len(rows) != 2 {
		t.Fatalf("expected 2 non-blank rows, got %d", len(rows))
	}
}

func TestValidateAndStatusRows_RequiredFieldsAndDuplicates(t *testing.T) {
	pool := testPool(t)
	r := NewRepo(pool)
	ctx := context.Background()
	nilUUID := "00000000-0000-0000-0000-000000000000"

	rows := []MemberDetailRow{
		{FullName: "", Email: "missing-name@example.com"},
		{FullName: "Bad Email", Email: "not-an-email"},
	}
	out, err := r.ValidateAndStatusRows(ctx, nilUUID, nilUUID, rows)
	if err != nil {
		t.Fatalf("ValidateAndStatusRows: %v", err)
	}
	if out[0].Status != RowStatusInvalid || len(out[0].Errors) == 0 {
		t.Fatalf("expected missing-name row to be invalid, got %+v", out[0])
	}
	if out[1].Status != RowStatusInvalid || len(out[1].Errors) == 0 {
		t.Fatalf("expected bad-email row to be invalid, got %+v", out[1])
	}

	dupRows := []MemberDetailRow{
		{FullName: "Dup One", Email: "dup@example.com"},
		{FullName: "Dup Two", Email: "DUP@example.com"}, // case-insensitive duplicate
	}
	out, err = r.ValidateAndStatusRows(ctx, nilUUID, nilUUID, dupRows)
	if err != nil {
		t.Fatalf("ValidateAndStatusRows: %v", err)
	}
	if out[0].Status != RowStatusNew {
		t.Fatalf("expected first dup@example.com row to be new, got %+v", out[0])
	}
	if out[1].Status != RowStatusDuplicateInFile {
		t.Fatalf("expected second dup@example.com row to be duplicate_in_file, got %+v", out[1])
	}
}
