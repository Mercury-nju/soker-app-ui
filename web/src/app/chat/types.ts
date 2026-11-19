export type LocalAttachment = {
  id: string;
  file?: File;
  kind: "text" | "image" | "session-file";
  name: string;
  previewUrl?: string;
  uploadError?: string;
  uploadStatus?: "idle" | "uploading" | "success" | "failed";
};
