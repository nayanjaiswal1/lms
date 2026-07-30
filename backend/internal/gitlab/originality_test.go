package gitlab

import "testing"

// TestCompareSource_NearIdenticalScoresAboveThreshold verifies the core claim
// kind-herding-cookie.md's own Verification section requires: two
// near-identical text blobs (a copy-paste with cosmetic renames/reformats)
// score at or above originalityMatchThreshold. Pure unit test — zero DB,
// zero network, zero GitLab client.
func TestCompareSource_NearIdenticalScoresAboveThreshold(t *testing.T) {
	original := `package main

import "fmt"

func processOrders(orders []int) int {
	total := 0
	for _, amount := range orders {
		if amount < 0 {
			continue
		}
		total += amount
		if amount > 100 {
			total += 10
		}
	}
	return total
}

func summarize(total int) string {
	return fmt.Sprintf("order total: %d", total)
}

func average(nums []int) float64 {
	sum := 0
	for _, n := range nums {
		sum += n
	}
	if len(nums) == 0 {
		return 0
	}
	return float64(sum) / float64(len(nums))
}

func maxOf(nums []int) int {
	best := nums[0]
	for _, n := range nums {
		if n > best {
			best = n
		}
	}
	return best
}

func main() {
	orders := []int{50, 120, -5, 30, 200}
	total := processOrders(orders)
	fmt.Println(summarize(total))
	fmt.Println(average(orders))
	fmt.Println(maxOf(orders))
}
`
	// Copy-pasted with only the entry function's name changed at its
	// definition and call site — everything else (the loop body, the
	// summarize/average/maxOf functions, main's other lines) left
	// byte-for-byte identical, exactly the "minor rename" case the batch's
	// own verification section calls out: a student renaming just enough to
	// not look like a literal `cp` of the file.
	copied := `package main

import "fmt"

func handleOrders(orders []int) int {
	total := 0
	for _, amount := range orders {
		if amount < 0 {
			continue
		}
		total += amount
		if amount > 100 {
			total += 10
		}
	}
	return total
}

func summarize(total int) string {
	return fmt.Sprintf("order total: %d", total)
}

func average(nums []int) float64 {
	sum := 0
	for _, n := range nums {
		sum += n
	}
	if len(nums) == 0 {
		return 0
	}
	return float64(sum) / float64(len(nums))
}

func maxOf(nums []int) int {
	best := nums[0]
	for _, n := range nums {
		if n > best {
			best = n
		}
	}
	return best
}

func main() {
	orders := []int{50, 120, -5, 30, 200}
	total := handleOrders(orders)
	fmt.Println(summarize(total))
	fmt.Println(average(orders))
	fmt.Println(maxOf(orders))
}
`

	similarity, matched := CompareSource(original, copied)
	if similarity < originalityMatchThreshold {
		t.Fatalf("expected near-identical blobs to score >= %.2f, got %.4f (matched shingles: %d)", originalityMatchThreshold, similarity, matched)
	}
	if matched == 0 {
		t.Fatalf("expected at least one matched shingle between near-identical blobs")
	}
}

// TestCompareSource_UnrelatedScoresBelowThreshold verifies the other half of
// the same claim: two unrelated files score below the match threshold.
func TestCompareSource_UnrelatedScoresBelowThreshold(t *testing.T) {
	fileA := `package geometry

import "math"

func CircleArea(radius float64) float64 {
	return math.Pi * radius * radius
}

func CircleCircumference(radius float64) float64 {
	return 2 * math.Pi * radius
}
`
	fileB := `package inventory

type Item struct {
	SKU      string
	Quantity int
}

func (i Item) IsLowStock(threshold int) bool {
	return i.Quantity < threshold
}

func TotalValue(items []Item, unitPrice map[string]float64) float64 {
	total := 0.0
	for _, item := range items {
		total += unitPrice[item.SKU] * float64(item.Quantity)
	}
	return total
}
`

	similarity, _ := CompareSource(fileA, fileB)
	if similarity >= originalityMatchThreshold {
		t.Fatalf("expected unrelated blobs to score below %.2f, got %.4f", originalityMatchThreshold, similarity)
	}
}

// TestJaccardSimilarity_EmptySetsScoreZero guards the deliberate "empty is
// not similar" rule documented on JaccardSimilarity — two blank files must
// never register as a 100% match.
func TestJaccardSimilarity_EmptySetsScoreZero(t *testing.T) {
	similarity, _ := CompareSource("   \n\n  ", "\n\n\n")
	if similarity != 0 {
		t.Fatalf("expected two blank/whitespace-only blobs to score 0, got %.4f", similarity)
	}
}

// TestShingles_ShortFileProducesOneWindow verifies a file shorter than k
// lines still yields a comparable (non-empty) shingle set instead of
// silently contributing nothing.
func TestShingles_ShortFileProducesOneWindow(t *testing.T) {
	lines := NormalizeSourceLines("package main\nfunc main() {}\n")
	set := Shingles(lines, shingleK)
	if len(set) != 1 {
		t.Fatalf("expected exactly one shingle window for a short file, got %d", len(set))
	}
}
