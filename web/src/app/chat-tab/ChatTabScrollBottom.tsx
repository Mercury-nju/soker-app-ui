"use client";

import { useSyncExternalStore } from "react";
import { getChatCopy } from "../chat/chat-ui-copy";
import type { createChatTabScrollState } from "./chat-tab-scroll";
import styles from "./chat-tab.module.scss";

export function ChatTabScrollBottom({ state, locale, onClick }: {
  state: ReturnType<typeof createChatTabScrollState>;
  locale: Parameters<typeof getChatCopy>[0];
  onClick: () => void;
}) {
  const detached = useSyncExternalStore(state.subscribe, state.getSnapshot, state.getServerSnapshot);
  if (!detached) return null;
  const label = getChatCopy(locale).scrollBottom;
  return <button className={styles.scrollBottom} type="button" aria-label={label} title={label} onClick={onClick}>
    <img src={"/chat/scroll-down.svg"} alt="" />
  </button>;
}
