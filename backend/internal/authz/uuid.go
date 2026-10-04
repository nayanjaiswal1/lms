package authz

// isValidUUID reports whether s is the canonical 8-4-4-4-12 UUID form. It is
// the package's only UUID-format check: audit writes decide whether an entity
// id lands in the uuid target_id column or in a text fallback, and permission
// lookups reject non-uuid id lists before they reach the query — both must
// agree on what "a UUID" means.
func isValidUUID(s string) bool {
	if len(s) != 36 {
		return false
	}
	for i, c := range s {
		switch i {
		case 8, 13, 18, 23:
			if c != '-' {
				return false
			}
		default:
			if !((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')) {
				return false
			}
		}
	}
	return true
}
