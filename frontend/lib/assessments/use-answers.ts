"use client";

import * as React from "react";
import type { StudentQuestion } from "@/lib/assessments/types";

export type MCQAnswer = { selected: string[] };
export type CodingAnswer = { language: string; code: string };
export type TranscriptAnswer = { transcript: string };
export type AnswerValue = MCQAnswer | CodingAnswer | TranscriptAnswer;

interface AnswersState {
  answers: Record<string, AnswerValue>;
  index: number;
  submitting: boolean;
}

type Action =
  | { kind: "toggleOption"; qid: string; optionId: string; multiple: boolean }
  | { kind: "setCode"; qid: string; code: string; language: string }
  | { kind: "setLanguage"; qid: string; language: string; starter: string }
  | { kind: "setTranscript"; qid: string; transcript: string }
  | { kind: "clearAnswer"; qid: string }
  | { kind: "goto"; index: number }
  | { kind: "submitting"; value: boolean };

function reducer(state: AnswersState, action: Action): AnswersState {
  switch (action.kind) {
    case "toggleOption": {
      const current = (state.answers[action.qid] as MCQAnswer | undefined)?.selected ?? [];
      let selected: string[];
      if (action.multiple) {
        selected = current.includes(action.optionId)
          ? current.filter((id) => id !== action.optionId)
          : [...current, action.optionId];
      } else {
        selected = [action.optionId];
      }
      return { ...state, answers: { ...state.answers, [action.qid]: { selected } } };
    }
    case "setCode": {
      const prev = state.answers[action.qid] as CodingAnswer | undefined;
      return {
        ...state,
        answers: {
          ...state.answers,
          [action.qid]: { language: prev?.language ?? action.language, code: action.code },
        },
      };
    }
    case "setLanguage": {
      const prev = state.answers[action.qid] as CodingAnswer | undefined;
      return {
        ...state,
        answers: {
          ...state.answers,
          [action.qid]: { language: action.language, code: prev?.code || action.starter },
        },
      };
    }
    case "setTranscript":
      return {
        ...state,
        answers: { ...state.answers, [action.qid]: { transcript: action.transcript } },
      };
    case "clearAnswer": {
      const rest = { ...state.answers };
      delete rest[action.qid];
      return { ...state, answers: rest };
    }
    case "goto":
      return { ...state, index: action.index };
    case "submitting":
      return { ...state, submitting: action.value };
  }
}

// useAnswers holds all in-attempt answer state and navigation in a reducer, so
// the runner component stays within the project's 2-useState limit.
export function useAnswers(questions: StudentQuestion[]) {
  const [state, dispatch] = React.useReducer(reducer, { answers: {}, index: 0, submitting: false });

  const answeredCount = React.useMemo(
    () =>
      questions.filter((q) => {
        const a = state.answers[q.assessment_question_id];
        if (!a) return false;
        if ("selected" in a) return a.selected.length > 0;
        if ("transcript" in a) return a.transcript.trim().length > 0;
        return a.code.trim().length > 0;
      }).length,
    [questions, state.answers],
  );

  return { state, dispatch, answeredCount };
}
