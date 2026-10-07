package rewards

import "testing"

func TestAnonymiseGlobal_HidesEveryoneButCaller(t *testing.T) {
	avatar := "https://x/a.png"
	got := anonymiseGlobal([]LeaderboardEntry{
		{Rank: 1, UserID: "other", Name: "Other Person", AvatarURL: &avatar, TotalXP: 90},
		{Rank: 2, UserID: "me", Name: "Me", AvatarURL: &avatar, TotalXP: 80},
	}, "me")

	if got[0].UserID != "anon-1" || got[0].Name != "Learner" || got[0].AvatarURL != nil || got[0].TotalXP != 90 {
		t.Fatalf("other entry not anonymised: %+v", got[0])
	}
	if got[1].UserID != "me" || got[1].Name != "Me" || got[1].AvatarURL == nil {
		t.Fatalf("caller entry must stay intact: %+v", got[1])
	}
}
