"use client";

import { useEffect, useRef, useState, type ReactNode, type RefObject } from "react";
import { useChatCopy } from "../chat/chat-locale";
import { ComposerAttachments } from "../chat/components/ComposerAttachments";
import type { LocalAttachment } from "../chat/types";
import styles from "./ChatTabComposer.module.scss";
import { composerDiagnosticsEnabled, startComposerDiagnostics } from "./composer-diagnostics";

export type ChatTabComposerProps = {
  inputRef: RefObject<HTMLTextAreaElement | null>;
  value: string;
  attachments: LocalAttachment[];
  hasReferences: boolean;
  referencePreview?: ReactNode;
  canSend: boolean;
  disabled: boolean;
  streaming: boolean;
  stopping: boolean;
  syncing?: boolean;
  voiceDisabled?: boolean;
  voice?: {
    busy: boolean;
    dictationPhase: "idle" | "listening" | "partial" | "stopping";
    press: () => void;
    cancel: (cancelled: boolean) => void;
  };
  onChange: (value: string) => void;
  onRemoveAttachment: (id: string) => void;
  onOpenAttachments: () => void;
  onSend: () => void;
  onStop: () => void;
  onVoice: () => void;
  onPreparationBlocked?: () => void;
  acquisition?: { voiceEnabled: boolean; attachmentsEnabled?: boolean; placeholder?: string };
};

function resizeComposerInput(input: HTMLTextAreaElement | null) {
  if (!input) return;
  input.style.height = "auto";
  input.style.height = `${Math.min(Math.max(input.scrollHeight, 28), 84)}px`;
}

// Copied from the legacy Chat composer; v2 business state stays in ChatTabClient.
export function ChatTabComposer(props: ChatTabComposerProps) {
  const copy = useChatCopy();
  const [focused, setFocused] = useState(false);
  const pressTarget = useRef<HTMLButtonElement>(null);
  const touchTimes = useRef<Record<string, number>>({});
  const touchTap = useRef(false);
  const diagnostic = useRef<ReturnType<typeof startComposerDiagnostics>>(null);
  const { inputRef, value } = props;
  const dictating = Boolean(props.voice && props.voice.dictationPhase !== "idle");
  const listening = props.voice?.dictationPhase === "listening" || props.voice?.dictationPhase === "partial";
  const syncing = Boolean(props.syncing && !props.streaming);
  const placeholder = props.acquisition ? (props.acquisition.placeholder ?? "描述你想找的客户") : copy.composerPlaceholder;
  const statusMode = props.streaming || syncing;
  const attachmentsLocked = props.disabled || statusMode || Boolean(props.voice?.busy);
  const sendEnabled = !props.disabled && !statusMode && !props.voice?.busy && props.canSend && Boolean(value.trim() || props.attachments.length || props.hasReferences);
  const explainPreparation = Boolean(props.onPreparationBlocked && !props.disabled && !statusMode && !props.voice?.busy && !dictating);
  const explainSend = explainPreparation && !props.canSend && Boolean(value.trim() || props.attachments.length || props.hasReferences);
  const explainVoice = explainPreparation && Boolean(props.voiceDisabled);
  const focus = () => {
    inputRef.current?.focus({ preventScroll: true });
    resizeComposerInput(inputRef.current);
  };
  function command(key: string, action: () => void, disabled: boolean) {
    return {
      disabled,
      onPointerDown: (event: { preventDefault: () => void }) => event.preventDefault(),
      onTouchEnd: (event: { preventDefault: () => void }) => {
        event.preventDefault();
        if (disabled) return;
        touchTimes.current[key] = Date.now(); action();
      },
      onClick: (event?: { detail: number }) => {
        if (disabled || (event?.detail !== 0 && Date.now() - (touchTimes.current[key] ?? -Infinity) < 750)) return;
        action();
      },
    };
  }

  useEffect(() => {
    if (typeof window === "undefined" || !composerDiagnosticsEnabled(window.location.search) || !inputRef.current) return;
    const trace = startComposerDiagnostics(inputRef.current);
    diagnostic.current = trace;
    return () => { trace?.dispose(); if (diagnostic.current === trace) diagnostic.current = null; };
  }, [inputRef]);
  useEffect(() => {
    diagnostic.current?.update({ reactFocused: Number(focused), streaming: Number(props.streaming), hasText: Number(Boolean(value)), hasAttachments: Number(props.attachments.length > 0) });
  }, [focused, value, props.streaming, props.attachments.length]);
  useEffect(() => {
    const input = inputRef.current;
    if (!input) return;
    diagnostic.current?.capture("resize-before");
    if (!value && !focused) { input.style.height = ""; diagnostic.current?.capture("resize-reset"); return; }
    resizeComposerInput(input);
    diagnostic.current?.capture("resize-after");
  }, [value, focused, inputRef]);
  useEffect(() => {
    const target = pressTarget.current;
    if (!target) return;
    const preventCallout = (event: TouchEvent) => event.preventDefault();
    target.addEventListener("touchstart", preventCallout, { passive: false });
    return () => target.removeEventListener("touchstart", preventCallout);
  }, []);

  return <div className={`${styles.composer} ${focused ? styles.composerFocused : ""} ${value.length ? styles.composerWithText : ""} ${props.attachments.length ? styles.composerWithAttachments : ""} ${props.referencePreview ? styles.composerWithReferences : ""} ${props.acquisition && !props.acquisition.voiceEnabled ? styles.composerWithoutVoice : ""}`}
    data-streaming-reply={props.streaming ? "true" : undefined}>
    {props.referencePreview ? <div className={styles.composerReferences}>{props.referencePreview}</div> : null}
    <ComposerAttachments attachments={props.attachments} disabled={attachmentsLocked} onRemove={id => { if (!attachmentsLocked) props.onRemoveAttachment(id); }} />
    {(!props.acquisition || props.acquisition.attachmentsEnabled) && <button className={styles.composerButton} type="button" aria-label={props.acquisition ? "添加附件" : copy.addContent} title={props.acquisition ? "添加附件" : copy.addContent}
      {...command("attach", props.onOpenAttachments, props.disabled || statusMode || Boolean(props.voice?.busy))}>
      <img src={"/chat/add.svg"} alt="" />
    </button>}
    <div className={styles.composerEntry}>
      <textarea ref={inputRef} id="chat-composer" name="chat-composer" className={styles.composerInput} rows={1}
        autoComplete="off" autoCorrect="off" autoCapitalize="off" spellCheck={false} inputMode="text"
        data-lpignore="true" data-1p-ignore="true" data-form-type="other"
        aria-label={props.acquisition ? placeholder : copy.messageInput} placeholder={placeholder} value={value} disabled={props.disabled}
        onKeyDown={props.acquisition ? event => {
          if (event.key !== "Enter" || event.shiftKey || event.nativeEvent.isComposing || event.nativeEvent.keyCode === 229) return;
          event.preventDefault();
          if (sendEnabled) props.onSend();
        } : undefined}
        onPointerDown={() => props.voice?.cancel(false)}
        onChange={event => props.onChange(event.target.value)} onFocus={() => {
          props.voice?.cancel(false); setFocused(true);
          // Match legacy Chat: keep focus confirmation and sizing in the focus event.
          focus();
        }} onBlur={() => setFocused(false)} />
      <button ref={pressTarget} className={styles.composerPressTarget} type="button" aria-label={copy.voiceGesture}
        hidden={focused || value.length > 0} disabled={props.disabled || dictating}
        onPointerDown={event => {
          touchTap.current = false;
          if (props.disabled || dictating || props.voice?.busy || (event.pointerType === "mouse" && event.button !== 0)) return;
          if (event.pointerType === "touch") touchTap.current = true;
        }}
        onPointerUp={event => {
          if (!props.disabled && !dictating && !props.voice?.busy && event.pointerType !== "touch" && event.button === 0) focus();
        }}
        onPointerCancel={() => { touchTap.current = false; }}
        onTouchEnd={() => { if (touchTap.current) { touchTap.current = false; focus(); } }}
        onContextMenu={event => event.preventDefault()} onClick={event => { if (event.detail === 0) focus(); }}>
        {props.acquisition ? placeholder : copy.composerVoicePrompt}
      </button>
    </div>
    {(!props.acquisition || props.acquisition.voiceEnabled) && <button className={`${styles.composerButton} ${styles.composerVoiceIcon}`} type="button" aria-label={dictating ? copy.endVoice : copy.voiceInput} title={dictating ? copy.endVoice : copy.voiceInput} aria-pressed={dictating}
      aria-disabled={explainVoice || undefined}
      {...command("voice", explainVoice ? props.onPreparationBlocked! : props.onVoice, !explainVoice && (props.disabled || statusMode || Boolean(props.voiceDisabled) || props.voice?.dictationPhase === "stopping" || Boolean(props.voice?.busy && !dictating)))}>
      {dictating ? <>
        <span className={`${styles.microphoneHalo}${listening ? ` ${styles.microphoneBreathing}` : ""}`} aria-hidden="true" />
        <img className={styles.microphoneGlyph} src={"/annotations/recording-microphone.svg"} alt="" width={44} height={44} aria-hidden="true" draggable={false} />
      </> : <img src={"/chat/语音.svg"} alt="" draggable={false} />}
    </button>}
    {props.streaming ? <button className={`${styles.composerButton} ${styles.composerStopButton}`} type="button" aria-label={copy.stopResponse} title={copy.stopResponse}
      {...command("stop", props.onStop, props.disabled || props.stopping)}><span className={styles.composerStopIcon} aria-hidden="true" /></button> :
      <button className={`${styles.composerButton} ${styles.composerSendButton} ${sendEnabled ? styles.composerSendButtonActive : ""}`} type="button" aria-label={copy.sendMessage} title={copy.sendMessage}
        aria-disabled={explainSend || undefined}
        {...command("send", explainSend ? props.onPreparationBlocked! : props.onSend, !sendEnabled && !explainSend)}>
        <img src={"/chat/发送.svg"} alt="" />
      </button>}
  </div>;
}

type AcquisitionChatComposerProps = { placeholder?: string } & Pick<ChatTabComposerProps, "inputRef" | "value" | "onChange" | "onSend">
  & Partial<Pick<ChatTabComposerProps, "disabled" | "onVoice" | "attachments" | "onOpenAttachments" | "onRemoveAttachment">>;

const ignoreComposerAction = () => {};

export function AcquisitionChatComposer({
  disabled = false,
  placeholder,
  onVoice,
  attachments = [],
  onOpenAttachments,
  onRemoveAttachment = ignoreComposerAction,
  ...props
}: AcquisitionChatComposerProps) {
  return <ChatTabComposer
    {...props}
    acquisition={{ placeholder, voiceEnabled: Boolean(onVoice), attachmentsEnabled: Boolean(onOpenAttachments) }}
    attachments={attachments}
    hasReferences={false}
    canSend
    disabled={disabled}
    streaming={false}
    stopping={false}
    onRemoveAttachment={onRemoveAttachment}
    onOpenAttachments={onOpenAttachments ?? ignoreComposerAction}
    onStop={ignoreComposerAction}
    onVoice={onVoice ?? ignoreComposerAction}
  />;
}
