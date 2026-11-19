const businessQuestion = "你主要卖什么产品，或者提供什么服务？";
const targetQuestion = "你主要想找哪类客户？说说他们现在有什么需求就行。";

const genericBusiness = /^(?:生意|小生意|业务|服务|产品|咨询|咨询服务|项目|销售|营销|电商|公司|工作室|创业|实体店|开店)$/;
const genericTarget = /^(?:(?:潜在|意向|有需求的|精准|当地|本地|一些|更多|几个|一批|一下|附近的)*?(?:客户|顾客|客源|潜客|线索|用户|买家|老板|人群|人|合作伙伴)|找人|获客)$/;
const clauseBreak = /[，,。！？；;\n]/;
const businessStatement = /(?:^|[，,。！？；;\n])(?:我(?:们|家|公司)?|本人|本店|我们公司)?(?:主要|专门|目前|现在)?(?:在[^，,。！？；;\n]{1,12}?)?(?:销售|主营|提供|经营|专做|专卖|从事|做|卖|开|是)(?:的)?([^，,。！？；;\n]+?)(?=$|[，,。！？；;\n]|(?:想|希望|请|帮我|要)(?:帮我)?找)/;
const targetStatement = /(?:想(?:要)?找|希望(?:找到?|筛选)|帮(?:我|我们)?找|找一下|找一批|找|目标客户(?:是|为|[:：]))\s*([^，,。！？；;\n]+)/;
const beforeTarget = /(?:想(?:要)?找|希望(?:找到?|筛选)|帮(?:我|我们)?找|找一下|找一批|目标客户)/;
const indefiniteAnswer = /^(?:不清楚|不知道|还没想好|暂时没有|没有|随便|都行|都可以|看情况|你看着办|嗯|好|继续|开始)[。！!]?$/;
const unrestrictedScope = /不限(?:地区|地域)|不限制(?:地区|地域)|全国(?:都)?(?:可做|可接|可以|都行|服务)?/;
const cityNames = "北京|上海|天津|重庆|杭州|宁波|温州|南京|苏州|无锡|常州|成都|武汉|长沙|郑州|广州|深圳|佛山|东莞|惠州|珠海|厦门|福州|泉州|合肥|南昌|济南|青岛|西安|昆明|贵阳|南宁|太原|石家庄|沈阳|大连|哈尔滨|长春|香港|澳门";
const cityPattern = new RegExp(cityNames, "g");
const hardScopePattern = /(?:只(?:能|做|接|服务|限|覆盖|负责)|仅(?:限|在|服务)|不做外地|不接外地)[^，,。！？；;\n]*/;

function cityMentions(text: string): string[] {
  return [...new Set(text.match(cityPattern) ?? [])];
}

function businessDetail(text: string): string | undefined {
  const detail = text.match(businessStatement)?.[1]?.split(clauseBreak)[0]?.trim()
    .replace(/^(?:一个|一家|一名|一位|个|家)/, "")
    .replace(/(?:的业务|的生意)$/, "");
  return detail || undefined;
}

function explicitTarget(text: string): boolean {
  const target = text.match(targetStatement)?.[1]?.trim().replace(/(?:。|吧|就行|谢谢)$/g, "");
  if (!target) return false;
  const withoutLocation = target.replace(cityPattern, "").replace(/(?:本地|当地|附近|同城|市内|的)/g, "");
  return !!withoutLocation && !genericTarget.test(withoutLocation);
}

function readScope(text: string): string[] | undefined {
  if (unrestrictedScope.test(text)) return [];
  const hardScope = text.match(hardScopePattern)?.[0]?.split(beforeTarget)[0];
  const cities = cityMentions(hardScope ?? "");
  return cities.length ? cities : undefined;
}

function readTargetScope(text: string): string[] | undefined {
  const clauses = text.split(clauseBreak).filter(clause => !/(?:不|别|取消|不用)找/.test(clause));
  const target = clauses.map(clause => clause.match(targetStatement)?.[1]).filter(Boolean).at(-1);
  const cities = cityMentions(target ?? "");
  return cities.length ? cities : undefined;
}

function outsideScope(service: string[], target: string[]): string[] {
  return service.length ? target.filter(city => !service.includes(city)) : [];
}

function isSpecificCustomerAnswer(text: string): boolean {
  return explicitTarget(text) || /(?:正在|计划|准备|打算|考虑|需要|询价|咨询).+|有.+需求|(?:的)?(?:业主|卖家|买家|老板|家长|消费者|采购方|门店|企业|公司|家庭)$/.test(text)
    || /^(?:B2B|B2C|企业客户|个人客户)$/i.test(text);
}

/** Rules for the local prototype. Linked material is not fetched during mock intake. */
export function acquisitionQuestion(text: string): string | null {
  const [brief, ...answers] = text
    .replace(/https?:\/\/[^\s，。！？；;]+/g, "")
    .split(/[；;]\s*补充[:：]\s*/)
    .map(part => part.trim());

  let business = businessDetail(brief);
  let targetKnown = explicitTarget(brief);
  let serviceCities = readScope(brief) ?? [];
  let requestedCities = readTargetScope(brief) ?? [];

  for (const answer of answers) {
    if (!answer || indefiniteAnswer.test(answer)) continue;

    const hadBusiness = Boolean(business);
    const wasMissingTarget = Boolean(business && genericBusiness.test(business) && !targetKnown);
    const hadConflict = outsideScope(serviceCities, requestedCities).length > 0;
    const namedBusiness = businessDetail(answer);
    const namedService = readScope(answer);
    const namedTarget = readTargetScope(answer);

    if (namedBusiness) {
      business = namedBusiness;
    } else if (!hadBusiness && !namedService && !beforeTarget.test(answer) && !isSpecificCustomerAnswer(answer)) {
      business = answer.split(clauseBreak)[0].trim();
    }
    if (explicitTarget(answer) || (wasMissingTarget && !namedBusiness && isSpecificCustomerAnswer(answer))) {
      targetKnown = true;
    }

    if (namedService) {
      serviceCities = namedService;
      // A revised service scope may replace the impossible targeting scope under clarification.
      if (hadConflict && !namedTarget && outsideScope(serviceCities, requestedCities).length) {
        requestedCities = serviceCities;
      }
    }
    if (namedTarget) requestedCities = namedTarget;
    if (hadConflict && !namedService && !namedTarget) {
      const answerCities = cityMentions(answer);
      const relevantCities = [...serviceCities, ...requestedCities];
      if (answerCities.length && answerCities.every(city => relevantCities.includes(city))
          && !/[？?]|不确定|还没定|再想想|不做|不接|不服务|不找|不是/.test(answer)) {
        serviceCities = answerCities;
        requestedCities = answerCities;
      }
    }
  }

  const outside = outsideScope(serviceCities, requestedCities);
  if (outside.length) {
    return `你说只服务${serviceCities.join("、")}，也提到了找${outside.join("、")}的客户。这轮实际能服务哪些地区？`;
  }
  if (!business) return businessQuestion;
  if (!targetKnown && genericBusiness.test(business)) return targetQuestion;
  return null;
}
