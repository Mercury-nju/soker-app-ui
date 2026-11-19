import { useState } from "react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import { getChatCopy } from "../chat/chat-ui-copy";
import styles from "./chat-tab.module.scss";

const primaryColor = "#7E58E9";

export const chatTabThemeStyle = {
  "--primary-color": primaryColor,
  ...Object.fromEntries([6, 9, 10, 12, 20, 90].map(alpha =>
    [`--primary-color-alpha-${alpha}`, `color-mix(in srgb, ${primaryColor} ${alpha}%, transparent)`],
  )),
};

export function Bubble({ text, locale, user = false, onOpenLink }: {
  text: string;
  locale: "zh" | "en";
  user?: boolean;
  onOpenLink: (url: string) => void;
}) {
  const [expanded, setExpanded] = useState(false);
  const copy = getChatCopy(locale);
  const long = text.length > 700 || text.split("\n").length > 16;
  return <article className={`${styles.bubble} ${user ? styles.user : ""}`}>
    {text ? <div className={`${long && !expanded ? styles.collapsed : ""} ${user ? styles.userText : ""}`}>
      {user ? text : <ReactMarkdown remarkPlugins={[[remarkGfm, { singleTilde: false }]]} components={{
        a: ({ href, children }) => href
          ? <a href={href} onClick={event => { event.preventDefault(); onOpenLink(href); }}>{children}</a>
          : children,
      }}>{text}</ReactMarkdown>}
    </div> : null}
    {long ? <button className={styles.expand} type="button" onClick={() => setExpanded(!expanded)}>
      {expanded ? copy.collapseMessage : copy.expandMessage}
    </button> : null}
  </article>;
}
