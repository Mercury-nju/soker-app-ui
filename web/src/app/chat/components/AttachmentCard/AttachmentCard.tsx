import type { LocalAttachment } from "../../types";
import styles from "./AttachmentCard.module.scss";
import { useChatCopy, useChatLocale } from "../../chat-locale";
import { chatErrorText, fillChatCopy, getChatCopy } from "../../chat-ui-copy";
import type { ChatToolLocale } from "../../chat-tool-copy";

type AttachmentCardData = LocalAttachment & {
  size?: number;
  file?: File;
  uploadError?: string;
  uploadStatus?: "idle" | "uploading" | "success" | "failed";
};

const icons = {
  session: "/chat/会话文件.svg",
  text: "/chat/文件.svg",
  txt: "/chat/txt.svg",
  md: "/chat/md-composer.svg",
};

function getFileExtension(fileName: string, locale: ChatToolLocale) {
  const extension = fileName.split(".").pop()?.trim().toLowerCase();
  const copy = getChatCopy(locale);
  return extension ? fillChatCopy(copy.extensionFile, { extension }) : copy.file;
}

function getTextAttachmentIcon(fileName: string) {
  const extension = fileName.split(".").pop()?.trim().toLowerCase();
  if (extension === "txt") return icons.txt;
  if (extension === "md") return icons.md;
  return icons.text;
}

function formatFileSize(size: number) {
  if (size >= 1024 * 1024) return `${(size / 1024 / 1024).toFixed(1)}M`;
  if (size >= 1024) return `${Math.ceil(size / 1024)}K`;
  return `${size}B`;
}

function getAttachmentUploadLabel(attachment: AttachmentCardData, locale: ChatToolLocale) {
  const copy = getChatCopy(locale);
  if (attachment.uploadStatus === "uploading") return copy.uploading;
  if (attachment.uploadStatus === "failed")
    return chatErrorText(attachment.uploadError, locale, "uploadFailed");
  if (attachment.uploadStatus === "success") return copy.uploaded;
  return copy.waitingUpload;
}

export function AttachmentCard({
  attachment,
  onRemove,
  removeDisabled = false,
}: {
  attachment: AttachmentCardData;
  onRemove?: () => void;
  removeDisabled?: boolean;
}) {
  const locale = useChatLocale();
  const copy = useChatCopy();
  const size = attachment.size ?? attachment.file?.size;
  const extension = attachment.name.split(".").pop()?.trim().toLowerCase();
  const isMarkdown = attachment.kind !== "image" && attachment.kind !== "session-file" && extension === "md";
  const isTxt = attachment.kind !== "image" && attachment.kind !== "session-file" && extension === "txt";
  return (
    <article
      className={
        attachment.kind === "image"
          ? styles.composerAttachmentPhoto
          : attachment.kind === "session-file"
            ? styles.composerAttachmentSessionFile
            : styles.composerAttachmentFile
      }
      data-upload-status={onRemove ? attachment.uploadStatus : undefined}
    >
      {attachment.kind === "image" && attachment.previewUrl ? (
        <img
          className={styles.composerAttachmentPreview}
          src={attachment.previewUrl}
          alt={attachment.name}
        />
      ) : (
        <div
          className={
            attachment.kind === "session-file"
              ? styles.composerAttachmentSessionIcon
              : `${styles.composerAttachmentFileIcon} ${isMarkdown ? styles.composerAttachmentMarkdownIcon : ""} ${isTxt ? styles.composerAttachmentTxtIcon : ""}`
          }
          aria-hidden="true"
        >
          <img
            src={
              attachment.kind === "session-file"
                ? icons.session
                : getTextAttachmentIcon(attachment.name)
            }
            alt=""
          />
        </div>
      )}
      {attachment.kind !== "image" ? (
        <div className={styles.composerAttachmentMeta}>
          <strong>{attachment.name}</strong>
          <span>
            {attachment.kind === "session-file"
              ? copy.meetingRecord
              : `${getFileExtension(attachment.name, locale)} | ${size === undefined ? "" : formatFileSize(size)}`}
          </span>
          {onRemove && attachment.kind !== "session-file" && attachment.uploadStatus !== "success" ? (
            <span className={styles.composerAttachmentStatus}>
              {getAttachmentUploadLabel(attachment, locale)}
            </span>
          ) : null}
        </div>
      ) : null}
      {onRemove && attachment.kind === "image" && attachment.uploadStatus && attachment.uploadStatus !== "success" ? (
        <span className={styles.composerAttachmentStatus}>
          {getAttachmentUploadLabel(attachment, locale)}
        </span>
      ) : null}
      {onRemove ? (
        <button
          className={styles.composerAttachmentRemove}
          type="button"
          aria-label={fillChatCopy(copy.remove, { name: attachment.name })}
          disabled={removeDisabled}
          onClick={() => { if (!removeDisabled) onRemove(); }}
        >
          ×
        </button>
      ) : null}
    </article>
  );
}
