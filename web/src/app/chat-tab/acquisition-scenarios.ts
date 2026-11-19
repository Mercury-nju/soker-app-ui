type AcquisitionLead = {
  name: string;
  signal: string;
  quote: string;
  source: string;
  time: string;
};

type AcquisitionScenario = {
  kind: "matches" | "empty" | "partial";
  message: string;
  leads: AcquisitionLead[];
};

const fixtures: { match: RegExp; region: RegExp; lead: AcquisitionLead }[] = [
  {
    match: /注销/,
    region: /深圳/,
    lead: {
      name: "南山小周",
      signal: "深圳，本人正在询问公司注销代办",
      quote: "我在深圳的公司不经营了，想这周开始办注销，有人可以代办吗？",
      source: "作品评论 · 深圳公司注销需要准备什么",
      time: "昨天",
    },
  },
  {
    match: /门窗|换窗|隔音/,
    region: /不限|全国|宁波/,
    lead: {
      name: "临街卧室改造日记",
      signal: "宁波，本人正在了解换窗报价",
      quote: "我家在宁波，卧室临街太吵，想把窗换了，隔音窗怎么报价？",
      source: "作品评论 · 临街卧室换窗前后对比",
      time: "今天",
    },
  },
  {
    match: /劳动纠纷|劳动仲裁|辞退/,
    region: /杭州/,
    lead: {
      name: "阿杭",
      signal: "杭州，本人正在咨询辞退赔偿",
      quote: "我在杭州，被公司辞退没拿到赔偿，想找律师问一下。",
      source: "作品评论 · 被辞退后怎么申请劳动仲裁",
      time: "昨天",
    },
  },
  {
    match: /奥迪|A6L/i,
    region: /杭州/,
    lead: {
      name: "杭州看车笔记",
      signal: "杭州，本人近期准备提车，正在询价",
      quote: "我在杭州，这两周准备提 A6L，想问四驱落地多少。",
      source: "作品评论 · A6L 四驱落地价怎么比",
      time: "今天",
    },
  },
];

export function getAcquisitionScenario(query: string): AcquisitionScenario {
  if (/只看|只去|仅看|仅在|只在/.test(query) && /账号|抖音号|直播|https?:\/\/|@/.test(query)) {
    return {
      kind: "partial",
      message: "指定来源有一部分评论暂时无法读取。目前能看到的内容里，还没有确认有人正在找这项服务。你可以继续等这些来源有新内容，也可以告诉我能否扩大范围。",
      leads: [],
    };
  }

  if (!/只找|仅找|只要|预算|以内|以上|今天|刚刚|区县/.test(query)) {
    const leads = fixtures.filter(({ match, region }) => match.test(query) && region.test(query)).map(({ lead }) => lead);
    if (leads.length > 0) {
      return {
        kind: "matches",
        message: `这轮找到 ${leads.length} 位近期明确表达过本人需求的潜客。可以先看他们的原话和出处。`,
        leads,
      };
    }
  }

  return {
    kind: "empty",
    message: "这轮看过的内容里，暂时没有找到符合条件、近期明确表达本人需求的人。可以再等新的内容，也可以在这里告诉我哪些条件能放宽。",
    leads: [],
  };
}
