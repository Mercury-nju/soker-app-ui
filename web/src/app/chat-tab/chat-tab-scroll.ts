import { isScrolledToBottom, resolveConversationScrollTop } from "../chat/chat-keyboard";

export function createChatTabScrollState() {
  let detached = false;
  const listeners = new Set<() => void>();
  return {
    getSnapshot: () => detached,
    getServerSnapshot: () => false,
    subscribe: (listener: () => void) => { listeners.add(listener); return () => { listeners.delete(listener); }; },
    setDetached: (next: boolean) => {
      if (next === detached) return;
      detached = next;
      listeners.forEach(listener => listener());
    },
  };
}

export function createChatTabScrollController(host: HTMLDivElement, onDetached: (detached: boolean) => void) {
  let following = true;
  let disposed = false;
  let lastTop = host.scrollTop;
  let lastHeight = host.scrollHeight;
  let lastViewport = host.clientHeight;
  let userIntent = false;
  let touchY: number | undefined;
  let anchor: { id: string; contentTop: number } | undefined;
  let guidanceLayout: string | undefined;
  let publishedDetached: boolean | undefined;
  const publishDetached = () => {
    const detached = !following && host.scrollHeight > host.clientHeight;
    if (detached === publishedDetached) return;
    publishedDetached = detached;
    onDetached(detached);
  };
  const readGuidanceLayout = () => JSON.stringify(Array.from(host.querySelectorAll<HTMLElement>("[data-chat-tab-guidance]")).map((node) => {
    const rect = node.getBoundingClientRect();
    return [node.dataset.chatTabGuidance, rect.height, rect.width];
  }));
  const rows = () => Array.from(host.querySelectorAll<HTMLElement>("[data-chat-tab-item]"));
  const capture = () => {
    const bounds = host.getBoundingClientRect();
    const ordered = rows();
    let low = 0, high = ordered.length;
    let candidate: { id: string; top: number } | undefined;
    // Timeline rows are vertically ordered; avoid measuring every older message on touch/scroll.
    while (low < high) {
      const mid = Math.floor((low + high) / 2);
      const row = ordered[mid];
      const rect = row.getBoundingClientRect();
      if (rect.bottom <= bounds.top) low = mid + 1;
      else { high = mid; candidate = { id: row.dataset.chatTabItem!, top: rect.top }; }
    }
    anchor = candidate && candidate.top < bounds.bottom ? { id: candidate.id, contentTop: candidate.top - bounds.top + host.scrollTop } : undefined;
    lastTop = host.scrollTop;
    lastHeight = host.scrollHeight;
    lastViewport = host.clientHeight;
    guidanceLayout = readGuidanceLayout();
  };
  const sync = () => {
    if (disposed) return;
    // 推荐属于被动补充内容；新增或重排不能借正文的跟随状态推走阅读位置。
    // 主动发送或点击到底部仍通过 toBottom 显式恢复跟随。
    const nextGuidanceLayout = readGuidanceLayout();
    // 主动发送会同步移除上一轮建议；移除本身不取消刚刚恢复的正文跟随。
    if (guidanceLayout !== undefined && nextGuidanceLayout !== "[]" && nextGuidanceLayout !== guidanceLayout) following = false;
    // A layout sync may consume the final native movement before onScroll sees it.
    if (!following && host.scrollTop > lastTop && host.scrollHeight === lastHeight && host.clientHeight === lastViewport && nextGuidanceLayout === guidanceLayout) {
      following = isScrolledToBottom({ clientHeight: host.clientHeight, scrollHeight: host.scrollHeight, scrollTop: host.scrollTop, epsilon: 1 });
    }
    let top = host.scrollTop;
    if (!following && anchor) {
      const row = rows().find(row => row.dataset.chatTabItem === anchor!.id);
      if (row) {
        // Content coordinates isolate layout displacement from pending native scroll events.
        const contentTop = host.scrollTop + row.getBoundingClientRect().top - host.getBoundingClientRect().top;
        top += contentTop - anchor.contentTop;
      }
    }
    const nextTop = resolveConversationScrollTop({ clientHeight: host.clientHeight, scrollHeight: host.scrollHeight, scrollTop: top, pinToBottom: following });
    // Leave native momentum alone when no position correction is needed.
    if (Math.abs(host.scrollTop - nextTop) > 0.01) host.scrollTop = nextTop;
    userIntent = false;
    capture();
    publishDetached();
  };
  const detach = () => { following = false; capture(); publishDetached(); };
  const onScroll = () => {
    if (disposed) return;
    // Resize/clamping scroll events must not change the reader's follow mode.
    if (!userIntent && (host.scrollHeight !== lastHeight || host.clientHeight !== lastViewport)) { sync(); return; }
    userIntent = false;
    const delta = host.scrollTop - lastTop;
    if (delta === 0) return;
    // Only a downward return to the actual bottom restores follow mode.
    // The shared 48px threshold would snap near-bottom reading gestures back.
    following = delta > 0 && isScrolledToBottom({ clientHeight: host.clientHeight, scrollHeight: host.scrollHeight, scrollTop: host.scrollTop, epsilon: 1 });
    capture();
    publishDetached();
  };
  const intent = (direction: number) => {
    userIntent = direction < 0 ? host.scrollTop > 0 : direction > 0 && host.scrollTop + host.clientHeight < host.scrollHeight;
    if (direction < 0 && userIntent && following) detach();
  };
  const onWheel = (event: WheelEvent) => intent(event.deltaY);
  const onTouchStart = (event: TouchEvent) => { touchY = event.touches[0]?.clientY; };
  const onTouchMove = (event: TouchEvent) => {
    const next = event.touches[0]?.clientY;
    if (next !== undefined && touchY !== undefined) intent(touchY - next);
    touchY = next;
  };
  const onKeyDown = (event: KeyboardEvent) => {
    if ((event.target as HTMLElement)?.closest?.("input, textarea, select, button, [contenteditable=true]")) return;
    if (["ArrowUp", "PageUp", "Home"].includes(event.key) || event.key === " " && event.shiftKey) intent(-1);
    else if (["ArrowDown", "PageDown", "End", " "].includes(event.key)) intent(1);
  };
  host.addEventListener("scroll", onScroll, { passive: true });
  host.addEventListener("wheel", onWheel, { passive: true });
  host.addEventListener("touchstart", onTouchStart, { passive: true });
  host.addEventListener("touchmove", onTouchMove, { passive: true });
  host.addEventListener("keydown", onKeyDown);
  return {
    sync,
    toReply: (replyId: string) => {
      if (disposed) return false;
      // Compare attributes directly; URL values must not become CSS selectors.
      const row = Array.from(host.querySelectorAll<HTMLElement>("[data-reply-id]")).find(node => node.dataset.replyId === replyId);
      if (!row) return false;
      following = false;
      host.scrollTop += row.getBoundingClientRect().top - host.getBoundingClientRect().top;
      capture(); publishDetached();
      return true;
    },
    toBottom: () => { if (!disposed) { guidanceLayout = readGuidanceLayout(); following = true; userIntent = false; sync(); } },
    dispose: () => {
      disposed = true;
      host.removeEventListener("scroll", onScroll);
      host.removeEventListener("wheel", onWheel);
      host.removeEventListener("touchstart", onTouchStart);
      host.removeEventListener("touchmove", onTouchMove);
      host.removeEventListener("keydown", onKeyDown);
    },
  };
}
