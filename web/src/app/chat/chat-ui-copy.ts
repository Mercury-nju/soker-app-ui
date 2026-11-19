import type { ChatToolLocale } from "./chat-tool-copy";

const messages = {
  sessionFiles: ["会话文件", "Session files"], close: ["关闭", "Close"], send: ["发送", "Send"], sending: ["正在发送…", "Sending..."],
  retryFeedbackIdentity: ["重试恢复反馈", "Retry feedback recovery"],
  loadEarlierMessages: ["加载更早消息", "Load earlier messages"],
  reloadTaskStatus: ["重新加载任务状态", "Reload task status"],
  checkSubmission: ["查询发送状态", "Check submission"],
  recovering: ["正在恢复…", "Recovering..."], retryOriginalSubmission: ["重试原提交", "Retry original submission"],
  restoreSendingState: ["恢复发送状态", "Restore sending state"],
  retryAnnotations: ["重试原批注", "Retry original annotations"],
  retryImageAnnotations: ["查询或重试图片批注", "Check or retry image annotations"],
  chooseDirection: ["选择方向", "Choose a direction"], recommendedTaskDirection: ["推荐任务方向", "Recommended task direction"],
  customAnswerOption: ["以上选项都不满足，我自定义回答", "None of these options; write my own answer"],
  customAnswer: ["自定义回答", "Custom answer"], answerPlaceholder: ["请输入你的答案", "Enter your answer"],
  confirmAndSend: ["确认并发送", "Confirm and send"],
  needsConfirmation: ["需要你确认", "Needs your confirmation"],
  customContent: ["自定义内容", "Custom content"],
  keepDraft: ["保留草稿", "Keep draft"],
  continueEditing: ["继续编辑", "Continue editing"],
  discardAnnotationTitle: ["放弃本次批注修改？", "Discard annotation changes?"],
  discardAnnotationWarning: ["批注尚未保存，返回 Chat 将丢弃本次更改。", "Annotations are not saved. Returning to chat will discard these changes."],
  discardAndReturn: ["放弃并返回", "Discard and return"],
  discardAnnotationInputTitle: ["放弃当前批注输入？", "Discard annotation input?"],
  discardAndContinue: ["放弃并继续", "Discard and continue"],
  messageActions: ["消息操作", "Message actions"], quoteReply: ["引用回复", "Quote reply"],
  edit: ["编辑", "Edit"], quote: ["引用", "Quote"], editAsset: ["编辑资产", "Edit asset"],
  quoteAssetAction: ["引用资产", "Quote asset"], regenerate: ["重新生成", "Regenerate"],
  chooseRegeneration: ["选择重新生成方向", "Choose a regeneration direction"],
  currentAsset: ["当前资产", "Current asset"], keepOriginalDirection: ["选择一个方向，原稿会保留", "Choose a direction. The original will be kept."],
  regenerationFailed: ["重新生成方向准备失败", "Couldn't prepare regeneration directions"],
  regenerationPreparing: ["正在准备重新生成方向", "Preparing regeneration directions"],
  retryDirections: ["重试生成方向", "Retry directions"], refreshDirections: ["刷新方向状态", "Refresh direction status"],
  additionalRequirements: ["补充要求", "Additional requirements"], optional: ["选填", "Optional"],
  requirementsPlaceholder: ["也可以补充你的想法…", "Add your ideas..."],
  asset: ["资产", "Asset"], previewUnavailable: ["预览暂不可用", "Preview unavailable"], openPreview: ["点击打开预览", "Open preview"],
  downloadOriginal: ["下载原件", "Download original"], downloading: ["正在下载…", "Downloading..."],
  editAnnotations: ["编辑资产批注", "Edit asset annotations"], assetPreview: ["资产预览", "Asset preview"],
  backToChat: ["返回Chat", "Back to chat"], annotatePage: ["批注页面", "Annotate page"],
  annotatePresentation: ["批注演示文稿", "Annotate presentation"], editImage: ["编辑图片", "Edit image"],
  saveAndReturn: ["保存并返回", "Save and return"], otherDownloadFormats: ["其他下载格式", "Other download formats"],
  otherFormats: ["其他格式", "Other formats"], downloadFormat: ["下载{format}", "Download {format}"],
  loadingOriginal: ["正在加载原件…", "Loading original..."], reloadOriginalPages: ["重新加载原件页图", "Reload original pages"],
  originalPagesFailed: ["原件页图加载失败，可能链接已过期。已保留批注，请重试加载同一版本后再选择新位置。", "Original pages couldn't load; the link may have expired. Annotations are kept. Reload the same version before selecting a new position."],
  annotateContentHint: ["点选需要修改的内容，留下你的批注", "Select content to annotate"],
  annotatePointHint: ["轻点图片中的位置，添加修改要求", "Tap a position to add requirements"],
  annotateRegionHint: ["拖动框选区域，添加修改要求", "Drag a region to add requirements"],
  htmlPreview: ["HTML预览", "HTML preview"], pdfPreview: ["PDF预览", "PDF preview"], imagePreview: ["图片预览", "Image preview"],
  pageNumber: ["页码", "Page"], selectPptPage: ["选择PPT页码", "Select presentation page"],
  pageOfTotal: ["第{page}页 / {total}", "Page {page} / {total}"], annotationMode: ["批注方式", "Annotation mode"],
  pointSelection: ["点选", "Point"], regionSelection: ["框选", "Region"], zoom: ["缩放", "Zoom"],
  imageZoom: ["图片缩放", "Image zoom"], fitScreen: ["适合屏幕", "Fit to screen"],
  editAnnotation: ["编辑批注{number}：{comment}", "Edit annotation {number}: {comment}"],
  annotationEditor: ["批注编辑", "Annotation editor"], addedAnnotations: ["已添加的批注", "Added annotations"],
  selectedPageRegion: ["已选页面区域", "Selected page region"], cancelAnnotation: ["取消本处批注", "Cancel this annotation"],
  currentAnnotation: ["本处批注", "Current annotation"], describeRequirements: ["描述修改要求", "Describe your requirements"],
  confirmAnnotation: ["确认修改批注", "Confirm annotation changes"], addAnnotation: ["添加批注", "Add annotation"],
  deleteAnnotation: ["删除此批注", "Delete annotation"],
  continueAnnotationsHint: ["点击编号可继续编辑 · 保存后回到对话补充要求", "Select a number to continue editing. Save to return to chat and add requirements."],
  selectPositionHint: ["选择位置后，输入修改要求", "Select a position, then enter requirements"],
  discardAnnotationInput: ["当前批注尚未确认，切换位置将丢弃输入，是否继续？", "This annotation is not confirmed. Switching positions will discard your input. Continue?"],
  discardAnnotationChanges: ["批注尚未保存，确定返回Chat并丢弃本次更改？", "Annotations are not saved. Return to chat and discard these changes?"],
  operationFailed: ["操作失败，请稍后重试。", "The operation failed. Please try again later."],
  conversationList: ["会话列表", "Chat history"], outputType: ["产物类型", "Output type"],
  draftConfirm: ["放弃未发送的草稿？", "Discard unsent draft?"],
  draftWarning: ["未发送的内容和附件将保留到切换成功，是否继续？", "Your draft and attachments will be kept until switching succeeds. Continue?"],
  discardContinue: ["放弃草稿并继续", "Discard and continue"],
  loadMoreChats: ["加载更多", "Load more"],
  language: ["语言", "Language"],
  chat: ["聊天", "Chat"], navigation: ["聊天导航", "Chat navigation"], back: ["返回", "Back"],
  newChat: ["新建对话", "New chat"], more: ["更多", "More"], moreActions: ["更多操作", "More actions"],
  newChatTitle: ["新对话", "New chat"], untitledChat: ["未命名对话", "Untitled chat"], welcome: ["有什么可以帮你？", "How can I help you?"],
  recommended: ["推荐问法", "Recommended"], suggestedQuestions: ["推荐问法", "Suggested questions"],
  composerPlaceholder: ["输入消息…", "Enter a message..."],
  composerVoicePrompt: ["输入消息…", "Enter a message..."],
  messageInput: ["消息输入", "Message input"], addContent: ["添加内容", "Add content"],
  scrollBottom: ["滚动到底部", "Scroll to bottom"], voiceGesture: ["点按输入文字", "Tap to type"],
  voiceInput: ["语音输入", "Voice input"], endVoice: ["结束语音输入", "End voice input"],
  stopResponse: ["停止回复", "Stop response"], sendMessage: ["发送消息", "Send message"],
  responding: ["正在回复中", "Responding"], stopping: ["正在停止", "Stopping"],
  recoveryReadTimeout: ["执行状态恢复超时，请重试。", "Conversation recovery timed out. Please retry."],
  syncingConversation: ["正在同步会话状态…", "Syncing conversation status…"],
  offline: ["网络已断开，联网后自动恢复。", "You're offline. Reconnecting automatically when the network is available."],
  reconnecting: ["正在恢复连接…", "Reconnecting..."], retry: ["重试", "Retry"],
  loading: ["加载中…", "Loading..."], closeDialog: ["关闭弹出层", "Close dialog"],
  thinking: ["思考中", "Thinking"], thinkingComplete: ["思考完成", "Thinking complete"],
  thinkingDuration: ["已思考 {N} 秒", "Thinking for {N}s"], thinkingProcess: ["思考过程", "Thinking process"],
  thinkingStopped: ["思考已停止", "Thinking stopped"], thinkingFailed: ["思考中断", "Thinking interrupted"],
  searching: ["网页搜索中", "Searching the web"], searched: ["已搜索 {N} 个网页", "Searched {N} webpages"],
  searchedOne: ["已搜索 1 个网页", "Searched 1 webpage"], searchStopped: ["搜索已停止", "Search stopped"],
  searchUnavailable: ["搜索暂时不可用", "Search is temporarily unavailable"], searchComplete: ["搜索已完成", "Search completed"],
  consulted: ["参考了 {N} 篇资料", "Consulted {N} sources"], consultedOne: ["参考了 1 篇资料", "Consulted 1 source"],
  searchProgress: ["搜索进度", "Search progress"], searchResults: ["搜索结果列表", "Search results"],
  sources: ["引用来源", "Sources"], sourceCount: ["引用来源（{N}）", "Sources ({N})"],
  citationRecoveryFailed: ["引用来源暂时无法加载。", "Sources could not be loaded."],
  retryCitationRecovery: ["重试加载来源", "Retry sources"],
  sourceDetails: ["引用来源详情", "Source details"], noExcerpt: ["暂无正文片段", "No excerpt available"],
  noSources: ["暂无可展示的引用来源", "No sources to display"], linkPreview: ["链接预览", "Link preview"],
  intent: ["意图确认", "Intent clarification"], intentPrompt: ["我理解你想进一步确认：", "I understand you want to clarify:"],
  userInput: ["用户输入", "User input"], aiOutput: ["AI 输出", "AI output"],
  messageReaction: ["助手表情：{emoji}", "Assistant reaction: {emoji}"],
  messageAttachments: ["消息附件", "Message attachments"], selectedAttachments: ["已选择附件", "Selected attachments"],
  quotedMessage: ["已引用的消息", "Quoted message"],
  messageReference: ["消息引用", "Message reference"],
  assetReference: ["资产引用", "Asset reference"],
  referencedAsset: ["引用资产", "Referenced asset"],
  removeReference: ["移除引用", "Remove reference"],
  cancelReference: ["取消引用", "Cancel reference"],
  annotationCount: ["{N}处批注", "{N} annotations"],
  annotationCountOne: ["{N}处批注", "{N} annotation"],
  quoteUserMessage: ["你的消息，长按或按Shift+F10引用", "Your message. Hold or press Shift+F10 to quote"],
  quoteAssistantReply: ["助手回复，长按或按Shift+F10引用", "Assistant reply. Hold or press Shift+F10 to quote"],
  quoteAsset: ["{name}，长按引用资产", "{name}. Hold to quote this asset"],
  summaryTitle: ["分析总结", "Meeting summary"],
  collapseMessage: ["收起", "Show less"],
  expandMessage: ["查看更多", "Show more"],
  submittedAssetAnnotations: ["已提交{N}处资产批注", "Submitted {N} asset annotations"],
  submittedAssetAnnotationOne: ["已提交{N}处资产批注", "Submitted {N} asset annotation"],
  followUps: ["后续问题建议", "Follow-up suggestions"],
  usage: ["本次消耗 {used} AI灵感 · 剩余 {remaining}", "{used} AI Inspiration used · {remaining} remaining"],
  zeroUsage: ["本次未消耗 AI灵感 · 剩余 {remaining}", "No AI Inspiration used · {remaining} remaining"],
  billingRecoveryFailed: ["灵感消耗暂时无法加载，不影响继续聊天。", "Inspiration usage could not be loaded. You can still chat."],
  retryBillingRecovery: ["重试加载消耗", "Retry usage"],
  inspirationExhausted: ["灵感值已用尽，请尽快补充", "You're out of AI Inspiration. Please top up soon."],
  insufficient: ["当前 AI 灵感额度不足，请购买加量包后继续使用。", "You don't have enough AI Inspiration. Purchase an add-on pack to continue."],
  copied: ["已复制", "Copied"], thanksLike: ["感谢您的认可！我们将继续努力", "Thanks for your support! We'll keep improving."],
  thanksFeedback: ["感谢您的反馈！我们将继续努力", "Thanks for your feedback! We'll keep improving."],
  replyActions: ["回复操作", "Reply actions"], copyAnswer: ["复制回答", "Copy answer"],
  like: ["点赞", "Like"], dislike: ["点踩", "Dislike"], feedbackNotReady: ["回复信息尚未就绪，暂无法反馈", "This reply isn't ready for feedback yet"],
  feedbackSubmitting: ["反馈提交中", "Submitting feedback"], copyFailed: ["复制失败，请重试。", "Copy failed. Please try again."],
  feedbackFailed: ["反馈提交失败，请重试。", "Couldn't submit feedback. Please try again."],
  fileType: ["选择文件类型", "Choose a file type"], chooseSessionFiles: ["选择会话文件", "Choose session files"],
  textFiles: ["TXT / MD 文件", "TXT / MD files"], camera: ["拍照", "Take a photo"], photos: ["照片", "Photos"],
  file: ["文件", "File"], extensionFile: ["{extension} 文件", "{extension} file"], meetingRecord: ["会议记录", "Meeting record"],
  uploading: ["上传中", "Uploading"], uploadFailed: ["附件上传失败", "Attachment upload failed"],
  uploaded: ["已上传", "Uploaded"], waitingUpload: ["等待上传", "Waiting to upload"], remove: ["移除 {name}", "Remove {name}"],
  noMatchingFiles: ["未找到匹配的会话文件", "No matching session files"], noSessionFiles: ["暂无会话文件", "No session files"],
  untitledSessionFile: ["未命名会话文件", "Untitled session file"], selectFile: ["选择 {name}", "Select {name}"],
  deselectFile: ["取消选择 {name}", "Deselect {name}"], summary: ["摘要：", "Summary:"],
  loadingFile: ["正在加载 {name}", "Loading {name}"], pause: ["暂停 {name}", "Pause {name}"],
  play: ["播放 {name}", "Play {name}"], seek: ["调整播放进度 {name}", "Seek {name}"],
  audioFailed: ["无法播放音频", "Unable to play audio"], searchFiles: ["搜索会话文件", "Search session files"],
  closeSearch: ["关闭搜索", "Close search"], search: ["搜索", "Search"], confirm: ["确认", "Confirm"], cancel: ["取消", "Cancel"],
  feedback: ["反馈", "Feedback"], feedbackThanks: ["感谢你的反馈，我们会持续改进。", "Thanks for your feedback. We'll keep improving."],
  feedbackPrompt: ["告诉我们哪些地方需要改进（可多选）。", "Tell us what we could improve (select all that apply)."],
  feedbackContent: ["反馈内容", "Feedback content"], feedbackReasons: ["反馈原因", "Feedback reasons"],
  noFeedbackReasons: ["暂无可选原因，可填写补充说明。", "No reasons available. You can add a comment."],
  comment: ["补充说明", "Additional comments"], commentPlaceholder: ["还有其他问题？请补充说明。", "Anything else? Tell us more."],
  clearComment: ["清空补充说明", "Clear comments"], submitting: ["提交中…", "Submitting..."],
  submitFeedback: ["提交反馈", "Submit feedback"], skip: ["跳过", "Skip"],
  feedbackLoadFailed: ["反馈原因加载失败，请重试。", "Couldn't load feedback reasons. Please try again."],
  history: ["历史记录", "History"], chats: ["对话", "Chats"], outputs: ["产物", "Outputs"],
  historyType: ["历史内容类型", "History content type"], allTime: ["全部时间", "All time"],
  pastWeek: ["近一周", "Past week"], past30Days: ["近 30 天", "Past 30 days"], all: ["全部", "All"],
  allCount: ["全部时间（{N}）", "All ({N})"], images: ["图片", "Images"], documents: ["文档", "Documents"],
  chatDateRange: ["对话历史时间范围", "Chat history date range"], loadingChats: ["正在加载对话…", "Loading chats..."],
  noChats: ["暂无对话", "No chats yet"], chatActions: ["对话操作", "Chat actions"],
  outputActions: ["产物操作", "Output actions"], rename: ["重命名", "Rename"], delete: ["删除", "Delete"],
  download: ["下载", "Download"], deleteChat: ["删除此对话？", "Delete this chat?"],
  deleteChatWarning: ["此对话删除后无法恢复。", "This chat cannot be recovered."],
  keepOutputs: ["已生成的产物不会被删除。", "Generated outputs will not be deleted."],
  deleteOutput: ["删除此产物？", "Delete this output?"], deleteOutputWarning: ["此产物删除后无法恢复。", "This output cannot be recovered."],
  clearTitle: ["清空标题", "Clear title"],
  renameChat: ["重命名对话", "Rename chat"], enterTitle: ["输入标题", "Enter a title"],
  outputRange: ["选择产物时间范围", "Select output date range"], outputDateRange: ["产物时间范围", "Output date range"],
  loadingOutputs: ["正在加载产物…", "Loading outputs..."], noOutputs: ["暂无产物", "No outputs yet"],
  preview: ["预览 {name}", "Preview {name}"], outputOpenFailed: ["产物暂时无法打开，请重试。", "This output cannot be opened right now. Please try again."],
  noDownload: ["产物下载地址不存在，请重试。", "No download link is available. Please try again."],
  downloadFailed: ["下载失败，请重试。", "Download failed. Please try again."],
  outputsLoadFailed: ["加载产物失败，请重试。", "Failed to load outputs. Please try again."],
  chatNotReady: ["会话尚未就绪，请稍后重试。", "Chat session is not ready yet. Please try again later."],
  chatsLoadFailed: ["加载对话失败，请重试。", "Failed to load chats. Please try again."],
  renameFailed: ["重命名对话失败，请重试。", "Failed to rename chat. Please try again."],
  deleteChatFailed: ["删除对话失败，请重试。", "Failed to delete chat. Please try again."],
  deleteOutputFailed: ["删除产物失败，请重试。", "Failed to delete output. Please try again."],
  networkFailed: ["网络连接失败，请稍后重试。", "Network connection failed. Please try again later."],
  reconnectFailed: ["无法恢复连接，请重新进入会话。", "Couldn't reconnect. Please reopen the chat."],
  restoreTimeout: ["恢复会话超时，请重试。", "Restoring the chat timed out. Please try again."],
  restoreFailed: ["恢复聊天会话失败，请稍后重试。", "Couldn't restore the chat. Please try again later."],
  createFailed: ["创建会话失败，请稍后重试。", "Couldn't create the chat. Please try again later."],
  sendFailed: ["发送消息失败，请稍后重试。", "Couldn't send the message. Please try again later."],
  messageSubmitting: ["发送中", "Sending"],
  messageConfirming: ["正在确认发送结果", "Confirming delivery"],
  messageSendFailed: ["发送失败，内容已保留，可修改后重试", "Send failed. Edit your draft and try again."],
  querySendStatus: ["查询状态", "Check status"],
  stopFailed: ["中断聊天失败，请稍后重试。", "Couldn't stop the response. Please try again later."],
  stopTimeout: ["等待停止确认超时，回复可能仍在进行，请重试。", "Stop confirmation timed out. The response may still be running. Please try again."],
  responseFailed: ["AI 回复失败，请稍后重试。", "The AI response failed. Please try again later."],
  invalidChat: ["无法打开或操作此对话，请重新进入。", "Couldn't open or update this chat. Please reopen it."],
  attachmentsNotReady: ["附件上传中或上传失败，请处理后再发送。", "An attachment is still uploading or failed to upload. Resolve it before sending."],
  filesLoadFailed: ["获取会话文件失败，请稍后重试。", "Couldn't load session files. Please try again later."],
  attachmentFailed: ["附件上传失败，请检查网络后重试。", "Attachment upload failed. Check your connection and try again."],
  voiceFailed: ["语音输入失败，请重试。", "Voice input failed. Please try again."],
  recognitionFailed: ["语音识别失败，请重试。", "Speech recognition failed. Please try again."],
  voiceStartFailed: ["无法启动语音输入，请重试。", "Couldn't start voice input. Please try again."],
  voiceActionFailed: ["语音输入操作失败，请重试。", "The voice input action failed. Please try again."],
  closeFailed: ["关闭页面失败，请重试。", "Couldn't close the page. Please try again."],
  replyNotReady: ["回复信息尚未就绪，请稍后重试。", "This reply isn't ready yet. Please try again later."],
  feedbackChanged: ["反馈状态已变化，请重新操作。", "Feedback has changed. Please try again."],
  feedbackBusy: ["反馈提交中，请稍候。", "Feedback is being submitted. Please wait."],
  feedbackValidation: ["请选择反馈原因或填写补充说明，最多选择 6 项，说明不超过 200 字。", "Select up to 6 reasons or add a comment of up to 200 characters."],
  titleTooLong: ["会话名称不能超过 128 个字符。", "The chat title must be 128 characters or fewer."],
} as const;

export type ChatCopyKey = keyof typeof messages;
type ChatCopy = Record<ChatCopyKey, string>;
const dictionaries = Object.fromEntries((["zh", "en"] as const).map((locale, index) => [
  locale, Object.fromEntries(Object.entries(messages).map(([key, pair]) => [key, pair[index]])),
])) as Record<ChatToolLocale, ChatCopy>;

export function getChatCopy(locale: ChatToolLocale) { return dictionaries[locale]; }

export function fillChatCopy(template: string, values: Record<string, string | number>) {
  return template.replace(/\{(\w+)\}/g, (match, key: string) => String(values[key] ?? match));
}

// Only known fixed UI messages are projected; unknown backend/native diagnostics never reach the UI.
const errorAliases: Record<string, ChatCopyKey> = {
  "Failed to load outputs.": "outputsLoadFailed", "Failed to load chats.": "chatsLoadFailed",
  "Chat session is not ready yet.": "chatNotReady", "Failed to rename chat.": "renameFailed",
  "Failed to delete chat.": "deleteChatFailed", "Failed to delete output.": "deleteOutputFailed",
  "附件上传失败，请稍后重试。": "attachmentFailed", "反馈原因加载失败，请检查网络后重试。": "feedbackLoadFailed",
  "反馈提交失败，请检查网络后重试。": "feedbackFailed", "会话信息不完整，无法删除该对话。": "invalidChat",
  "会话信息不完整，无法打开该对话。": "invalidChat", "会话参数无效。": "invalidChat",
  "缺少回复 Run ID，暂无法提交反馈。": "replyNotReady",
};
const knownErrors = new Map<string, ChatCopyKey>([
  ...Object.entries(errorAliases),
  ...Object.entries(messages).flatMap(([key, pair]) => pair.map((text) => [text, key as ChatCopyKey] as const)),
]);

export function chatErrorText(error: unknown, locale: ChatToolLocale, fallback: ChatCopyKey) {
  const message = error instanceof Error ? error.message : typeof error === "string" ? error : "";
  const key = knownErrors.get(message);
  // Do not accept arbitrary non-error UI strings, even if a server happens to return one.
  const safe = key && (key.endsWith("Failed") || key.endsWith("Timeout") || key === "invalidChat"
    || key === "titleTooLong" || key === "feedbackValidation" || key === "replyNotReady"
    || key === "chatNotReady" || key === "feedbackChanged" || key === "feedbackBusy"
    || key === "attachmentsNotReady");
  return getChatCopy(locale)[safe ? key : fallback];
}

export function formatChatUsage(used: number, remaining: number, locale: ChatToolLocale) {
  if (![used, remaining].every((n) => Number.isFinite(n) && n >= 0)) return null;
  const copy = getChatCopy(locale);
  return fillChatCopy(used === 0 ? copy.zeroUsage : copy.usage, {
    used: used.toLocaleString(locale === "zh" ? "zh-CN" : "en-US"),
    remaining: remaining.toLocaleString(locale === "zh" ? "zh-CN" : "en-US"),
  });
}

export function projectLegacyUsage(value: string | null, locale: ChatToolLocale) {
  if (!value) return null;
  const number = "([\\d,]+(?:\\.\\d+)?)";
  const patterns = [
    new RegExp(`^本次消耗 ${number} AI灵感 · 剩余 ${number}$`),
    new RegExp(`^${number} AI Inspiration used · ${number} remaining$`),
  ];
  for (const pattern of patterns) {
    const match = value.match(pattern);
    if (match) return formatChatUsage(Number(match[1].replaceAll(",", "")), Number(match[2].replaceAll(",", "")), locale);
  }
  const zero = value.match(new RegExp(`^(?:本次未消耗 AI灵感 · 剩余 |No AI Inspiration used · )${number}(?: remaining)?$`));
  return zero ? formatChatUsage(0, Number(zero[1].replaceAll(",", "")), locale) : null;
}

export function formatChatMessageTime(value: string, locale: ChatToolLocale) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  const time = [date.getHours(), date.getMinutes(), date.getSeconds()].map((n) => String(n).padStart(2, "0")).join(":");
  return locale === "zh" ? `${date.getMonth() + 1}月${date.getDate()}日 ${time}`
    : `${new Intl.DateTimeFormat("en-US", { month: "long" }).format(date)} ${date.getDate()}, ${time}`;
}
