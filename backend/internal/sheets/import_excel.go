package sheets

import (
	"fmt"
	"io"
	"strings"

	"github.com/xuri/excelize/v2"
)

// ImportedItem is one row parsed from an uploaded sheet — the client merges
// these into its draft list before the sheet is actually created.
type ImportedItem struct {
	Title      string  `json:"title"`
	Category   *string `json:"category,omitempty"`
	Difficulty *string `json:"difficulty,omitempty"`
}

var validImportDifficulties = map[string]bool{"easy": true, "medium": true, "hard": true}

// titleHeaders and topicHeaders list the accepted header spellings
// (case-insensitive) for each column; the first match wins.
var titleHeaders = []string{"title", "question", "problem", "name"}
var topicHeaders = []string{"topic", "category"}

// ParseSheetExcel reads the first sheet of an uploaded .xlsx and returns one
// ImportedItem per non-blank row. Recognized headers: title/question/
// problem/name, topic/category, difficulty. Unrecognized columns are
// ignored. It does not persist anything.
func ParseSheetExcel(r io.Reader) ([]ImportedItem, error) {
	f, err := excelize.OpenReader(r)
	if err != nil {
		return nil, fmt.Errorf("sheets: open excel: %w", err)
	}
	defer f.Close()

	sheet := f.GetSheetName(0)
	if sheet == "" {
		return nil, fmt.Errorf("sheets: excel file has no sheets")
	}
	rows, err := f.GetRows(sheet)
	if err != nil {
		return nil, fmt.Errorf("sheets: read sheet: %w", err)
	}
	if len(rows) == 0 {
		return nil, fmt.Errorf("sheets: excel file is empty")
	}

	header := rows[0]
	colIndex := make(map[string]int, len(header))
	for i, h := range header {
		colIndex[strings.ToLower(strings.TrimSpace(h))] = i
	}

	findCol := func(names []string) (int, bool) {
		for _, name := range names {
			if idx, ok := colIndex[name]; ok {
				return idx, true
			}
		}
		return 0, false
	}
	titleIdx, hasTitle := findCol(titleHeaders)
	if !hasTitle {
		return nil, fmt.Errorf("sheets: no title/question column found")
	}
	topicIdx, hasTopic := findCol(topicHeaders)
	difficultyIdx, hasDifficulty := colIndex["difficulty"]

	cell := func(row []string, idx int) string {
		if idx >= len(row) {
			return ""
		}
		return strings.TrimSpace(row[idx])
	}

	out := make([]ImportedItem, 0, len(rows)-1)
	for _, row := range rows[1:] {
		if isBlankExcelRow(row) {
			continue
		}
		title := cell(row, titleIdx)
		if title == "" {
			continue
		}
		item := ImportedItem{Title: title}
		if hasTopic {
			if v := cell(row, topicIdx); v != "" {
				item.Category = &v
			}
		}
		if hasDifficulty {
			v := strings.ToLower(cell(row, difficultyIdx))
			if validImportDifficulties[v] {
				item.Difficulty = &v
			}
		}
		out = append(out, item)
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
