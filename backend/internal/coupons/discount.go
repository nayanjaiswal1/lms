package coupons

// DiscountCents computes how much a coupon takes off amountCents. This is
// the only place discount math happens — never trust a client-sent discount
// amount; callers always pass the server's own price and recompute here,
// both at checkout-time preview and again at webhook confirmation.
func DiscountCents(c Coupon, amountCents int) int {
	if amountCents <= 0 {
		return 0
	}

	var discount int
	switch c.DiscountType {
	case DiscountTypePercent:
		// Floors in the customer's favor — a coupon never rounds up against
		// them, and this keeps a 100%-off coupon exactly zero, not off by a
		// cent from any rounding direction.
		discount = amountCents * c.DiscountValue / 100
	case DiscountTypeFixed:
		discount = c.DiscountValue
	}

	if discount < 0 {
		return 0
	}
	if discount > amountCents {
		discount = amountCents
	}
	// Caps the absolute discount a percent-off coupon can give — "30% off"
	// on an expensive course can otherwise discount far more than intended.
	// A no-op for a fixed-amount coupon: its DiscountValue already IS the
	// cap, so MaxDiscountCents (if set on one anyway) never binds tighter.
	if c.MaxDiscountCents != nil && discount > *c.MaxDiscountCents {
		discount = *c.MaxDiscountCents
	}
	return discount
}
