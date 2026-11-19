import Foundation

struct ENTMockAcquisitionFixture {
    enum AccountMode: String, CaseIterable, Identifiable {
        case none = "自动找来源"
        case reference = "参考账号"
        case specified = "指定采集"
        case both = "参考并采集"

        var id: String { rawValue }

        fileprivate var readsReference: Bool { self == .reference || self == .both }
        fileprivate var collectsFromAccount: Bool { self == .specified || self == .both }
    }

    struct Step: Identifiable {
        let title: String
        let summary: String
        let detail: String

        var id: String { title }
    }

    struct Lead: Identifiable {
        let id: String
        let name: String
        let comment: String
        let sourceTitle: String
        let sourceAccount: String
        let postedAt: String
        let rationale: String
        let context: String
    }

    let title: String
    let region: String
    let keywords: [String]
    let steps: [Step]
    let leads: [Lead]
    let emptyReason: String

    static func make(
        requirement: String,
        accountMode: AccountMode = .none,
        account: String = "",
        onlySpecified: Bool = false
    ) -> Self {
        let scenario = scenarios.first { $0.matches(requirement) }
        let accountName = account.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceName = accountName.isEmpty ? "示例账号" : accountName
        let scopeIsLimited = accountMode.collectsFromAccount && onlySpecified
        let keywords = scenario?.keywords ?? []
        let sampleLeads = scenario?.leads ?? []
        let leads = sampleLeads.enumerated().compactMap { index, lead -> Lead? in
            guard accountMode.collectsFromAccount, index == 0 else {
                let isReferenceOnlySource = accountMode == .reference && lead.sourceAccount == accountName
                return scopeIsLimited || isReferenceOnlySource ? nil : lead
            }
            return Lead(
                id: lead.id,
                name: lead.name,
                comment: lead.comment,
                sourceTitle: lead.sourceTitle,
                sourceAccount: sourceName,
                postedAt: lead.postedAt,
                rationale: lead.rationale,
                context: lead.context
            )
        }

        var steps: [Step] = []
        if accountMode.readsReference {
            let coverage: String
            if let scenario {
                let counts = [72, 28, 14, 9]
                let works = scenario.referenceWorks.enumerated().map { offset, title in
                    "\(offset + 1). \(title) · \(offset + 1) 天前 · 读完 \(counts[offset]) 条"
                }.joined(separator: "\n")
                coverage = "模拟样本已读完 123 条评论和回复。\n\(works)\n\n\(scenario.referenceClues)"
            } else {
                coverage = "本地没有与这个需求匹配的参考样本。"
            }
            steps.append(Step(
                title: "理解参考账号",
                summary: "查看 \(sourceName) 最近发布的 4 条作品",
                detail: "先看账号名称和简介，按发布时间取最新 4 条公开作品。读取作品标题、发布描述及全部可读取的评论和回复。归纳内容主题、受众原话和搜索表达。\n\n\(coverage)"
            ))
        }
        if scopeIsLimited {
            steps.append(Step(
                title: "确认采集范围",
                summary: "只在 \(sourceName) 下查找",
                detail: "按你指定的范围核验这个账号并查看相关作品评论。"
            ))
        } else {
            let summary = keywords.isEmpty
                ? "整理搜索方向"
                : keywords.joined(separator: " · ")
            let details = keywords.isEmpty
                ? "此需求没有匹配的本地案例，暂无能展开的搜索词。"
                : "按这些关键词查找抖音账号。模拟首页返回 10 条，去重后有 8 个账号，先核验 6 个，其余 2 个保留在待处理队列。"
            steps.append(Step(
                title: "查找相关来源",
                summary: summary,
                detail: accountMode.collectsFromAccount
                    ? "同时纳入你指定的 \(sourceName)。\n\n\(details)"
                    : details
            ))
        }
        let hasSample = !sampleLeads.isEmpty
        let coverage: String
        if scopeIsLimited {
            coverage = "只检查 \(sourceName) 的身份、相关性、可读性和可用采集位。"
        } else {
            coverage = "本批 6 个账号中，3 个通过，2 个待核验，1 个与业务无关。第一个通过的账号立即开始查看作品评论，后续账号继续核验。"
        }
        steps.append(Step(
            title: "核验来源账号",
            summary: hasSample ? "核对主页、作品和读取条件" : "等待可核验的来源",
            detail: hasSample ? coverage : "逐个检查主页、作品相关性、公开性和读取能力。资料不足的标记为待核验。"
        ))
        let workReadout: String
        if let lead = leads.first {
            workReadout = "\n\n模拟记录：\(lead.sourceAccount) 的《\(lead.sourceTitle)》进入采集。首批读到 60 条，其中有 1 条需复核的近期需求。继续翻页读取 18 条，当前作品的公开评论已读完。这个账号未开播，作品评论照常继续。"
        } else {
            workReadout = ""
        }
        steps.append(Step(
            title: "查看相关作品评论",
            summary: hasSample ? "按发布时间核对相关作品与原文" : "暂无可读取的作品样本",
            detail: "从最新作品往前检查，相关就入选，明确无关就跳过，最多选 4 条相关作品。首批读取 60 条评论，有符合条件的需求表达时继续翻页。保留作者、原话、出处和时间。\(workReadout)"
        ))
        let reviewed = leads.first.map { lead in
            "\n\n模拟记录：\(lead.name) 的留言发表于\(lead.postedAt)，已确认是本人需求，地区有原话支持。另有促销留言和没有明确需求的评论，均未进入结果。"
        } ?? ""
        steps.append(Step(
            title: "筛选高意向潜客",
            summary: leads.isEmpty ? "暂无符合条件的模拟线索" : "找到 \(leads.count) 个符合条件的模拟潜客",
            detail: "核对评论是否为本人表达、需求是否仍有效、是否匹配业务，以及硬条件是否有证据支持。同一个人的多条证据合并。\(reviewed)"
        ))

        return Self(
            title: scenario?.title ?? requirement,
            region: scenario?.region ?? "按原需求核对",
            keywords: scopeIsLimited ? [] : keywords,
            steps: steps,
            leads: leads,
            emptyReason: "本地样本中没有足够证据确认这条需求。可以补充你卖什么、客户正在解决的问题，或选择一个首页示例查看结果。"
        )
    }
}

private extension ENTMockAcquisitionFixture {
    struct Scenario {
        let title: String
        let region: String
        let matches: (String) -> Bool
        let keywords: [String]
        let referenceWorks: [String]
        let referenceClues: String
        let leads: [Lead]
    }

    static var scenarios: [Scenario] {
        [
            Scenario(
                title: "近期要买二手 SUV 的人",
                region: "杭州",
                matches: { $0.contains("杭州") && $0.contains("二手") && $0.localizedCaseInsensitiveContains("SUV") },
                keywords: ["杭州二手 SUV", "15 万二手 SUV", "杭州二手车周末看车"],
                referenceWorks: ["杭州二手 SUV 怎么挑", "十五万预算实车对比", "看车前先问什么", "周末到店记录"],
                referenceClues: "模拟样本里，主要讨论预算、车况和到店看车。有人问「十五万在杭州能看哪些二手 SUV」，可提炼出预算和本地看车两条方向。",
                leads: [
                    Lead(
                        id: "suv-1",
                        name: "山野阿诚",
                        comment: "人在杭州，预算 15 万以内，这周末想去看二手 RAV4 或 CR-V，有车况好的能看看吗？",
                        sourceTitle: "15 万预算怎么挑二手 SUV",
                        sourceAccount: "杭州车况笔记",
                        postedAt: "今天 10:24",
                        rationale: "本人明确说在杭州，有预算、车型备选和周末看车计划。",
                        context: "在讨论二手 RAV4 和 CR-V 的作品下留言。还需核实实际预算是否含过户和保险。"
                    ),
                    Lead(
                        id: "suv-2",
                        name: "栗子出行记",
                        comment: "杭州滨江，准备月底前买个二手 SUV 给家里用，12 万左右，哪里方便看实车？",
                        sourceTitle: "家庭用二手 SUV 看车清单",
                        sourceAccount: "杭州看车日记",
                        postedAt: "昨天 19:08",
                        rationale: "明确了杭州滨江、二手 SUV、预算和月底前购车的计划。",
                        context: "在家庭用车的选购作品下主动问实车。还需确认座位数和车况要求。"
                    )
                ]
            ),
            Scenario(
                title: "正在比较装修公司的业主",
                region: "上海",
                matches: { $0.contains("上海") && $0.contains("装修") && $0.contains("比较") },
                keywords: ["上海装修公司对比", "上海量房报价", "上海半包预算"],
                referenceWorks: ["半包报价有哪些增项", "88 平量房记录", "装修报价对比清单", "工地验收日记"],
                referenceClues: "模拟样本里，主要讨论量房、半包报价和增项。有人问「两家预算差了三万，怎么比」，可提炼出核对清单和量房两条方向。",
                leads: [
                    Lead(
                        id: "renovation-1",
                        name: "小乔的新家",
                        comment: "上海浦东，88 平已经交房，最近在比两家的半包报价。这周末还能约量房吗？",
                        sourceTitle: "上海半包报价怎么比较",
                        sourceAccount: "上海装修账本",
                        postedAt: "今天 09:45",
                        rationale: "已交房业主，正在比较报价，并明确提出周末量房。",
                        context: "在半包报价拆解下留言。还需确认预算和预计开工日期。"
                    ),
                    Lead(
                        id: "renovation-2",
                        name: "小屋开工簿",
                        comment: "上海闵行的二手房，下个月准备开工。手上有两家公司方案，想找一家再比一下全包清单。",
                        sourceTitle: "签装修合同前怎么核对清单",
                        sourceAccount: "沪上住家笔记",
                        postedAt: "昨天 21:13",
                        rationale: "本人有上海房屋项目，正在比较装修公司且有明确开工时间。",
                        context: "在全包项目清单作品下主动比较方案。还需确认房屋面积和施工范围。"
                    )
                ]
            ),
            Scenario(
                title: "正在给孩子挑英语课的家长",
                region: "深圳",
                matches: { $0.contains("深圳") && $0.contains("英语") && $0.contains("家长") },
                keywords: ["深圳少儿英语体验课", "深圳小学英语课程对比", "深圳周末英语小班"],
                referenceWorks: ["一年级零基础怎么选课", "周末英语小班实录", "试听课要问什么", "少儿英语课程对比"],
                referenceClues: "模拟样本里，常见问题是年龄分班、试听和周末排课。有人问「一年级零基础试听怎么约」，可提炼出年龄和试听两条方向。",
                leads: [
                    Lead(
                        id: "english-1",
                        name: "橙子家长",
                        comment: "深圳南山，一年级零基础，最近在挑英语小班。这周末能先试听一次吗？",
                        sourceTitle: "小学英语小班试听看什么",
                        sourceAccount: "深圳亲子课程笔记",
                        postedAt: "今天 11:06",
                        rationale: "家长描述了地区、孩子学习阶段和当前选课动作，并主动问试听。",
                        context: "在试听建议作品下留言。还需确认可到店区域和英语课目标。"
                    ),
                    Lead(
                        id: "english-2",
                        name: "周末慢慢来",
                        comment: "深圳福田，孩子三年级，最近比较两家英语课。我们平时没空，想看看周六班怎么排。",
                        sourceTitle: "深圳周末英语班怎么挑",
                        sourceAccount: "深圳家长周末记",
                        postedAt: "昨天 18:32",
                        rationale: "本人是深圳家长，正在比课，时间偏好明确。",
                        context: "在周末班作品下询问排课。还需核实课程预算和是否接受线上。"
                    )
                ]
            )
        ]
    }
}
