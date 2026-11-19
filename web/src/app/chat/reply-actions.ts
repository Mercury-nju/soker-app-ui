export async function copyReplyText(text: string) {
  if (navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(text);
    return;
  }
  const input = document.createElement("textarea");
  input.value = text;
  input.style.position = "fixed";
  input.style.display = "none";
  input.style.opacity = "0";
  input.readOnly = true;
  document.body.appendChild(input);
  const focused = document.activeElement;
  try {
    input.select();
    if (!document.execCommand("copy")) throw new Error("Copy unavailable");
  } finally {
    input.remove();
    if (focused instanceof HTMLElement) focused.focus({ preventScroll: true });
  }
}
