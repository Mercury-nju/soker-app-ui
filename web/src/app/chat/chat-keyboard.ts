export const SCROLLABLE_EPSILON = 48;

export function scheduleAttachmentSheetAfterKeyboardDismiss(open: () => void) {
  const viewport = window.visualViewport ?? window;
  const keyboard = (window.navigator as Navigator & {
    virtualKeyboard?: EventTarget & { boundingRect: { height: number } };
  })?.virtualKeyboard;
  let settledTimer: ReturnType<typeof setTimeout> | null = null;
  let cancelled = false;

  function cancel() {
    cancelled = true;
    viewport.removeEventListener("resize", onResize);
    keyboard?.removeEventListener("geometrychange", onResize);
    if (settledTimer) clearTimeout(settledTimer);
    clearTimeout(fallbackTimer);
  }

  function finish(force = false) {
    if (cancelled) return;
    if (!force && keyboard?.boundingRect.height) return;
    if (!force && window.visualViewport && Number.isFinite(window.innerHeight)
      && window.innerHeight - window.visualViewport.height - window.visualViewport.offsetTop > 80) return;
    cancel();
    open();
  }

  function onResize() {
    if (settledTimer) clearTimeout(settledTimer);
    settledTimer = setTimeout(finish, 180);
  }

  viewport.addEventListener("resize", onResize);
  keyboard?.addEventListener("geometrychange", onResize);
  const fallbackTimer = setTimeout(() => finish(true), 900);
  return cancel;
}

export function isScrolledToBottom({
  clientHeight,
  scrollHeight,
  scrollTop,
  epsilon = SCROLLABLE_EPSILON,
}: {
  clientHeight: number;
  scrollHeight: number;
  scrollTop: number;
  epsilon?: number;
}) {
  return scrollTop + clientHeight >= scrollHeight - epsilon;
}

export function resolveConversationScrollTop({
  clientHeight,
  scrollHeight,
  scrollTop,
  pinToBottom,
}: {
  clientHeight: number;
  scrollHeight: number;
  scrollTop: number;
  pinToBottom: boolean;
}) {
  const maxScrollTop = Math.max(0, scrollHeight - clientHeight);
  if (pinToBottom) {
    return maxScrollTop;
  }

  return Math.min(Math.max(0, scrollTop), maxScrollTop);
}

export function resolveChatViewportLayout({
  visualViewportHeight,
  visualViewportOffsetTop,
  overlayKeyboardHeight = 0,
}: {
  visualViewportHeight: number;
  visualViewportOffsetTop: number;
  overlayKeyboardHeight?: number;
}) {
  return {
    offsetTop: Math.max(0, visualViewportOffsetTop),
    height: Math.max(0, visualViewportHeight),
    overlayInset: Math.max(0, overlayKeyboardHeight),
  };
}
