import { AttachmentCard } from "../AttachmentCard";
import type { LocalAttachment } from "../../types";
import styles from "./ComposerAttachments.module.scss";
import { useChatCopy } from "../../chat-locale";

export function ComposerAttachments({
  attachments,
  onRemove,
  disabled = false,
}: {
  attachments: LocalAttachment[];
  onRemove: (id: string) => void;
  disabled?: boolean;
}) {
  const copy = useChatCopy();
  if (attachments.length === 0) return null;

  return (
    <div className={styles.composerAttachments} data-composer-attachments aria-label={copy.selectedAttachments}>
      {attachments.map((attachment) => (
        <AttachmentCard attachment={attachment} removeDisabled={disabled} onRemove={() => { if (!disabled) onRemove(attachment.id); }} key={attachment.id} />
      ))}
    </div>
  );
}
