"use client";

// The shelf — everything that isn't Now: today's plan, the inbox,
// the amnesty pile, and the weekly recap. Opens as a slide-over so the
// stage stays the main character.

import { useEffect, useState } from "react";
import { whatnowApi } from "@/lib/whatnow/client";
import type { PlanToday, Task, WeeklyRecap } from "@/lib/whatnow/types";

export function Shelf({
  onClose,
  onChanged,
}: {
  onClose: () => void;
  /** anything that could change what "Now" answers */
  onChanged: () => void;
}) {
  const [plan, setPlan] = useState<PlanToday | null>(null);
  const [inbox, setInbox] = useState<Task[]>([]);
  const [decayed, setDecayed] = useState<Task[]>([]);
  const [recap, setRecap] = useState<WeeklyRecap | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  async function loadAll() {
    const [p, i, d, r] = await Promise.all([
      whatnowApi.getPlanToday(),
      whatnowApi.getInbox(),
      whatnowApi.getDecayed(),
      whatnowApi.getWeeklyRecap(),
    ]);
    setPlan(p);
    setInbox(i);
    setDecayed(d);
    setRecap(r);
  }

  useEffect(() => {
    loadAll().catch(() => {});
  }, []);

  async function toggleToday(task: Task, add: boolean) {
    if (!plan || busyId) return;
    setBusyId(task.id);
    try {
      const ids = plan.tasks.map((t) => t.id).filter((id) => id !== task.id);
      if (add) ids.push(task.id);
      await whatnowApi.postPlanToday(ids);
      await loadAll();
      onChanged();
    } finally {
      setBusyId(null);
    }
  }

  async function move(task: Task, dir: -1 | 1) {
    if (!plan || busyId) return;
    const ids = plan.tasks.map((t) => t.id);
    const i = ids.indexOf(task.id);
    const j = i + dir;
    if (j < 0 || j >= ids.length) return;
    [ids[i], ids[j]] = [ids[j], ids[i]];
    setBusyId(task.id);
    try {
      await whatnowApi.postPlanToday(ids);
      await loadAll();
      onChanged();
    } finally {
      setBusyId(null);
    }
  }

  async function promote(task: Task) {
    if (busyId) return;
    setBusyId(task.id);
    try {
      await whatnowApi.patchTask(task.id, { pinned: true });
      onChanged();
    } finally {
      setBusyId(null);
    }
  }

  async function revive(task: Task) {
    if (busyId) return;
    setBusyId(task.id);
    try {
      await whatnowApi.reviveTask(task.id);
      await loadAll();
      onChanged();
    } finally {
      setBusyId(null);
    }
  }

  const planFull = !!plan && plan.tasks.length >= plan.cap;

  return (
    <div className="wn-shelf-backdrop" onClick={onClose}>
      <aside
        className="wn-shelf"
        role="dialog"
        aria-label="Task shelf"
        onClick={(e) => e.stopPropagation()}
      >
        <header className="wn-shelf-head">
          <h3 className="wn-shelf-title">The shelf</h3>
          <button className="wn-shelf-close" onClick={onClose} aria-label="Close shelf">✕</button>
        </header>

        {recap && <p className="wn-recap">{recap.summary}</p>}

        <section className="wn-shelf-section">
          <h4 className="wn-shelf-label">
            Today {plan ? `· ${plan.tasks.length}/${plan.cap}` : ""}
            {plan && plan.throughput < plan.cap ? (
              <span className="wn-shelf-hint"> you usually land {plan.throughput}</span>
            ) : null}
          </h4>
          {plan?.tasks.length ? (
            <ul className="wn-shelf-list">
              {plan.tasks.map((t, i) => (
                <li key={t.id} className="wn-shelf-item">
                  <span className="wn-shelf-item-title">{t.title}</span>
                  <span className="wn-shelf-item-actions">
                    <button
                      className="wn-shelf-action"
                      disabled={busyId === t.id || i === 0}
                      aria-label={`Move ${t.title} up`}
                      onClick={() => move(t, -1)}
                    >
                      ↑
                    </button>
                    <button
                      className="wn-shelf-action"
                      disabled={busyId === t.id || i === plan.tasks.length - 1}
                      aria-label={`Move ${t.title} down`}
                      onClick={() => move(t, 1)}
                    >
                      ↓
                    </button>
                    <button
                      className="wn-shelf-action"
                      disabled={busyId === t.id}
                      onClick={() => promote(t)}
                    >
                      do this now
                    </button>
                    <button
                      className="wn-shelf-action"
                      disabled={busyId === t.id}
                      onClick={() => toggleToday(t, false)}
                    >
                      drop
                    </button>
                  </span>
                </li>
              ))}
            </ul>
          ) : (
            <p className="wn-shelf-empty">No plan yet — promote something from the inbox.</p>
          )}
        </section>

        <section className="wn-shelf-section">
          <h4 className="wn-shelf-label">Inbox</h4>
          {inbox.length ? (
            <ul className="wn-shelf-list">
              {inbox.map((t) => (
                <li key={t.id} className="wn-shelf-item">
                  <span className="wn-shelf-item-title">
                    {t.title}
                    {t.status === "paused" && <span className="wn-shelf-paused"> · paused</span>}
                  </span>
                  <button
                    className="wn-shelf-action"
                    disabled={busyId === t.id || planFull}
                    title={planFull ? "Today is full — drop something first" : undefined}
                    onClick={() => toggleToday(t, true)}
                  >
                    today
                  </button>
                </li>
              ))}
            </ul>
          ) : (
            <p className="wn-shelf-empty">Empty. Suspiciously calm.</p>
          )}
        </section>

        {decayed.length > 0 && (
          <section className="wn-shelf-section">
            <h4 className="wn-shelf-label">Amnesty · faded quietly</h4>
            <ul className="wn-shelf-list">
              {decayed.map((t) => (
                <li key={t.id} className="wn-shelf-item wn-shelf-item-decayed">
                  <span className="wn-shelf-item-title">{t.title}</span>
                  <button
                    className="wn-shelf-action"
                    disabled={busyId === t.id}
                    onClick={() => revive(t)}
                  >
                    revive
                  </button>
                </li>
              ))}
            </ul>
          </section>
        )}
      </aside>
    </div>
  );
}
