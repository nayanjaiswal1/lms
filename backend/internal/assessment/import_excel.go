package assessment

import (
	"fmt"
	"io"
	"strings"

	"github.com/xuri/excelize/v2"
)

// fixedImportHeaders are the recognized column headers (case-insensitive);
// any other header becomes an other_fields key on MemberDetailRow.
var fixedImportHeaders = map[string]bool{
	"full name":    true,
	"email":        true,
	"roll number":  true,
	"phone number": true,
	"department":   true,
}

// ParseStudentExcel reads the first sheet of an uploaded roster and returns
// one MemberDetailRow per non-blank data row. It does not validate or
// classify rows — see Repo.ValidateAndStatusRows for that.
func ParseStudentExcel(r io.Reader) ([]MemberDetailRow, error) {
	f, err := excelize.OpenReader(r)
	if err != nil {
		return nil, fmt.Errorf("assessment: open excel: %w", err)
	}
	defer f.Close()

	sheet := f.GetSheetName(0)
	if sheet == "" {
		return nil, fmt.Errorf("assessment: excel file has no sheets")
	}
	rows, err := f.GetRows(sheet)
	if err != nil {
		return nil, fmt.Errorf("assessment: read sheet: %w", err)
	}
	if len(rows) == 0 {
		return nil, fmt.Errorf("assessment: excel file is empty")
	}

	header := rows[0]
	colIndex := make(map[string]int, len(header))
	for i, h := range header {
		colIndex[strings.ToLower(strings.TrimSpace(h))] = i
	}

	get := func(row []string, key string) string {
		idx, ok := colIndex[key]
		if !ok || idx >= len(row) {
			return ""
		}
		return strings.TrimSpace(row[idx])
	}

	out := make([]MemberDetailRow, 0, len(rows)-1)
	for _, row := range rows[1:] {
		if isBlankExcelRow(row) {
			continue
		}
		m := MemberDetailRow{
			FullName:    get(row, "full name"),
			Email:       strings.ToLower(get(row, "email")),
			RollNumber:  get(row, "roll number"),
			PhoneNumber: get(row, "phone number"),
			Department:  get(row, "department"),
			OtherFields: map[string]string{},
		}
		for h, idx := range colIndex {
			if fixedImportHeaders[h] || idx >= len(row) {
				continue
			}
			if v := strings.TrimSpace(row[idx]); v != "" {
				m.OtherFields[header[idx]] = v
			}
		}
		out = append(out, m)
	}
	return out, nil
}

func isBlankExcelRow(row []string) bool {
	for _, c := range row {
		if strings.TrimSpace(c) != "" {
			return false
		}
	}
	return true
}
