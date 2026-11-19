import Foundation

/// Enterprise process projection, following Android XiaoYanThinkingParser / AgentNativeProcessAccumulator.
nonisolated struct ENTChatProcessState: Equatable, Sendable {
    struct Step: Equatable, Sendable {
        var id: String
        var title: String
        var detail: String
        var status: String?
        var toolInput: String = ""
        var toolResult: String = ""
        var previousFailures: [String] = []

        var isTool: Bool { id.hasPrefix("tool:") || title == "调用工具" }
        var isContext: Bool {
            id == "context" || id.hasPrefix("context:") || ["正在压缩历史对话", "历史对话压缩"].contains(title)
        }
        var isThinking: Bool { !isTool && !isContext }
        var isActive: Bool {
            ["running", "in_progress", "in-progress", "started", "invoking", "receiving", "retrying"].contains(status ?? "")
        }
        var statusDetail: String {
            switch status {
            case "running", "in_progress", "in-progress", "started": return "正在执行"
            case "invoking": return "正在调取工具"
            case "receiving": return "正在接收结果"
            case "retrying": return "正在重试"
            case "success", "succeeded", "completed": return "已完成"
            case "empty": return "无匹配结果"
            case "partial": return "部分结果"
            case "failed", "error": return "执行失败"
            case "unavailable": return "不可用"
            case "queued": return "正在排队"
            case "waiting_user": return "等待补充条件"
            case "cancelled", "canceled", "stopped": return "已停止"
            case "unconfirmed", "interrupted": return "状态待确认"
            default: return status.map { "状态：\($0)" } ?? ""
            }
        }
    }

    struct Group: Equatable, Sendable {
        let id: String
        var steps: [Step]

        var title: String {
            let first = steps[0]
            if first.isContext {
                switch first.status {
                case "success", "succeeded", "completed": return "历史对话已成功压缩"
                case "failed", "error": return "历史对话压缩失败"
                case "cancelled", "canceled", "stopped": return "历史对话压缩已停止"
                case "unconfirmed": return "历史对话压缩状态待确认"
                default: return "正在压缩历史对话"
                }
            }
            if first.isThinking {
                switch first.status {
                case "stopped", "cancelled", "canceled": return "思考已停止"
                case "unconfirmed", "interrupted": return "思考已中断"
                default: return first.isActive ? "正在思考" : "思考过程"
                }
            }
            if steps.contains(where: { $0.status == "retrying" }) { return "正在重试工具" }
            if steps.allSatisfy({ $0.status == "invoking" }) { return "正在调取工具" }
            if steps.contains(where: { $0.status == "receiving" }) && !steps.contains(where: {
                ["running", "invoking"].contains($0.status ?? "")
            }) { return "正在接收工具结果" }
            return "调用 \(steps.count) 次工具"
        }
    }

    private(set) var steps: [Step] = []
    private(set) var startedAt: TimeInterval?
    private(set) var durationSeconds: Int?
    private(set) var replyTextStarted = false
    private(set) var statusText: String?
    var usesAcquisitionPresentation = false
    private var modelSerial = 0
    private var activeModelID: String?
    private var rawSerial = 0

    var completedAcquisitionStepCount: Int {
        steps.lazy.filter {
            $0.id.hasPrefix("tool:") && ["success", "empty", "partial"].contains($0.status ?? "")
        }.count
    }

    var groups: [Group] {
        var result: [Group] = []
        for step in steps {
            if step.isTool, let last = result.last, last.steps.allSatisfy(\.isTool) {
                result[result.count - 1].steps.append(step)
            } else if !step.isThinking || !step.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.append(Group(id: step.id, steps: [step]))
            }
        }
        return result
    }

    mutating func start(at now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        if startedAt == nil, durationSeconds == nil { startedAt = now }
    }

    func elapsedSeconds(at now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Int {
        durationSeconds ?? startedAt.map { max(0, Int(now - $0)) } ?? 0
    }

    mutating func beginAnswer() {
        replyTextStarted = true
        freezeClock()
        closeRawThinking()
    }

    mutating func finish() {
        freezeClock()
        for index in steps.indices where steps[index].isActive || (steps[index].status == nil && index == steps.indices.last) {
            steps[index].status = "unconfirmed"
        }
    }

    mutating func consume(_ payload: AgentEventValue, type: String) {
        start()
        if let text = payload.firstText("statusText", "processStatusText", "message") {
            statusText = text
        }
        if type == "agent.native" {
            if let event = payload["event"] { consumeNative(event) }
            return
        }
        let containers = [payload, payload["payload"], payload["result"], payload["data"]].compactMap { $0 }
        let keys = ["thinking", "trace", "reasoning", "thought", "step", "delta", "content", "text", "message"]
        guard let container = containers.first(where: { value in keys.contains { value[$0] != nil } }),
              let raw = keys.compactMap({ container[$0] }).first else { return }
        merge(raw, container: container, append: type.hasSuffix(".delta") || payload["delta"] != nil)
    }

    static func isThinkingDelta(_ payload: AgentEventValue) -> Bool {
        if let channel = payload.firstText("channel", "kind", "type", "part")?.lowercased(),
           ["thinking", "thought", "reasoning", "trace"].contains(channel) { return true }
        if ["thinking", "trace", "reasoning", "thought"].contains(where: { payload[$0] != nil }) { return true }
        return payload["delta"].map(isThinkingDelta) ?? false
    }
}

private extension ENTChatProcessState {
    nonisolated mutating func freezeClock() {
        guard startedAt != nil, durationSeconds == nil else { return }
        durationSeconds = elapsedSeconds()
        startedAt = nil
    }

    nonisolated mutating func closeRawThinking() {
        if let index = steps.indices.last, steps[index].id.hasPrefix("raw:"), steps[index].isActive {
            steps[index].status = "completed"
        }
    }

    nonisolated mutating func merge(_ raw: AgentEventValue, container: AgentEventValue, append: Bool) {
        if case .array(let values) = raw {
            for value in values { merge(value, container: container, append: append) }
            return
        }
        if let nested = raw["steps"] {
            merge(nested, container: raw, append: append)
            return
        }
        let detail = raw.text ?? raw.firstText("detail", "content", "text", "message", "summary") ?? ""
        let association = raw.firstText("id", "stepId", "key") ?? container.firstText("stepId")
            ?? raw.firstIdentifier("sequence", "seq", "index") ?? container.firstIdentifier("sequence", "index")
        let status = raw.firstText("status", "state")?.lowercased()
        guard !detail.isEmpty || (association != nil && status != nil) else { return }
        let title = raw.firstText("title", "name", "phase") ?? container.firstText("title", "name") ?? ""
        if let association {
            let incoming = Step(id: association, title: title, detail: detail, status: status)
            if let index = steps.firstIndex(where: { $0.id == association }) {
                let old = steps[index]
                if status == "retrying", ["failed", "error"].contains(old.status ?? ""), !old.detail.isEmpty {
                    steps[index].previousFailures.append(old.detail)
                }
                steps[index].title = title.isEmpty ? old.title : title
                if !detail.isEmpty { steps[index].detail = detail }
                steps[index].status = status ?? old.status
            } else {
                closeRawThinking()
                steps.append(incoming)
            }
        } else if let index = steps.indices.last,
                  (steps[index].id.hasPrefix("raw:") && steps[index].isActive || steps[index].id == activeModelID) {
            steps[index].detail = append ? steps[index].detail + detail : detail
            steps[index].status = status ?? steps[index].status
        } else {
            rawSerial += 1
            steps.append(Step(id: "raw:\(rawSerial)", title: title, detail: detail, status: status ?? "running"))
        }
    }

    nonisolated mutating func consumeNative(_ event: AgentEventValue) {
        guard let type = event["type"]?.text?.uppercased() else { return }
        switch type {
        case "MODEL_CALL_START":
            closeRawThinking()
            modelSerial += 1
            let id = "model:\(modelSerial)"
            activeModelID = id
            steps.append(Step(id: id, title: "思考", detail: "", status: "running"))
        case "MODEL_CALL_END":
            if let index = steps.firstIndex(where: { $0.id == activeModelID }) { steps[index].status = "completed" }
            activeModelID = nil
        case "THINKING_BLOCK_START", "THINKING_BLOCK_DELTA", "THINKING_BLOCK_END":
            guard let block = event.firstText("block_id") else { return }
            let id = "thinking:\(event["reply_id"]?.text ?? ""):\(block)"
            let existing = steps.firstIndex { $0.id == id }
            if type == "THINKING_BLOCK_END", existing == nil { return }
            let delta = type == "THINKING_BLOCK_DELTA" ? event["delta"]?.text : ""
            guard let delta else { return }
            if let existing {
                steps[existing].detail += delta
                if type == "THINKING_BLOCK_END" { steps[existing].status = "completed" }
            } else {
                steps.append(Step(id: id, title: "思考", detail: delta, status: "running"))
            }
        default:
            consumeTool(event, type: type)
        }
    }

    nonisolated mutating func consumeTool(_ event: AgentEventValue, type: String) {
        guard let callID = event.firstText("tool_call_id") else { return }
        let id = "tool:\(callID)"
        let index = steps.firstIndex { $0.id == id }
        if type == "TOOL_CALL_DELTA" || type == "TOOL_RESULT_TEXT_DELTA" {
            guard let index, let delta = event["delta"]?.text else { return }
            if type == "TOOL_CALL_DELTA", steps[index].status == "invoking" { steps[index].toolInput += delta }
            if type == "TOOL_RESULT_TEXT_DELTA", steps[index].isActive { steps[index].toolResult += delta }
            return
        }
        let status: String
        switch type {
        case "TOOL_CALL_START": status = "invoking"
        case "TOOL_CALL_END": status = "running"
        case "TOOL_RESULT_START": status = "receiving"
        case "TOOL_RESULT_END":
            switch event["state"]?.text?.lowercased() {
            case "success": status = toolResultStatus(index.map { steps[$0].toolResult } ?? "")
            case "error": status = "failed"
            default: status = "unconfirmed"
            }
        default: return
        }
        func phase(_ status: String?) -> Int {
            switch status {
            case "invoking": return 0
            case "running": return 1
            case "receiving": return 2
            default: return 3
            }
        }
        if let index, phase(status) <= phase(steps[index].status) { return }
        let name: String
        switch event["tool_call_name"]?.text {
        case "read_skill_resource": name = "读取规则文档"
        case "query_crm_customer_segments", "query_crm_segments": name = "查询客户分群"
        case "list_customer_profiles": name = "查询客户画像"
        case "get_daily_crm_work": name = "查询今日 CRM 工作"
        case .some: name = "其他工具"
        case nil: name = ""
        }
        if let index {
            steps[index].status = status
            if !name.isEmpty { steps[index].detail = name }
        } else {
            closeRawThinking()
            steps.append(Step(id: id, title: "调用工具", detail: name, status: status))
        }
    }

    nonisolated func toolResultStatus(_ text: String) -> String {
        guard let data = text.data(using: .utf8), let result = try? JSONDecoder().decode(AgentEventValue.self, from: data) else {
            return "success"
        }
        if result["data"]?["hasMore"] == .bool(true) { return "partial" }
        if case .array(let missing) = result["meta"]?["missingSources"], !missing.isEmpty { return "partial" }
        if result["data"]?["total"] == .number(0) { return "empty" }
        return "success"
    }
}

private extension AgentEventValue {
    nonisolated func firstText(_ keys: String...) -> String? {
        keys.compactMap { self[$0]?.text }.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    nonisolated func firstIdentifier(_ keys: String...) -> String? {
        for key in keys {
            if let text = self[key]?.text { return text }
            if case .number(let number) = self[key] { return NSDecimalNumber(decimal: number).stringValue }
        }
        return nil
    }
}
