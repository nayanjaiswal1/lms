"use client";

// The answer to the only question: one primary task, two quiet alternatives.

import type { NowResponse, Task } from "@/lib/whatnow/types";

function Chips({ task }: { task: Task }) {
  if (!task.chips?.length) return null;
  return (
    <div className="wn-chips">
      {task.chips.map((c) => (
        <span key={c.id} className={`wn-chip wn-chip-${c.kind}`}>
          {c.label}
        </span>
      ))}
    </div>
  );
}

export function NowStage({
  now,
  loading,
  onStart,
}: {
  now: NowResponse | null;
  loading: boolean;
  onStart: (task: Task) => void;
}) {
  if (loading && !now) {
    return (
      <section className="wn-stage" aria-busy="true">
        <div className="wn-stage-empty">Finding the one thing…</div>
      </section>
    );
  }

  if (!now || !now.primary) {
    return (
      <section className="wn-stage">
        <div className="wn-stage-empty">
          <p className="wn-empty-line">Nothing on deck.</p>
          <p className="wn-empty-sub">Capture one thing below — that&rsquo;s enough.</p>
        </div>
      </section>
    );
  }

  const t = now.primary;
  return (
    <section className="wn-stage">
      <article className="wn-primary">
        {t.resumeNote && (
          <p className="wn-resume-note">
            <span className="wn-resume-mark">↩</span> {t.resumeNote}
          </p>
        )}
        <h2 className="wn-primary-title">{t.title}</h2>
        <Chips task={t} />
        <p className="wn-rationale">{now.rationale}</p>
        {t.trigger && <p className="wn-trigger">{t.trigger}</p>}
        <button className="wn-start" onClick={() => onStart(t)}>
          Start
          {t.durationMin ? <span className="wn-start-min"> · {t.durationMin}m</span> : null}
        </button>
      </article>

      {now.alternatives.length > 0 && (
        <div className="wn-alts">
          {now.alternatives.map((alt) => (
            <button key={alt.id} className="wn-alt" onClick={() => onStart(alt)}>
              <span className="wn-alt-or">or</span>
              <span className="wn-alt-title">{alt.title}</span>
              {alt.durationMin ? <span className="wn-alt-min">{alt.durationMin}m</span> : null}
            </button>
          ))}
        </div>
      )}
    </section>
  );
}
