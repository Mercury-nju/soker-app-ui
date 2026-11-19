"use client";

import { useCallback, useLayoutEffect, useRef, useState, type RefObject } from "react";
import { createChatTabScrollController, createChatTabScrollState } from "./chat-tab-scroll";

export function useChatTabScroll(owner: string, scroller: RefObject<HTMLDivElement | null>) {
  const content = useRef<HTMLDivElement>(null);
  const controller = useRef<ReturnType<typeof createChatTabScrollController> | null>(null);
  const [state] = useState(createChatTabScrollState);

  useLayoutEffect(() => {
    const host = scroller.current;
    if (!host) return;
    const current = createChatTabScrollController(host, state.setDetached);
    controller.current = current;
    current.sync();
    const observer = typeof ResizeObserver === "undefined" ? null : new ResizeObserver(() => current.sync());
    observer?.observe(host);
    if (content.current) observer?.observe(content.current);
    return () => {
      observer?.disconnect();
      current.dispose();
      if (controller.current === current) controller.current = null;
    };
  }, [owner, scroller, state]);

  // React commits cover stream updates; the observer covers images, expansion and keyboard layout.
  useLayoutEffect(() => { controller.current?.sync(); });
  const toBottom = useCallback(() => controller.current?.toBottom(), []);
  const toReply = useCallback((replyId: string) => controller.current?.toReply(replyId) ?? false, []);
  return { content, state, toBottom, toReply };
}
