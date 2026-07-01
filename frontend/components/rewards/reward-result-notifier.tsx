"use client";

import { useEffect, useRef } from "react";
import { showRewardToasts } from "@/components/rewards/reward-toast";
import type { AwardResult } from "@/lib/server/rewards";

interface RewardResultNotifierProps {
  result: AwardResult | null;
}

export function RewardResultNotifier({ result }: RewardResultNotifierProps) {
  const fired = useRef(false);

  useEffect(() => {
    if (fired.current || !result) return;
    if (!result.xp_gained && !result.new_level && !result.new_achievements?.length) return;
    fired.current = true;
    // Slight delay so the page renders first.
    const t = setTimeout(() => showRewardToasts(result), 600);
    return () => clearTimeout(t);
  }, [result]);

  return null;
}
