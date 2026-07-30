"use client";

import { useSyncExternalStore } from "react";
import {
  CARD_FIELDS_DEFAULTS,
  getCardFieldsSettings,
  subscribeCardFieldsSettings,
  toggleCardField,
} from "@/lib/assessments/card-fields-settings";
import type { CardFieldsSettings } from "@/lib/assessments/card-fields-settings";

/** Live view of the persisted question-card field visibility; every consumer re-renders on change. */
export function useCardFieldsSettings(): {
  settings: CardFieldsSettings;
  toggle: typeof toggleCardField;
} {
  const settings = useSyncExternalStore(
    subscribeCardFieldsSettings,
    getCardFieldsSettings,
    () => CARD_FIELDS_DEFAULTS,
  );
  return { settings, toggle: toggleCardField };
}
