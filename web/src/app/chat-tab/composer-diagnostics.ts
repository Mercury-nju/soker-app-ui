export const composerTraceEvents = ["mount", "pointerdown", "pointerup", "pointercancel", "touchstart", "touchend", "click", "focusin", "focusout", "scroll", "transitionend", "viewport-resize", "viewport-scroll", "resize-observer", "resize-before", "resize-after", "resize-reset", "react-state", "frame", "settled-80", "settled-300", "settled-700", "pagehide"] as const;
const targets = ["textarea", "gesture", "button", "other", "none"] as const;
const metricNames = ["inputScrollTop", "inputScrollHeight", "inputClientHeight", "inputHeight", "inputTop", "inputWidth", "inputInlineHeight", "inputFontSize", "inputLineHeight", "inputPaddingTop", "inputPaddingBottom", "inputMarginBottom", "placeholderFontSize", "placeholderLineHeight", "inputFocused", "focusWithin", "gestureFocused", "gestureHidden", "gestureTop", "gestureHeight", "boxTop", "boxHeight", "boxWidth", "viewportHeight", "viewportTop", "viewportScale", "windowHeight", "windowScrollY", "documentScrollTop", "reactFocused", "streaming", "hasText", "hasAttachments"] as const;
export type ComposerTraceEvent = typeof composerTraceEvents[number];
export type ComposerTraceEntry = { event: ComposerTraceEvent; target: typeof targets[number]; at: number; metrics: Record<string, number> };
export type ComposerTraceBatch = { runId: string; userAgent: string; entries: ComposerTraceEntry[] };

export function composerDiagnosticsEnabled(search: string) {
  return process.env.NODE_ENV === "development" && new URLSearchParams(search).get("composerDebug") === "1";
}

function object(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/** Only allow numeric geometry and fixed event labels across the logging boundary. */
export function sanitizeComposerBatch(value: unknown): ComposerTraceBatch | null {
  if (!object(value) || typeof value.runId !== "string" || !/^[a-zA-Z0-9-]{1,80}$/.test(value.runId) ||
      !Array.isArray(value.entries) || !value.entries.length || value.entries.length > 40) return null;
  const entries: ComposerTraceEntry[] = [];
  for (const row of value.entries) {
    if (!object(row) || !composerTraceEvents.includes(row.event as ComposerTraceEvent) ||
        !targets.includes(row.target as ComposerTraceEntry["target"]) || typeof row.at !== "number" ||
        !Number.isFinite(row.at) || row.at < 0 || !object(row.metrics)) return null;
    const metrics: Record<string, number> = {};
    for (const name of metricNames) {
      const number = row.metrics[name];
      if (number === undefined) continue;
      if (typeof number !== "number" || !Number.isFinite(number)) return null;
      metrics[name] = number;
    }
    entries.push({ event: row.event as ComposerTraceEvent, target: row.target as ComposerTraceEntry["target"], at: row.at, metrics });
  }
  return { runId: value.runId, userAgent: typeof value.userAgent === "string" ? value.userAgent.slice(0, 256) : "", entries };
}

export function startComposerDiagnostics(input: HTMLTextAreaElement) {
  const box = input.parentElement?.parentElement;
  if (!box) return null;
  // LAN HTTP WebViews do not expose crypto.randomUUID (secure contexts only).
  const runId = `trace-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
  const started = performance.now();
  const gesture = input.nextElementSibling as HTMLButtonElement | null;
  const pending: ComposerTraceEntry[] = [];
  const removers: Array<() => void> = [];
  const timers = new Set<ReturnType<typeof setTimeout>>();
  let frame: number | null = null;
  let flushTimer: ReturnType<typeof setTimeout> | null = null;
  let count = 0;
  let disposed = false;
  let state = { reactFocused: 0, streaming: 0, hasText: 0, hasAttachments: 0 };
  const targetName = (target: EventTarget | null): ComposerTraceEntry["target"] =>
    target === input ? "textarea" : target === gesture ? "gesture" : target instanceof HTMLButtonElement ? "button" : target ? "other" : "none";
  const flush = () => {
    if (flushTimer) clearTimeout(flushTimer);
    flushTimer = null;
    while (pending.length) {
      const batch: ComposerTraceBatch = { runId, userAgent: navigator.userAgent, entries: pending.splice(0, 40) };
      void fetch("/api/dev-composer-diagnostics", {
        method: "POST", headers: { "content-type": "application/json" }, credentials: "omit",
        referrerPolicy: "no-referrer", body: JSON.stringify(batch), keepalive: true,
      }).then(response => { if (!response.ok) console.warn("[composer-debug] Trace upload failed", response.status); })
        .catch(() => console.warn("[composer-debug] Trace upload unavailable"));
    }
  };
  const capture = (event: ComposerTraceEvent, target: EventTarget | null = document.activeElement) => {
    if (disposed || count >= 500) return;
    count++;
    const rect = input.getBoundingClientRect();
    const boxRect = box.getBoundingClientRect();
    const gestureRect = gesture?.getBoundingClientRect();
    const css = getComputedStyle(input);
    const placeholder = getComputedStyle(input, "::placeholder");
    const visual = window.visualViewport;
    const metrics: Record<string, number> = {
      ...state, inputScrollTop: input.scrollTop, inputScrollHeight: input.scrollHeight, inputClientHeight: input.clientHeight,
      inputHeight: rect.height, inputTop: rect.top, inputWidth: rect.width,
      inputFocused: Number(document.activeElement === input), focusWithin: Number(box.matches(":focus-within")),
      gestureFocused: Number(document.activeElement === gesture), gestureHidden: Number(gesture?.hidden ?? true),
      boxTop: boxRect.top, boxHeight: boxRect.height, boxWidth: boxRect.width,
      windowHeight: window.innerHeight, windowScrollY: window.scrollY, documentScrollTop: document.documentElement.scrollTop,
    };
    const numeric = { inputInlineHeight: input.style.height, inputFontSize: css.fontSize, inputLineHeight: css.lineHeight,
      inputPaddingTop: css.paddingTop, inputPaddingBottom: css.paddingBottom, inputMarginBottom: css.marginBottom,
      placeholderFontSize: placeholder.fontSize, placeholderLineHeight: placeholder.lineHeight };
    for (const [key, value] of Object.entries(numeric)) { const n = parseFloat(value); if (Number.isFinite(n)) metrics[key] = n; }
    if (gestureRect) { metrics.gestureTop = gestureRect.top; metrics.gestureHeight = gestureRect.height; }
    if (visual) { metrics.viewportHeight = visual.height; metrics.viewportTop = visual.offsetTop; metrics.viewportScale = visual.scale; }
    pending.push({ event, target: targetName(target), at: Math.round((performance.now() - started) * 100) / 100, metrics });
    if (pending.length >= 40) flush();
    else if (!flushTimer) flushTimer = setTimeout(flush, 250);
  };
  const listen = (target: EventTarget, event: string, callback: EventListener) => {
    target.addEventListener(event, callback, { capture: true, passive: true });
    removers.push(() => target.removeEventListener(event, callback, true));
  };
  const settled = () => {
    if (frame !== null) cancelAnimationFrame(frame);
    for (const timer of timers) clearTimeout(timer);
    timers.clear();
    frame = requestAnimationFrame(() => { frame = null; capture("frame"); });
    for (const [delay, event] of [[80, "settled-80"], [300, "settled-300"], [700, "settled-700"]] as const) {
      const timer = setTimeout(() => { timers.delete(timer); capture(event); }, delay);
      timers.add(timer);
    }
  };
  for (const event of ["pointerdown", "pointerup", "pointercancel", "touchstart", "touchend", "click", "focusin", "focusout", "scroll", "transitionend"] as const) {
    listen(box, event, e => { capture(event, e.target); if (["pointerup", "touchend", "focusin", "focusout"].includes(event)) settled(); });
  }
  if (window.visualViewport) {
    listen(window.visualViewport, "resize", () => capture("viewport-resize"));
    listen(window.visualViewport, "scroll", () => capture("viewport-scroll"));
  }
  listen(window, "pagehide", () => { capture("pagehide"); flush(); });
  const observer = new ResizeObserver(() => capture("resize-observer"));
  observer.observe(input); observer.observe(box);
  const dispose = () => {
    if (disposed) return;
    disposed = true;
    removers.forEach(remove => remove()); observer.disconnect();
    if (frame !== null) cancelAnimationFrame(frame);
    timers.forEach(clearTimeout); clearTimeout(expiry); flush();
  };
  const expiry = setTimeout(dispose, 120_000);
  console.info("[composer-debug] Recording numeric layout trace for 120 seconds", { runId });
  capture("mount");
  return { capture, dispose, update: (next: typeof state) => { state = next; capture("react-state"); } };
}
