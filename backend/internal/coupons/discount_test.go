package coupons

import "testing"

func TestDiscountCents(t *testing.T) {
	cases := []struct {
		name   string
		coupon Coupon
		amount int
		want   int
	}{
		{"percent floors", Coupon{DiscountType: DiscountTypePercent, DiscountValue: 33}, 999, 329},
		{"percent 100 zeroes out", Coupon{DiscountType: DiscountTypePercent, DiscountValue: 100}, 999, 999},
		{"fixed under price", Coupon{DiscountType: DiscountTypeFixed, DiscountValue: 200}, 999, 200},
		{"fixed exceeds price clamps", Coupon{DiscountType: DiscountTypeFixed, DiscountValue: 5000}, 999, 999},
		{"zero amount never negative", Coupon{DiscountType: DiscountTypeFixed, DiscountValue: 500}, 0, 0},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := DiscountCents(tc.coupon, tc.amount)
			if got != tc.want {
				t.Errorf("DiscountCents(%+v, %d) = %d, want %d", tc.coupon, tc.amount, got, tc.want)
			}
			if got < 0 || got > tc.amount {
				t.Errorf("DiscountCents(%+v, %d) = %d, out of bounds [0,%d]", tc.coupon, tc.amount, got, tc.amount)
			}
		})
	}
}
