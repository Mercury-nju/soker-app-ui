type Trade = "renovation" | "cancellation";
type Project = "new" | "used" | "partial";
type Phase = "intake" | "calibration" | "feedback" | "authorization" | "business_question" | "contact_pending" | "continuation" | "monitoring" | "reauthorization" | "done";
type LeadPreference = "phone" | "wechat" | "either";
type BusinessSource = { url: string; kind: "audience" | "business" | "unclassified" };
type ServiceNote = "full" | "half" | "partial";
export const mockQuota = 3;

type Brief = {
  trade?: Trade;
  city?: string;
  serviceCity?: string;
  namedBusiness?: boolean;
  namedAudience?: boolean;
  areas: string[];
  exclusions: string[];
  project?: Project;
  excludedProjects: Project[];
  budget?: [number, number];
  onlyUncontracted?: boolean;
  needsAppointment?: boolean;
};

type Prospect = {
  name: string;
  area: string;
  source: string;
  when: string;
  quote: string;
  rationale: string;
  outreach: string;
  handle: string;
  project?: Project;
  budget?: number;
  uncontracted?: boolean;
  appointmentIntent?: boolean;
};

type SearchCounts = { accounts: number; works: number; liveMessages: number; comments: number };
type ProspectReview = {
  name: string;
  avatar: string;
  profile: string;
  quote: string;
  source: string;
  rationale: string;
  counts: SearchCounts;
  refined: boolean;
};

export type DemoState = {
  phase: Phase;
  brief: Brief;
  prospect?: Prospect;
  account?: string;
  outreachAuthorized?: boolean;
  excludedProspects: string[];
  calibrated: boolean;
  reviewDeferred?: boolean;
  scopeAsked?: boolean;
  consultationAsked?: boolean;
  businessMaterialsAsked?: boolean;
  preferenceAsked?: boolean;
  pendingSearchReply?: string;
  pendingReview?: ProspectReview;
  searchCounts?: SearchCounts;
  businessSources?: BusinessSource[];
  serviceNote?: ServiceNote;
  leadPreference?: LeadPreference;
  measurementPolicy?: string;
  authorizationStep?: "qr" | "verification";
  authorizationRecovered?: boolean;
  simulateAuthorizationLoss?: boolean;
  delivered: number;
  quota: number;
};

export type DeliveredCustomer = {
  avatar: string;
  id: string;
  name: string;
  need: string;
  contact: string;
  source: string;
  nextAction: string;
};

export type DemoAuthorizationAction = "scan" | "scan_requires_verification" | "verified";
type DemoTurn = {
  state: DemoState;
  activity: string[];
  reply: string;
  delivery?: DeliveredCustomer;
  review?: ProspectReview;
  authorization?: "qr" | "verification" | "restored";
};

export const initialDemoState: DemoState = {
  phase: "intake",
  brief: { areas: [], exclusions: [], excludedProjects: [] },
  excludedProspects: [],
  calibrated: false,
  delivered: 0,
  quota: mockQuota,
};

const scenarios: Record<Trade, { city: string; prospects: Prospect[] }> = {
  renovation: {
    city: "上海",
    prospects: [
      {
        name: "小乔的新家",
        area: "浦东",
        source: "《浦东新房半包报价，哪些容易漏算》评论区",
        when: "昨天",
        quote: "浦东 88 平，上周刚交房。准备下个月动工，两家半包报价差不少，还在选。想这周末约量房，半包预算大概 12 万。",
        rationale: "本人刚收房，有开工时间，还在比较两家报价，已经主动问怎么约量房。",
        outreach: "两份半包报价先核对拆改、水电和防水是不是都算了。水电尤其要看是按点位、米数还是一口价。量房后让两家按同一份工程量清单报，更容易看出价差。",
        handle: "DEMO_PD_01",
        project: "new",
        budget: 12,
        uncontracted: true,
        appointmentIntent: true,
      },
      {
        name: "浦东阿遥",
        area: "浦东",
        source: "「浦东新房装修答疑」直播间留言",
        when: "今天",
        quote: "浦东 106 平新房刚交付，还没签装修公司，打算下月开工。两家报价的水电和柜体差很多，整装预算 22 万，想再约一家量房。",
        rationale: "本人刚交房，还没签约，整装预算和开工时间明确，已经主动提出约量房。",
        outreach: "比较整装报价时，把水电增项和柜体计价口径单独列出来。两家按同一份清单报价，就能看清哪些是总价差、哪些是漏项。",
        handle: "DEMO_PD_02",
        project: "new",
        budget: 22,
        uncontracted: true,
        appointmentIntent: true,
      },
      {
        name: "浦东新居小陈",
        area: "浦东",
        source: "《浦东新房交付后怎么约量房》评论区",
        when: "今天",
        quote: "浦东 92 平刚交付，下个月想开工，预算 24 万。还在比全屋方案，周内能来量房吗？",
        rationale: "本人未定施工方，装修时间、预算和量房需求都明确。",
        outreach: "两份方案最好按同一份平面图聊，先把水电、收纳柜和拆改的工程量列出来。上门量房时可以一起核一下。",
        handle: "DEMO_PD_03",
        project: "new",
        budget: 24,
        uncontracted: true,
        appointmentIntent: true,
      },
      {
        name: "浦东小陆",
        area: "浦东",
        source: "《浦东毛坯房开工前要做哪些准备》评论区",
        when: "今天",
        quote: "刚拿到浦东 98 平毛坯房，想在下个月进场，整装预算 26 万。还没签公司，想先约人上门看现场。",
        rationale: "毛坯新房还没签施工方，预算和开工时间明确，并主动提出约上门。",
        outreach: "进场之前可以先核对户型和想保留的结构，再按你打算入住的时间往前排工期。你手头方便看平面图吗？",
        handle: "DEMO_PD_04",
        project: "new",
        budget: 26,
        uncontracted: true,
        appointmentIntent: true,
      },
      {
        name: "闵行开工日记",
        area: "闵行",
        source: "《闵行二手房翻新，拆改怎么做预算》评论区",
        when: "今天",
        quote: "闵行 76 平二手房，下个月拿钥匙准备全屋翻新，全包想控制在 18 万。看了两家，想再约一家现场看一下。",
        rationale: "本人要翻新二手房，交接时间和预算明确，还在比较服务商，愿意约现场。",
        outreach: "二手房全包先把拆除清运、基层修复和水电更换列出来，现场看完才能知道哪几项要动。拿这份清单再对比两家，报价才在一个口径上。",
        handle: "DEMO_MH_01",
        project: "used",
        budget: 18,
        uncontracted: true,
        appointmentIntent: true,
      },
      {
        name: "闵行新家小林",
        area: "闵行",
        source: "「闵行毛坯交付怎么准备」直播间留言",
        when: "今天",
        quote: "闵行 101 平毛坯房月底交付，想做整装，预算 24 万。问过两家还没定，拿到钥匙就想约量房。",
        rationale: "刚要收房，预算明确，尚未签约，愿意约上门量房。",
        outreach: "可以先对照户型图把想保留的房间布局、柜体和水电都列出来，等拿到钥匙，上门核完尺寸再把它们放在同一份报价里。",
        handle: "DEMO_MH_02",
        project: "new",
        budget: 24,
        uncontracted: true,
        appointmentIntent: true,
      },
      {
        name: "闵行阿青",
        area: "闵行",
        source: "《闵行新房整装报价怎么看》评论区",
        when: "今天",
        quote: "闵行 112 平毛坯已经交房，整装预算 28 万，想下月初开工。之前聊的一家水电没写清，想另约一家上门。",
        rationale: "本人已经交房，预算和开工时间明确，主动询问新的上门时间。",
        outreach: "水电可以先问清哪些按实测算、哪些含在报价里。上门确认点位以后，我可以把这部分和柜体分开列给你核对。",
        handle: "DEMO_MH_03",
        project: "new",
        budget: 28,
        uncontracted: true,
        appointmentIntent: true,
      },
      {
        name: "嘉定小满",
        area: "嘉定",
        source: "《厨卫翻新避坑，预算该算哪些》评论区",
        when: "昨天",
        quote: "嘉定自住房，只改厨卫不改全屋，预算 6 万左右。已经问了一家，想再找一家现场看下怎么改。",
        rationale: "本人要局部改厨卫，服务地点和预算明确，希望上门评估。",
        outreach: "厨卫局改先核对防水重做范围、给排水要不要改，以及做完需要停用几天。现场确认这几项后再定施工范围和预算。",
        handle: "DEMO_JD_01",
        project: "partial",
        budget: 6,
        uncontracted: true,
        appointmentIntent: true,
      },
    ],
  },
  cancellation: {
    city: "深圳",
    prospects: [
      {
        name: "南山小周",
        area: "南山",
        source: "《深圳公司停止经营后，注销先查什么》评论区",
        when: "今天",
        quote: "我在深圳南山，公司停了几个月，想这周开始注销。之前的申报记录不确定，有人能先帮我看一下再报代办费吗？",
        rationale: "本人想本周办理公司注销，需要先核对申报状态，再比较代办费用。",
        outreach: "代办前可以先核对最近一次申报记录和发票状态。把现状问清再报，比较容易看明白费用包含哪些步骤。手头有最近一次申报记录吗？",
        handle: "DEMO_NS_01",
      },
      {
        name: "南山阿宁",
        area: "南山",
        source: "「深圳停业公司的注销流程」直播间留言",
        when: "今天",
        quote: "南山公司停了半年，想在下个月之前办完注销。之前开过票，想问申报记录要从哪查，代办是怎么收费的？",
        rationale: "本人有明确截止日期，在问办理前要核对的材料和代办费用。",
        outreach: "先整理最后一次申报和开票记录，代办报价再分成补申报和注销两块看。你手边有上一份申报回执吗？",
        handle: "DEMO_NS_02",
      },
      {
        name: "南山小江",
        area: "南山",
        source: "《停业公司申请注销前先看这几份记录》评论区",
        when: "今天",
        quote: "南山的公司已经停业，想尽快办完注销。手上只有去年的资料，有人能先帮忙看下还缺哪些吗？",
        rationale: "本人已经停业，主动寻求材料核对，有明确的注销需求。",
        outreach: "先看最近一期申报和开票记录，确认有无遗漏，再列出要补的材料。手上那份资料是哪一期的？",
        handle: "DEMO_NS_03",
      },
    ],
  },
};

const cities = /上海|深圳|杭州|苏州|北京|广州|成都|重庆|南京|宁波|武汉|天津|西安|东莞|佛山/;
const areaNames = /浦东(?:新区)?|闵行|嘉定|徐汇|静安|宝山|松江|青浦|杨浦|普陀|虹口|长宁|奉贤|金山|崇明|黄浦|南山|福田|罗湖|龙岗|宝安|光明|坪山|龙华|盐田/g;
const shenzhenAreas = /南山|福田|罗湖|龙岗|宝安|光明|坪山|龙华|盐田/;
const projectPatterns: [Project, RegExp][] = [
  ["partial", /局改|局部|厨卫|卫生间|厨房/],
  ["used", /老房|旧房|二手房|旧改/],
  ["new", /新房|交房|交付|毛坯|收房/],
];
const projectNames: Record<Project, string> = {
  new: "刚交房、准备装修的新房业主",
  used: "准备翻新老房或二手房的业主",
  partial: "准备做局部翻新的业主",
};

function detectTrade(text: string): Trade | undefined {
  for (const clause of text.split(/[，,。；;！？\n]|但|改做/).reverse()) {
    if (/(?:不|别|暂停)(?:再)?(?:做|接|找)/.test(clause)) continue;
    if (/注销/.test(clause)) return "cancellation";
    if (/装修|家装|装潢|设计施工|量房|全屋|半包|全包|翻新|局改/.test(clause)) return "renovation";
  }
}

function readBudget(text: string, previous?: Brief["budget"]): Brief["budget"] {
  if (/不限预算|预算不限|取消预算/.test(text)) return undefined;
  const range = text.match(/(\d+(?:\.\d+)?)\s*万?\s*(?:到|至|[-～—])\s*(\d+(?:\.\d+)?)\s*万/);
  if (range) return [Number(range[1]), Number(range[2])];
  const floor = text.match(/(?:至少|不低于|起码|最低|超过|高于)\s*(\d+(?:\.\d+)?)\s*万/);
  if (floor) return [Number(floor[1]), Infinity];
  const amount = text.match(/(?:预算|报价|造价)?\s*(\d+(?:\.\d+)?)\s*万(?:元)?\s*(起|以上|以内|以下|左右)?/);
  if (!amount) return previous;
  const value = Number(amount[1]);
  if (amount[2] === "起" || amount[2] === "以上") return [value, Infinity];
  if (amount[2] === "左右") return [value * 0.85, value * 1.15];
  return [0, value];
}

function refineBrief(previous: Brief, text: string): Brief {
  const trade = detectTrade(text) ?? previous.trade;
  const current = previous.trade && trade !== previous.trade ? initialDemoState.brief : previous;
  const namedCity = Array.from(text.matchAll(new RegExp(cities.source, "g"))).at(-1)?.[0];
  const explicitScope = text.match(/(?:只(?:做|接|服务|覆盖|在)|仅(?:限|接|在|服务))[^，,。；;！？\n]*/)?.[0]?.match(cities)?.[0];
  const targetCity = text.match(/(?:改找|想找|帮我找|只找|客户在|目标是|找)([^，,。；;！？\n]+)/)?.[1]?.match(cities)?.[0];
  const scopeResolved = Boolean(current.city && current.serviceCity && current.city !== current.serviceCity && namedCity && !targetCity);
  const cityChanged = Boolean(namedCity && current.city && namedCity !== current.city);
  const allAreas = /(?:全(?:上海|深圳|市)|全城|不限(?:区|地区)|各区都|区都可以)/.test(text);
  const areas = new Set<string>();
  const exclusions = new Set(cityChanged || allAreas ? [] : current.exclusions);
  const excludedProjects = new Set(current.excludedProjects);
  let project = current.project;
  if (/全屋|整装/.test(text)) excludedProjects.add("partial");
  for (const clause of text.split(/[，,。；;！？!？\n]|但|改成|改找/)) {
    const negative = /不要|别找|排除|不接|不做|除外|不考虑|不找/.test(clause);
    for (const area of clause.match(areaNames) ?? []) {
      const name = area.replace(/新区$/, "");
      if (negative) exclusions.add(name);
      else {
        areas.add(name);
        exclusions.delete(name);
      }
    }
    const projectMatch = projectPatterns.find(([, pattern]) => pattern.test(clause))?.[0];
    if (!projectMatch) continue;
    if (negative) {
      excludedProjects.add(projectMatch);
      if (project === projectMatch) project = undefined;
    } else {
      project = projectMatch;
      excludedProjects.delete(projectMatch);
    }
  }
  const impliedCity = areas.size ? ([...areas].some(area => shenzhenAreas.test(area)) ? "深圳" : "上海") : undefined;
  const city = targetCity ?? explicitScope ?? namedCity ?? impliedCity ?? current.city;
  const expandsArea = city === current.city && /再加|加上|也(?:能|可以|接|做|跑)|扩大到/.test(text);
  const selectedAreas = allAreas ? []
    : areas.size ? [...new Set([...(expandsArea ? current.areas : []), ...areas])] : city === current.city ? current.areas : [];
  return {
    trade, city, areas: selectedAreas,
    serviceCity: explicitScope ?? (scopeResolved ? namedCity : current.serviceCity),
    namedBusiness: current.namedBusiness || /(?:我(?:们)?|本店|公司).{0,8}(?:做|卖|主营|从事|提供)|财税|工商代办/.test(text),
    namedAudience: current.namedAudience || /(?:找|目标客户|客户是|客户主要是).{0,35}(?:业主|客户|潜客|负责人|老板|人|企业|商家)/.test(text),
    exclusions: [...exclusions], project, excludedProjects: [...excludedProjects],
    budget: readBudget(text, current.budget),
    onlyUncontracted: current.onlyUncontracted || /没(?:有)?签|未签|还(?:在|没)(?:选|定)|已经签(?:约|单)的.{0,5}(?:不|别|排除)/.test(text),
    needsAppointment: current.needsAppointment || /只(?:要|找).{0,8}(?:约|量房)|愿意.{0,5}(?:约|量房)|只比价.{0,6}(?:不要|不接|不找)/.test(text),
  };
}

function reply(state: DemoState, activity: string[], message: string): DemoTurn {
  return { state, activity, reply: message };
}

const sourceLink = /https?:\/\/[^\s，,。；;！？、（）<>]+/g;
const audienceSource = /目标客户|目标用户|客户主页|用户主页|参考账号|参考主页|这类客户|这类人/;
const businessSource = /商品|店铺|门店|案例|服务|产品|业务|自家|我(?:们)?的|(?:我们|我|本店).{0,8}(?:做|提供|卖|主营)/;
const leadPreferenceLabels = { phone: "手机号", wechat: "微信", either: "手机号或微信" } as const;
const storeProfileFixture = "https://www.douyin.com/user/DEMO_QINGHE";
const services = {
  full: { scope: "全屋整装", outreach: "我们主要做全屋整装，可以量完房后把这几项按同一份清单列给你。" },
  half: { scope: "半包和上门量房", outreach: "我们做半包，也可以先上门量房，按你家的实际工程量把报价列清楚。" },
  partial: { scope: "厨卫局部改造", outreach: "我们有厨卫局部改造服务，可以先看现场，再跟你确认哪些项目确实需要做。" },
} as const;

function readLeadPreference(text: string): LeadPreference | undefined {
  if (/[？?]|没想好|拿不准|(?:没有|暂无|没提供|联系不上)(?:手机|电话|微信)/.test(text)) return;
  if (/^(?:都可以|都行|都可|都接受|任选|随客户|无偏好|不限|任意|对方方便就好)$/.test(text)) return "either";
  const phone = /手机(?:号(?:码)?)?|电话(?:号码)?/.test(text);
  const wechat = /微信|VX/i.test(text);
  if (!phone && !wechat) return;
  if (phone && wechat) {
    if (/(?:不想|不要|不方便)(?:要|留|收)?微信|(?:手机号|电话)(?:优先|为主)|(?:优先|倾向|只要|先拿)(?:收集|拿到|拿|要|留)?(?:手机号|电话)/.test(text)) return "phone";
    if (/(?:不想|不要|不方便)(?:要|留|收)?(?:手机|电话)|微信(?:优先|为主)|(?:优先|倾向|只要|先拿)(?:收集|拿到|拿|要|留)?微信/.test(text)) return "wechat";
    return "either";
  }
  const expressesPreference = /^(?:手机(?:号(?:码)?)?|电话(?:号码)?|微信|VX)$/i.test(text)
    || /希望|倾向|优先|偏好|只要|留资|线索|留给|拿到|留个|留一下|留手机|留微信|给我|可以|都行|即可|为主/.test(text);
  if (expressesPreference) return phone ? "phone" : "wechat";
}

function collectConsultation(state: DemoState, text: string) {
  const businessSources = [...(state.businessSources ?? [])];
  let leadPreference = state.leadPreference;
  let serviceNote = state.serviceNote;
  const taskClauses: string[] = [];
  for (const part of text.split(/[，,。；;！!\n]+/)) {
    const links = part.match(sourceLink) ?? [];
    const clause = part.replace(sourceLink, "").trim();
    const kind = audienceSource.test(clause) ? "audience" : businessSource.test(clause) ? "business" : "unclassified";
    for (const url of links) {
      const index = businessSources.findIndex(source => source.url === url);
      if (index < 0) businessSources.push({ url, kind });
      else if (businessSources[index].kind === "unclassified" && kind !== "unclassified") businessSources[index] = { url, kind };
      // This link represents a local storefront fixture. Other URLs are retained as user context.
      if (url === storeProfileFixture && kind === "business" && !serviceNote) serviceNote = "half";
    }
    const explicitChannel = /手机|电话|微信|VX/i.test(clause);
    const preference = explicitChannel || (state.consultationAsked && !leadPreference
      && (state.phase === "intake" || state.phase === "calibration" || state.phase === "monitoring"))
      ? readLeadPreference(clause) : undefined;
    if (preference) leadPreference = preference;
    const offeredService = clause.match(/(?:(?:我(?:们)?|本店).{0,8}|主要)(?:做|主营|提供|能接)(全屋|整装|全包|半包|厨卫翻新|厨卫局改|局部改造)/)?.[1];
    if (offeredService) serviceNote = /半包/.test(offeredService) ? "half" : /厨卫|局部/.test(offeredService) ? "partial" : "full";
    const onlyPreference = preference && !/装修|家装|注销|量房|找(?:到|一下)?(?:\d+|客户|业主|潜客)|联系本轮|用.*抖音号|私信|[周星期明后][一二三四五六日天下午上]/.test(clause);
    const onlySource = links.length && !/接|主营|提供|想找|帮我找|(?:我们|我|本店).{0,6}(?:做|卖)/.test(clause);
    const skipsSources = /^(?:(?:暂时|手头|目前|先)?(?:没有|没|不发|不提供)|稍后补|以后再发)(?:什么|相关|能发的)?(?:资料|链接|参考账号|主页|商品链接)?$/.test(clause);
    if (clause && !onlyPreference && !onlySource && !skipsSources) taskClauses.push(clause);
  }
  return { businessSources, leadPreference, serviceNote, intent: taskClauses.join("，") };
}

function matchingProspects(state: DemoState, brief: Brief) {
  if (!brief.trade) return [];
  const scenario = scenarios[brief.trade];
  return (!brief.city || brief.city === scenario.city) ? scenario.prospects.filter(prospect =>
    !state.excludedProspects.includes(prospect.name)
    && (!brief.areas.length || brief.areas.includes(prospect.area))
    && !brief.exclusions.includes(prospect.area)
    && (!brief.project || brief.project === prospect.project)
    && (!prospect.project || !brief.excludedProjects.includes(prospect.project))
    && (!brief.onlyUncontracted || prospect.uncontracted)
    && (!brief.needsAppointment || prospect.appointmentIntent)
    && (!brief.budget || Boolean(prospect.budget && brief.budget[0] <= prospect.budget
      && brief.budget[1] >= prospect.budget))) : [];
}

function search(state: DemoState, brief: Brief, feedback?: string): DemoTurn {
  const next: DemoState = { ...state, phase: "intake", brief, prospect: undefined, pendingReview: undefined };
  if (!brief.trade) {
    return reply(next, ["理解你想找的人"], brief.namedBusiness
      ? "你说的业务我收到了。当前演示样本覆盖上海家装和深圳公司注销。你的业务里有这两项吗？说说你想先做哪项。"
      : "你主要做什么业务？告诉我你提供的产品或服务，我再判断哪些话能看出对方现在就需要它。");
  }
  if (brief.city && brief.serviceCity && brief.city !== brief.serviceCity) {
    return reply(next, ["核对客户范围与服务范围"], "你希望找" + brief.city + "的客户，也提到只服务" + brief.serviceCity + "。这轮按哪个城市找？");
  }
  if (!brief.namedBusiness) {
    return reply(next, [], "你主要做什么业务？");
  }
  if (!brief.namedAudience) {
    return reply(next, [], "你想找哪类客户？");
  }

  const matches = matchingProspects(state, brief);
  const previousCounts = state.searchCounts;
  // Each search adds a batch of activity from the demo fixtures.
  const counts = {
    accounts: (previousCounts?.accounts ?? 0) + 12,
    works: (previousCounts?.works ?? 0) + 31,
    liveMessages: (previousCounts?.liveMessages ?? 0) + 64,
    comments: (previousCounts?.comments ?? 0) + 103,
  };
  next.searchCounts = counts;

  const area = (brief.city ?? "") + brief.areas.join("、");
  const target = brief.trade === "renovation"
    ? (brief.project ? projectNames[brief.project] : "正在比较装修公司、近期要动工的业主")
    : "近期准备办理公司注销、正在查材料或问代办费的负责人";
  const signals = brief.trade === "renovation"
    ? (brief.project === "partial" ? "厨卫局改、现场评估、报价" : "准备动工、比较报价、约量房")
    : "停业、申报记录、注销代办";
  const activity = [
    feedback ? "按反馈调整筛选条件" : area ? "确认范围 · " + area : "按业务和目标客户开始筛选",
    ...(state.businessSources?.some(source => source.kind === "audience") ? ["记录目标用户主页，结合已说明的特征筛人"] : []),
    ...(state.serviceNote && brief.trade === "renovation" ? ["结合你提供的服务 · " + services[state.serviceNote].scope] : []),
    "从直播间和作品评论查近期需求 · " + signals,
    "排除纯围观，核对需求原话、出处与时间",
  ];
  const [prospect] = matches;
  const update = feedback ? "收到，接下来按「" + area + " · " + target + "」找。\n\n" : "";
  if (!prospect) {
    return reply({ ...next, phase: "monitoring" }, activity, update + (area ? "我会继续在「" + area + "」找" : "我会继续找") + target + "，有值得跟进的进展再告诉你。");
  }

  const evidence = [
    (next.calibrated ? "我又找到一位符合这套条件的人：" : "我先拿一位给你看：") + prospect.name + "。",
    "「" + prospect.quote + "」\n" + prospect.when + " · " + prospect.source,
    prospect.rationale,
  ].join("\n\n");
  if ((next.calibrated || next.reviewDeferred) && next.outreachAuthorized && next.account) {
    return beginOutreach({ ...next, prospect }, next.account, true, activity, update + evidence);
  }
  if (next.calibrated) {
    return reply({ ...next, phase: "authorization", prospect }, activity, update + evidence + "\n\n" + authorizationQuestion);
  }
  const profile = brief.trade === "renovation"
    ? [
      (brief.city ?? scenarios.renovation.city) + prospect.area + "业主",
      prospect.project ? projectNames[prospect.project] : undefined,
      prospect.budget ? "预算约 " + prospect.budget + " 万元" : undefined,
    ].filter(Boolean).join(" · ")
    : (brief.city ?? scenarios.cancellation.city) + prospect.area + " · 正在咨询公司注销";
  return {
    ...reply(
      { ...next, phase: "calibration", prospect },
      activity,
      "这位是你想找的那类客户吗？你可以告诉我哪里符合，或者哪点需要筛掉。我会继续找。",
    ),
    review: {
      name: prospect.name,
      avatar: `ENTCustomerAvatar${(Number(prospect.handle.slice(-2)) - 1) % 4 + 1}`,
      profile,
      quote: prospect.quote,
      source: prospect.when + " · " + prospect.source,
      rationale: prospect.rationale,
      counts,
      refined: Boolean(feedback),
    },
  };
}

const contactInstruction = /联系|私信|发(?:个|条)?消息|去聊|聊聊|问一下|触达/;
const negatedContact = /(?:不|别|暂缓|暂停|等等)[^，,。；;！？!?]{0,5}(?:联系|私信|发消息|聊|发|着急)|^(?:先等等|不行|不可以|暂缓|暂停|取消|不要|不同意|先放着|先不用)[。！!]?$/;
const confirmedContact = /^(?:好(?:的|啊|吧)?|可以(?:的)?|同意|授权|确认|行(?:的)?|没问题|去吧|发吧|继续)[。！!]?$/;
const authorizationQuestion = "这位暂时留在待联系名单。";
const negativeFit = /^(?:不对|不符合|不合适|不是|不要|不行|不太对|不太合适|偏了)|换(?:个|一位|一个)|(?:找|看看)下一位/;
const positiveFit = /^(?:对(?:了|的)?|没错|是的?|符合|合适|挺合适)(?:$|[。，,！\s]|这|就)|就是我(?:们)?(?:想|要)找的|^(?:这个人|这类人)可以/;
const feedbackQuestion = "具体是哪点不符合？说说你希望他具备什么条件，我按你的反馈重新筛一位给你看。";
const optionalReview = /先(?:不|不用)(?:确认|评价|反馈)|(?:不用|无需)(?:我)?确认|你先继续找/;
const taskScope = /本轮|这类|都可以|接着联系|符合.{0,8}(?:条件|标准)/;

function asksToRefine(text: string): boolean {
  return /改成|换成|重找|再找|改找|筛掉|排除|只做|只接|只找|都可以接|放宽|范围|预算|不要新房|不要老房|签约的|已签|只比价|量房意向/.test(text);
}

function reviseStrategy(state: DemoState, text: string): DemoTurn {
  const feedback = text.replace(/^(?:不对|不符合|不合适|不是这(?:种|类)人|不是|不太对|不太合适)[，,。！\s]*/, "").trim().replace(/[。！]+$/, "");
  if (!feedback || /^(?:换一个|换一位|找下一位|看看下一位|不知道|不确定)$/.test(feedback)) {
    return reply({ ...state, phase: "feedback" }, [], feedbackQuestion);
  }

  const brief = refineBrief(state.brief, feedback);
  if (JSON.stringify(brief) === JSON.stringify(state.brief)) {
    return reply({ ...state, phase: "feedback" }, [], feedbackQuestion);
  }
  const previous = state.prospect?.name;
  return search({
    ...state,
    calibrated: false,
    reviewDeferred: false,
    outreachAuthorized: false,
    excludedProspects: previous ? [...state.excludedProspects, previous] : state.excludedProspects,
  }, brief, feedback);
}

function updateRunningSearch(state: DemoState, text: string): DemoTurn | undefined {
  if (!asksToRefine(text) && !/再加|加上|也能跑|也可以接|只看|先找/.test(text)) return;
  const brief = refineBrief(state.brief, text);
  if (JSON.stringify(brief) === JSON.stringify(state.brief)) return;
  const currentMatches = state.prospect && matchingProspects(state, brief).some(prospect => prospect.handle === state.prospect?.handle);
  const hasPendingConversation = ["contact_pending", "business_question", "reauthorization"].includes(state.phase);
  if (hasPendingConversation && currentMatches) {
    return reply({ ...state, brief }, ["更新筛选条件"], "收到，新线索按这个条件找。" + state.prospect!.name + "也符合，我会接着跟进。");
  }
  return search({ ...state, pendingSearchReply: undefined, authorizationStep: undefined }, brief, text);
}

function beginOutreach(
  state: DemoState, account: string, taskAuthorization: boolean, activity: string[] = [], evidence?: string,
  resuming?: "business_question" | "reauthorization",
): DemoTurn {
  const prospect = state.prospect;
  if (!prospect) return reply(state, [], "");
  const next = { ...state, account, outreachAuthorized: taskAuthorization };
  if (state.simulateAuthorizationLoss && state.delivered > 0 && !state.authorizationRecovered) {
    return {
      ...reply({ ...next, phase: "reauthorization", authorizationStep: "qr" }, activity, [
        evidence,
        "抖音登录掉线了，我还没给" + prospect.name + "发消息。扫一下这张码恢复登录，我会接着跟进，找人也会继续。",
      ].filter(Boolean).join("\n\n")),
      authorization: "qr",
    };
  }
  if (prospect.handle === "DEMO_PD_02" && !state.measurementPolicy) {
    const question = "你们第一次上门量房收费吗？我怕有上门费，想先问清楚。";
    return reply({ ...next, phase: "business_question" },
      [...activity, "联系" + prospect.name, "收到量房费用问题"], [
        evidence,
        "我联系了" + prospect.name + "，她问：「" + question + "」",
        "你们在浦东首次上门量房怎么收费？我确认后再回她，这边会继续找其他符合条件的人。",
      ].filter(Boolean).join("\n\n"));
  }
  return reply(
    { ...next, phase: "contact_pending" },
    [...activity, "用" + account + "联系" + prospect.name, "接着对方的原话聊", "收到对方回复"],
    resuming === "reauthorization" ? "抖音登录已恢复，我继续联系了" + prospect.name + "。" : "",
  );
}

const authorizedDouyinAccount = "你已授权的抖音账号";

export function advanceDemoReauthorization(state: DemoState, action: DemoAuthorizationAction): DemoTurn | null {
  if (state.phase !== "reauthorization") return null;
  if (state.authorizationStep === "qr" && action === "scan_requires_verification") {
    return {
      ...reply({ ...state, authorizationStep: "verification" }, [], "扫码完成。抖音还需要验证绑定手机号，请在抖音的验证页面完成，我会接着跟进。"),
      authorization: "verification",
    };
  }
  if (!(state.authorizationStep === "qr" && action === "scan")
    && !(state.authorizationStep === "verification" && action === "verified")) return null;
  return {
    ...beginOutreach({ ...state, authorizationStep: undefined, authorizationRecovered: true },
      state.account ?? authorizedDouyinAccount, Boolean(state.outreachAuthorized), [], undefined, "reauthorization"),
    authorization: "restored",
  };
}

function givesOutreachInstruction(text: string) {
  return contactInstruction.test(text) && !negatedContact.test(text)
    && !/[？?]|怎么|为什么|能不能|应不应该|要不要|吗[。！!]?|建议|之后|回头|明天再/.test(text);
}

export function advanceDemo(state: DemoState, rawText: string): DemoTurn {
  const text = rawText.trim();
  if (!text) return reply(state, [], "");
  if (state.phase === "done") return advanceDemoIntent(state, text);

  const { intent, businessSources, leadPreference, serviceNote } = collectConsultation(state, text);
  const next = { ...state, businessSources, leadPreference, serviceNote };
  const additions: string[] = [];
  if (businessSources.length > (state.businessSources?.length ?? 0)) {
    additions.push(serviceNote && serviceNote !== state.serviceNote
      ? "业务资料收到了。我会结合你的" + services[serviceNote].scope + "服务找人，跟业主聊的时候也从能帮上的事说起。"
      : "链接收到了。我先按你已经说清楚的目标和业务条件找。");
  }
  if (leadPreference && leadPreference !== state.leadPreference) {
    additions.push("明白，后续约好下一步时，我会" + (leadPreference === "either" ? "请客户选留手机号还是微信。" : "优先请客户留" + leadPreferenceLabels[leadPreference] + "。"));
  }
  if (state.pendingSearchReply && state.preferenceAsked && !leadPreference && /没想好|没决定|拿不准|不确定/.test(text)) {
    return reply(next, [], "好，留电话还是微信可以晚点再定。我先按你说的范围找，筛到合适的人再给你看。");
  }

  const updatedScope = state.pendingSearchReply && !state.brief.city && intent
    ? refineBrief(state.brief, intent)
    : undefined;
  const turn = updatedScope?.city
    ? search({ ...next, pendingSearchReply: undefined }, updatedScope)
    : state.pendingSearchReply
    ? releaseSearchReply(next)
    : intent ? advanceDemoIntent(next, intent) : reply(next, [], "");

  if (turn.state.phase === "calibration" || turn.state.phase === "monitoring") {
    const question = nextConsultationQuestion(turn.state);
    if (state.phase === "intake") {
      const { city, areas, trade } = turn.state.brief;
      const area = (city ?? "") + areas.join("、");
      const target = trade === "renovation"
        ? "最近在比较装修报价、准备开工的业主"
        : "最近在咨询公司注销的负责人";
      return reply({ ...turn.state, pendingSearchReply: turn.reply || undefined, pendingReview: turn.review }, [],
        [...additions, "好，我现在就帮你找" + area + target + "。"].join("\n\n"));
    }
    if (question) {
      return reply({ ...question.state, pendingSearchReply: turn.reply || undefined, pendingReview: turn.review }, turn.activity,
        [ ...additions, question.reply ].join("\n\n"));
    }
  }

  return { ...turn, reply: [turn.reply, ...additions].filter(Boolean).join("\n\n") || (turn.state.phase === "contact_pending" ? "" : "好，我先按手头的信息继续。") };

}

function advanceDemoIntent(state: DemoState, text: string): DemoTurn {
  if (state.phase === "done") {
    return reply(state, [], "套餐额度已用完，获客已暂停。这期已交付 " + state.delivered + " 条线索。");
  }
  const canUpdateSearch = ["authorization", "business_question", "contact_pending", "continuation", "monitoring", "reauthorization"].includes(state.phase);
  if (canUpdateSearch) {
    const updated = updateRunningSearch(state, text);
    if (updated) return updated;
  }
  if (state.phase === "intake" || state.phase === "monitoring" || !state.prospect) {
    return search(state, refineBrief(state.brief, text));
  }
  const prospect = state.prospect;

  if (state.phase === "reauthorization") {
    const step = state.authorizationStep;
    return {
      ...reply(state, [], step === "verification"
        ? "请在抖音的验证页面完成手机号验证，完成后我接着跟进。"
        : "抖音登录仍待恢复，请扫对话里的二维码。我会留着这位潜客的进度。"),
      authorization: step,
    };
  }

  if (state.phase === "business_question") {
    if (/[？?]|不确定|不知道|还没|再问|再确认/.test(text) || !/免费|不收费|不收钱|不要钱|\d+\s*元|[一二两三四五六七八九十百]+元/.test(text)) {
      return reply(state, [], "这位客户想先确认量房费。你方便时告诉我是否收费，收费的话告诉我金额，我会按你的答复跟进。");
    }
    return beginOutreach({ ...state, measurementPolicy: text }, state.account ?? authorizedDouyinAccount,
      Boolean(state.outreachAuthorized), ["按你的答复告知量房收费规则"], undefined, "business_question");
  }

  if (state.phase === "calibration" || state.phase === "feedback") {
    if (optionalReview.test(text)) {
      if (givesOutreachInstruction(text)) {
        return beginOutreach({ ...state, reviewDeferred: true }, authorizedDouyinAccount, taskScope.test(text));
      }
      return reply(state, [], "好，我会按现有条件继续找。有哪点需要改，随时告诉我。");
    }
    if (!/[？?]|是不是|可不可以/.test(text) && !negativeFit.test(text)
      && (positiveFit.test(text) || confirmedContact.test(text) && state.phase === "calibration")) {
      if (negatedContact.test(text)) {
        return reply({ ...state, calibrated: true, phase: "authorization" }, [],
          "我会按这个方向继续找，先不联系这位。");
      }
      return beginOutreach({ ...state, calibrated: true }, authorizedDouyinAccount, true,
        ["沿用你确认的筛选方向"]);
    }
    if (state.phase === "feedback" || negativeFit.test(text) || asksToRefine(text)) return reviseStrategy(state, text);
    return reply(state, [], "你觉得" + prospect.name + "这种人符合吗？你也可以直接告诉我想改哪条筛选条件，我继续看留言。");
  }

  if (state.phase === "authorization") {
    if (negativeFit.test(text) && !negatedContact.test(text) || asksToRefine(text)
      || (!contactInstruction.test(text) && (cities.test(text) || detectTrade(text) || text.match(areaNames)?.length))) return reviseStrategy(state, text);
    if (negatedContact.test(text)) {
      return reply(state, ["保留潜客证据"], "好，先把" + prospect.name + "留在待联系名单。等你确认后，我再接着处理这位。");
    }
    const directsOutreach = givesOutreachInstruction(text);
    if (!directsOutreach && !confirmedContact.test(text)) {
      return reply(state, ["核对联系范围"], "这次只会联系" + prospect.name + "。你可以告诉我继续联系，也可以先告诉我哪些筛选条件要改。");
    }
    return beginOutreach(state, authorizedDouyinAccount, taskScope.test(text));
  }

  if (state.phase === "contact_pending") {
    return reply(state, [], "我正在等" + prospect.name + "回复是否愿意留联系方式。");
  }

  if (state.phase === "continuation") {
    return reply(state, [], prospect.name + "的线索已交付。我正在按同样的条件继续找。");
  }
  return reply(state, [], "");
}

function deliverContact(state: DemoState, prospect: Prospect): DemoTurn {
  const isRenovation = state.brief.trade === "renovation";
  const byPhone = state.leadPreference === "phone"
    || (state.leadPreference !== "wechat" && prospect.handle === "DEMO_MH_02");
  const channel = byPhone ? "手机号" : "微信";
  const contactAction = byPhone ? "打电话" : "加微信";
  const contactInfo = byPhone ? "100000000" + prospect.handle.slice(-2) : prospect.handle;
  const nextAction = contactAction + (isRenovation ? "先了解小区、户型和装修需求。" : "先了解公司的经营状态和申报情况。");
  const delivered = state.delivered + 1;
  const quotaExhausted = delivered >= state.quota;
  const status = quotaExhausted ? "套餐额度已用完，获客已暂停。" : "我正在继续找符合条件的人。";
  return {
    ...reply(
      { ...state, phase: quotaExhausted ? "done" : "continuation", delivered, excludedProspects: [...state.excludedProspects, prospect.name] },
      ["收到" + prospect.name + "同意留资的回复", "生成客户卡片"],
      status,
    ),
    delivery: {
      id: prospect.handle,
      avatar: `ENTCustomerAvatar${(Number(prospect.handle.slice(-2)) - 1) % 4 + 1}`,
      name: prospect.name,
      need: (state.brief.city ?? "") + prospect.area + " · " + prospect.rationale,
      contact: channel + " · " + contactInfo,
      source: prospect.when + " · " + prospect.source,
      nextAction,
    },
  };
}

function releaseSearchReply(state: DemoState): DemoTurn {
  return {
    ...reply({ ...state, pendingSearchReply: undefined, pendingReview: undefined }, [], state.pendingSearchReply ?? ""),
    review: state.pendingReview,
  };
}

function nextConsultationQuestion(state: DemoState): DemoTurn | null {
  if (!state.brief.city && !state.scopeAsked) {
    return reply({ ...state, scopeAsked: true }, [], state.brief.trade === "renovation"
      ? "我已经在帮你找了。为了优先筛出你能跟进的人，你平时在哪些地方可以上门？"
      : "为了优先筛出你能跟进的客户，你主要接哪些城市的业务？");
  }
  if (!state.consultationAsked && !state.businessSources?.some(source => source.kind === "audience")) {
    return reply({ ...state, consultationAsked: true }, [],
      "我会按刚才说的条件继续找。你手头有符合你目标的客户抖音主页吗？有的话发我一个，我可以参考它找相似的人。");
  }
  if (!state.businessMaterialsAsked && !state.businessSources?.some(source => source.kind === "business")) {
    return reply({ ...state, businessMaterialsAsked: true }, [],
      "你手头有商品或服务的介绍吗？链接或文件都可以。我想先了解你能帮客户解决什么，后面跟他们聊时就知道从哪儿说起。手头没有也没关系，我照常找。");
  }
  if (!state.preferenceAsked && !state.leadPreference) {
    return reply({ ...state, preferenceAsked: true }, [],
      "找到合适的人后，你更想拿到手机号还是微信？都可以也行。");
  }
  return null;
}

export function advanceDemoInBackground(state: DemoState): DemoTurn | null {
  if (state.pendingSearchReply && !state.preferenceAsked && (!state.leadPreference || !state.businessMaterialsAsked)
      && (state.consultationAsked || state.businessMaterialsAsked)) return null;
  if (state.phase === "calibration" || state.phase === "monitoring") {
    const question = nextConsultationQuestion(state);
    if (question) return question;
  }
  if (state.pendingSearchReply) {
    return releaseSearchReply(state);
  }
  if (state.phase === "contact_pending" && state.prospect) return deliverContact(state, state.prospect);
  if (state.phase === "continuation") return search(state, state.brief);
  return null;
}
