"use client";

import { createContext, useContext, useEffect, type ReactNode } from "react";
import type { ChatToolLocale } from "./chat-tool-copy";
import { getChatCopy } from "./chat-ui-copy";

const ChatLocaleContext = createContext<ChatToolLocale>("zh");

export function ChatLocaleProvider({ locale, children }: { locale: ChatToolLocale; children?: ReactNode }) {
  useEffect(() => { document.documentElement.lang = locale === "zh" ? "zh-CN" : "en"; }, [locale]);
  return <ChatLocaleContext.Provider value={locale}>{children}</ChatLocaleContext.Provider>;
}

export function useChatLocale() { return useContext(ChatLocaleContext); }
export function useChatCopy() { return getChatCopy(useChatLocale()); }
