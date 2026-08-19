// VENDORED FROM partridg3-shared-calc/calc-core.js - do not edit here, edit upstream and re-run sync.ps1.
// Synced 2026-08-19 18:20 @ 66b1e48.

/**
 * Partridg3 — canonical financial calculator core.
 *
 * Plain, dependency-free ES2020 JavaScript (JSDoc types, not TypeScript) so it
 * runs unmodified in `landing`'s zero-build vanilla-JS pages via a plain
 * `<script type="module">` tag, while still getting type-checking on the
 * Vite/Next platforms via `"allowJs": true` in their tsconfig.
 *
 * This is the single source of truth. Every platform gets a vendored copy of
 * this exact file (see sync.ps1) — do not fork or hand-edit a vendored copy;
 * edit this file and re-sync.
 *
 * Methodology: finite-term annuity, not perpetuity, for income-replacement
 * capital needs (Life Cover, Capital Disability, Retirement). A perpetuity
 * (AnnualNeed / r) overstates the need by 32–71% depending on horizon — it
 * assumes the income stream never ends, when in practice it only needs to
 * last until the dependants are self-sufficient / retirement age. The finite
 * annuity — PV = AnnualNeed × [(1 − (1+r)^−n) / r] — is the CFP Board
 * standard for this class of calculation. This decision was made once,
 * deliberately, on 2026-08-19, after finding the two models had silently
 * coexisted across different platforms for months. Do not reintroduce
 * perpetuity for these three calculators without a new, equally deliberate
 * decision.
 */

// ─── SARS Published Tax Parameters ───────────────────────────────────────────
// Source: National Treasury Budget 2025 / SARS Tax Tables. These are the
// actual published SARS rates, used as the primary source of truth.

/**
 * @typedef {Object} TaxBracket
 * @property {number} from
 * @property {number|null} to
 * @property {number} rate
 * @property {number} base_tax
 */

/**
 * @typedef {Object} TaxParams
 * @property {string} tax_year
 * @property {string} effective_date
 * @property {TaxBracket[]} brackets
 * @property {number} primary_rebate
 * @property {number} secondary_rebate
 * @property {number} tertiary_rebate
 * @property {number} medical_credit_main
 * @property {number} medical_credit_additional
 * @property {number} ra_deduction_rate
 * @property {number} ra_annual_cap
 * @property {number} tfsa_annual_limit
 * @property {number} tfsa_lifetime_limit
 * @property {number} interest_exemption_under65
 * @property {number} interest_exemption_over65
 * @property {number} cgt_annual_exclusion
 * @property {number} cgt_death_exemption
 * @property {number} cgt_inclusion_rate
 * @property {number} estate_duty_abatement
 * @property {number} estate_duty_rate_standard
 * @property {number} estate_duty_rate_high
 * @property {number} estate_duty_high_threshold
 * @property {number} executor_fee_rate
 * @property {number} executor_fee_vat
 * @property {number} dividend_withholding_tax
 * @property {string} [notes]
 */

/** @type {TaxParams} 2025/26 tax year — effective 1 March 2025. Brackets frozen (unchanged from 2024/25). */
export const SARS_2025_26 = {
  tax_year: '2025/26',
  effective_date: '2025-03-01',
  brackets: [
    { from: 0,        to: 237100,   rate: 0.18, base_tax: 0      },
    { from: 237100,   to: 370500,   rate: 0.26, base_tax: 42678  },
    { from: 370500,   to: 512800,   rate: 0.31, base_tax: 77362  },
    { from: 512800,   to: 673000,   rate: 0.36, base_tax: 121475 },
    { from: 673000,   to: 857900,   rate: 0.39, base_tax: 179147 },
    { from: 857900,   to: 1817000,  rate: 0.41, base_tax: 251258 },
    { from: 1817000,  to: null,     rate: 0.45, base_tax: 644489 },
  ],
  primary_rebate:   17235,
  secondary_rebate:  9444,
  tertiary_rebate:   3145,
  medical_credit_main:       364,
  medical_credit_additional: 246,
  ra_deduction_rate: 0.275,
  ra_annual_cap:     350000,
  tfsa_annual_limit:   36000,
  tfsa_lifetime_limit: 500000,
  interest_exemption_under65: 23800,
  interest_exemption_over65:  34500,
  cgt_annual_exclusion: 40000,
  cgt_death_exemption:  300000,
  cgt_inclusion_rate:   0.40,
  estate_duty_abatement:       3500000,
  estate_duty_rate_standard:   0.20,
  estate_duty_rate_high:       0.25,
  estate_duty_high_threshold:  30000000,
  executor_fee_rate: 0.035,
  executor_fee_vat:  0.15,
  dividend_withholding_tax: 0.20,
  notes: 'SARS 2025/26 — National Treasury Budget 2025. Effective 1 March 2025. Brackets frozen (unchanged from 2024/25).',
};

/**
 * @type {TaxParams} 2026/27 tax year — effective 1 March 2026.
 * Reconciled field-by-field against SARS's published rate table
 * (sars.gov.za/tax-rates/income-tax/rates-of-tax-for-individuals/) and Budget
 * 2026 on 2026-08-19, after a spot-check found the brackets and CGT exclusion
 * had been silently carried forward unchanged from 2025/26 (wrong — this was
 * the first inflation-linked bracket adjustment since 2023/24, +3.4%).
 * Fields NOT reconciled against a fresh 2026/27 source in this pass — carried
 * forward from 2025/26 as last-known values, flag if precision matters:
 * interest_exemption_under65/over65, cgt_death_exemption, cgt_inclusion_rate,
 * estate duty rates/thresholds/abatement (abatement separately confirmed
 * unchanged), executor_fee_rate/vat, dividend_withholding_tax.
 */
export const SARS_2026_27 = {
  ...SARS_2025_26,
  tax_year: '2026/27',
  effective_date: '2026-03-01',
  brackets: [
    { from: 0,        to: 245100,   rate: 0.18, base_tax: 0      },
    { from: 245100,   to: 383100,   rate: 0.26, base_tax: 44118  },
    { from: 383100,   to: 530200,   rate: 0.31, base_tax: 79998  },
    { from: 530200,   to: 695800,   rate: 0.36, base_tax: 125599 },
    { from: 695800,   to: 887000,   rate: 0.39, base_tax: 185215 },
    { from: 887000,   to: 1878600,  rate: 0.41, base_tax: 259783 },
    { from: 1878600,  to: null,     rate: 0.45, base_tax: 666339 },
  ],
  primary_rebate:   17820,
  secondary_rebate:  9765,
  tertiary_rebate:   3249,
  medical_credit_main:       376,
  medical_credit_additional: 254,
  tfsa_annual_limit: 46000,
  ra_annual_cap:     430000,
  cgt_annual_exclusion: 50000,
  notes: 'SARS 2026/27 — Budget 2026, effective 1 March 2026. Brackets/rebates +3.4% (first inflation-linked adjustment since 2023/24). TFSA limit R46 000; RA cap R430 000; CGT annual exclusion R50 000 (was R40 000 in 2025/26 — do not silently inherit this one).',
};

export const SARS_CURRENT = SARS_2026_27;

/**
 * @param {number} grossAnnual
 * @param {number} age
 * @param {TaxParams} tp
 */
export function calculateTax(grossAnnual, age, tp) {
  let taxBeforeRebates = 0;
  let marginalRate = 0;

  for (const b of tp.brackets) {
    const upper = b.to ?? Infinity;
    if (grossAnnual > b.from) {
      const inBracket = Math.min(grossAnnual, upper) - b.from;
      taxBeforeRebates = b.base_tax + inBracket * b.rate;
      marginalRate = b.rate;
    }
  }

  let totalRebates = tp.primary_rebate;
  if (age >= 65) totalRebates += tp.secondary_rebate;
  if (age >= 75) totalRebates += tp.tertiary_rebate;

  const totalTax = Math.max(0, taxBeforeRebates - totalRebates);
  const netAnnual = grossAnnual - totalTax;
  const raMaxDeductible = Math.min(grossAnnual * tp.ra_deduction_rate, tp.ra_annual_cap);
  const raTaxSaving = raMaxDeductible * marginalRate;
  const interestExemption = age >= 65 ? tp.interest_exemption_over65 : tp.interest_exemption_under65;
  const effectiveCgtRate = tp.cgt_inclusion_rate * marginalRate;

  return {
    grossAnnual,
    taxBeforeRebates,
    totalRebates,
    totalTax,
    netAnnual,
    netMonthly: netAnnual / 12,
    marginalRate,
    effectiveRate: grossAnnual > 0 ? totalTax / grossAnnual : 0,
    raMaxDeductible,
    raTaxSaving,
    interestExemption,
    effectiveCgtRate,
  };
}

// ─── Shared math primitives ───────────────────────────────────────────────────

/**
 * Present value of a finite n-year annuity at real rate r. This is the
 * canonical model for income-replacement capital — see file header.
 *
 * On the real-return rate `r` itself: adviser-app's own FNA defaults (4.5%
 * for life cover, 6%/3.5% drawdown for retirement — see fna/types.ts
 * defaults) are already sensibly conservative against the external evidence
 * (JSE All Share ~8.4% real over 90yrs since 1925, ~9.1% real over the 25yrs
 * to 2014; FSCA published fund returns 10.79%/8.41% nominal 1yr/5yr avg).
 * If a *nominal* growth/inflation pair (e.g. "10% growth / 6% inflation") is
 * found hardcoded as a default anywhere else in the platforms still to be
 * migrated (flagged during the 2026-08-19 actuarial review, not yet
 * pinpointed to a specific file), replace it with an explicit real rate
 * sourced from the FSCA fund-return data or ASISA's reasonable-illustration
 * basis — don't carry an unsourced round number forward silently.
 * @param {number} annualAmount
 * @param {number} r real (above-inflation) rate
 * @param {number} n years
 */
export function pvFiniteAnnuity(annualAmount, r, n) {
  return r > 0
    ? annualAmount * ((1 - Math.pow(1 + r, -n)) / r)
    : annualAmount * n;
}

/**
 * Present value of a perpetuity at real rate r. Kept only as a documented,
 * explicitly-opt-in legacy/comparison mode — NOT used by default anywhere in
 * this module. See file header for why.
 * @param {number} annualAmount
 * @param {number} r
 */
export function pvPerpetuity(annualAmount, r) {
  return r > 0 ? annualAmount / r : Infinity;
}

/**
 * Future value of a lump sum compounded annually.
 * @param {number} principal
 * @param {number} r annual rate
 * @param {number} n years
 */
export function fvCompound(principal, r, n) {
  return principal * Math.pow(1 + r, n);
}

// ─── Life Cover ───────────────────────────────────────────────────────────────

/**
 * @typedef {Object} LifeCoverInputs
 * @property {number} netAnnualIncome
 * @property {number} incomeNeedPct % of net income the family needs to replace (typically 75)
 * @property {number} realReturnRate real (above-inflation) investment return on capital
 * @property {number} yearsToRetirement income replacement horizon
 * @property {number} outstandingBond
 * @property {number} otherDebt
 * @property {number} educationLumpSum
 * @property {number} estateCosts estate admin costs NOT separately covered in estate liquidity calc
 * @property {number} existingLiquidAssets
 * @property {number} existingLifeCover
 * @property {number} spouseAnnualIncome
 */

/** @param {LifeCoverInputs} p */
export function calcLifeCover(p) {
  const annualNeed = p.netAnnualIncome * (p.incomeNeedPct / 100);
  const n = Math.max(1, p.yearsToRetirement);
  const r = p.realReturnRate;

  const incomeReplacementCapital = pvFiniteAnnuity(annualNeed, r, n);
  const spousePV = p.spouseAnnualIncome > 0 ? pvFiniteAnnuity(p.spouseAnnualIncome, r, n) : 0;

  const total = Math.max(0,
    incomeReplacementCapital
    + p.outstandingBond
    + p.otherDebt
    + p.educationLumpSum
    + p.estateCosts
    - p.existingLiquidAssets
    - p.existingLifeCover
    - spousePV
  );

  const motivation =
    `Income Replacement (${n}-year finite annuity): ` +
    `net income R${Math.round(p.netAnnualIncome / 12).toLocaleString()}/month × ${p.incomeNeedPct}% = ` +
    `R${Math.round(annualNeed / 12).toLocaleString()}/month needed. ` +
    `PV over ${n} years at ${(r * 100).toFixed(1)}% real return = ${fmt(incomeReplacementCapital)}. ` +
    `+ Bond/debt ${fmt(p.outstandingBond + p.otherDebt)} ` +
    `+ Education ${fmt(p.educationLumpSum)} ` +
    `+ Estate costs ${fmt(p.estateCosts)} ` +
    `− Liquid assets ${fmt(p.existingLiquidAssets)} ` +
    `− Existing cover ${fmt(p.existingLifeCover)} ` +
    (spousePV > 0 ? `− Spouse income PV ${fmt(spousePV)} ` : '') +
    `= ${fmt(total)}. ` +
    `(Real return = net of CPI. Income need grows with inflation; capital is fully deployed — not preserved as a perpetuity.)`;

  return { incomeReplacementCapital, spousePV, total, motivation };
}

// ─── Dread Disease ────────────────────────────────────────────────────────────
// Medical gap calibrated to health cover: no medical aid R750k; medical aid,
// no gap cover R500k; medical aid + gap cover R200k. Income buffer uses the
// actual IP waiting period (18 months if no IP). Floor: 3× annual income.
//
// PROVENANCE (added 2026-08-19 after actuarial review): the three medical-gap
// tiers and the 3x annual-income floor are a Partridg3 house assumption, not
// a published industry table — neither Discovery's nor Sanlam's public severe
// illness materials publish a needs-sizing formula (their published figures
// are claims-payout schedules — % of sum assured by severity — not a
// recommended-cover methodology). The tiers are plausible against real SA
// cost evidence (private oncology treatment ranges ~R10k to ~R1m depending on
// stage/therapy; typical medical aid oncology benefit R200k-R400k leaves
// exactly this kind of shortfall) but have no external citation. Owner:
// Partridg3 product decision, dated 2026-08-14 (see FUNERAL_DEFAULTS'
// sibling business-rule note below for the same-vintage convention). Treat
// as reviewable, not as a sourced industry constant.

/**
 * @param {number} grossAnnual
 * @param {boolean} hasIP
 * @param {boolean} hasMedicalAid
 * @param {boolean} hasGapCover
 * @param {number} [ipWaitingPeriodMonths]
 */
export function calcDreadDisease(grossAnnual, hasIP, hasMedicalAid, hasGapCover, ipWaitingPeriodMonths = 3) {
  const medicalGap = !hasMedicalAid ? 750_000
    : !hasGapCover                  ? 500_000
    : 200_000;

  const bufferMonths = hasIP ? ipWaitingPeriodMonths : 18;
  const incomeBuffer = (grossAnnual / 12) * bufferMonths;
  const calculated   = medicalGap + incomeBuffer;
  const minimum      = grossAnnual * 3;
  const amount       = Math.max(calculated, minimum);

  const coverDesc = !hasMedicalAid
    ? 'no medical aid — full private hospitalisation exposure'
    : !hasGapCover
    ? 'medical aid without gap cover — significant shortfall risk'
    : 'medical aid + gap cover — residual exposure only';

  const motivation =
    `Medical gap (${coverDesc}): ${fmt(medicalGap)}. ` +
    (hasIP
      ? `Income buffer: ${bufferMonths}-month IP waiting period × ${fmt(grossAnnual / 12)}/month = ${fmt(incomeBuffer)}.`
      : `Income buffer: 18 months (no income protection in place) × ${fmt(grossAnnual / 12)}/month = ${fmt(incomeBuffer)}.`) +
    ` Subtotal: ${fmt(calculated)}. ` +
    `Minimum floor (3× annual income): ${fmt(minimum)}. ` +
    `Recommendation: ${fmt(amount)}.`;

  return { amount, medicalGap, incomeBuffer, motivation };
}

// ─── Capital Disability ───────────────────────────────────────────────────────
// Three-component lump sum: (1) debt clearance, (2) 24-month adaptation/care
// costs, (3) PV of the monthly shortfall between the 75% IP aggregate cap and
// 100% of income, to retirement age.
//
// PROVENANCE (added 2026-08-19 after actuarial review): the 24-month
// adaptation/care period is labelled "CFP Board guidance" in the parameter
// doc below, but no FPI/CFP-SA-published convention for this specific figure
// was located during review — treat it as a Partridg3 house assumption
// pending a located citation, not a verified external standard. Same
// disclosure standard as the dread-disease tiers above: reviewable, not
// sourced.

/**
 * @typedef {Object} CapitalDisabilityInputs
 * @property {number} outstandingDebt
 * @property {number} grossAnnual
 * @property {number} yearsToRetirement
 * @property {number} realReturnRate
 * @property {number} existingPermanentIPMonthly
 * @property {number} [adaptationMonths] default 24 per CFP Board guidance
 */

/** @param {CapitalDisabilityInputs} p */
export function calcCapitalDisability(p) {
  const adaptationMonths = p.adaptationMonths ?? 24;
  const grossMonthly     = p.grossAnnual / 12;

  const debtComponent = p.outstandingDebt;
  const adaptationComponent = grossMonthly * adaptationMonths;

  const ipCap              = grossMonthly * 0.75;
  const monthlyShortfall   = Math.max(0, ipCap - p.existingPermanentIPMonthly);
  const annualShortfall    = monthlyShortfall * 12;
  const n                  = Math.max(1, p.yearsToRetirement);
  const incomeSupplementCapital = pvFiniteAnnuity(annualShortfall, p.realReturnRate, n);

  const amount = debtComponent + adaptationComponent + incomeSupplementCapital;

  const motivation =
    `Capital Disability — three-component lump sum need: ` +
    `(1) Debt clearance: ${fmt(debtComponent)}. ` +
    `(2) Home/vehicle adaptation & care (${adaptationMonths} months × ${fmt(grossMonthly)}/month): ${fmt(adaptationComponent)}. ` +
    `(3) Income supplement capital: 75% IP cap = ${fmt(ipCap)}/month; existing permanent IP = ${fmt(p.existingPermanentIPMonthly)}/month; ` +
    `monthly shortfall = ${fmt(monthlyShortfall)}; PV over ${n} years at ${(p.realReturnRate * 100).toFixed(1)}% real return = ${fmt(incomeSupplementCapital)}. ` +
    `Total lump sum need: ${fmt(amount)}. ` +
    `Deduct existing capital disability cover and group CD benefit to determine additional cover required.`;

  return { debtComponent, adaptationComponent, incomeSupplementCapital, amount, motivation };
}

// ─── Income Protection ────────────────────────────────────────────────────────
// 75% of gross monthly income is the SA industry aggregate cap (across all IP
// policies and employer benefits combined).

/**
 * @param {number} grossMonthly
 * @param {number} existingBenefit
 * @param {string} label
 */
export function calcIncomeProtection(grossMonthly, existingBenefit, label) {
  const maxBenefit = grossMonthly * 0.75;
  const amount = Math.max(0, maxBenefit - existingBenefit);
  const motivation =
    `75% of gross monthly income ${fmt(grossMonthly)} = ${fmt(maxBenefit)} ` +
    `(industry aggregate cap — applies across all IP policies and employer benefits combined). ` +
    (existingBenefit > 0 ? `Less employer ${label} benefit ${fmt(existingBenefit)}. ` : '') +
    `Recommended additional monthly benefit: ${fmt(amount)}. ` +
    `Benefit period: to age 65. Waiting period and escalation rate to be confirmed with insurer.`;
  return { amount, motivation };
}

// ─── Retirement ───────────────────────────────────────────────────────────────
// All rates REAL (above CPI). Target income = grossAnnual × replacementRatio%.
// Drawdown rate = sustainable withdrawal % of portfolio per year. Longevity
// flag raised when retirement age < 60 at >3% drawdown.
//
// Drawdown rate disclosure (added 2026-08-19 after actuarial review): SA
// research (Maré 2016, SAAJ; Van Appel et al. 2021, SAAJ) supports a 4-5%
// sustainable band, and we default to the conservative end. But ASISA's 2022
// member survey found actual SA retirees draw an average of 6.66%, with ~69%
// exceeding 5% — real behaviour runs materially hotter than the "safe" rate.
// A UI surfacing this calculator should disclose that gap to the adviser
// (e.g. "we use a conservative X% for sustainability; SA retirees average
// 6.66% per ASISA 2022, which the research above flags as unsustainable
// over a full retirement") rather than presenting the default silently —
// advisers who know the ASISA figure will otherwise question the number.

/**
 * @typedef {Object} RetirementInputs
 * @property {number} currentSavings
 * @property {number} monthlyContribution
 * @property {number} grossAnnual
 * @property {number} yearsToRetirement
 * @property {number} retirementAge
 * @property {number} realReturnRate
 * @property {number} drawdownRate
 * @property {number} replacementRatio
 * @property {number} marginalTaxRate from calculateTax() — used for RA tax saving disclosure
 */

/** @param {RetirementInputs} p */
export function calcRetirementGap(p) {
  const targetIncome           = p.grossAnnual * (p.replacementRatio / 100);
  const monthlyIncomeRetirement = targetIncome / 12;
  const targetCapital          = targetIncome / p.drawdownRate;
  const n  = p.yearsToRetirement;
  const r  = p.realReturnRate;
  const rm = r / 12;
  const nm = n * 12;

  const fvSavings = fvCompound(p.currentSavings, r, n);
  const fvContributions = p.monthlyContribution > 0 && rm > 0
    ? p.monthlyContribution * ((Math.pow(1 + rm, nm) - 1) / rm) * (1 + rm)
    : p.monthlyContribution * nm;

  const projectedPortfolio = fvSavings + fvContributions;
  const gap = Math.max(0, targetCapital - projectedPortfolio);

  const additionalMonthlyNeeded = (() => {
    if (gap <= 0) return 0;
    if (rm <= 0)  return nm > 0 ? gap / nm : 0;
    return gap * rm / ((Math.pow(1 + rm, nm) - 1) * (1 + rm));
  })();

  const additionalMonthlyAfterTax = additionalMonthlyNeeded * (1 - p.marginalTaxRate);
  const earlyRetirementFlag = p.retirementAge < 60 && p.drawdownRate > 0.03;

  const motivation =
    `WHAT THE CLIENT HAS: ` +
    `Current savings ${fmt(p.currentSavings)} → ${fmt(fvSavings)} in ${n} years at ${(r * 100).toFixed(1)}% real return. ` +
    `Monthly contributions ${fmt(p.monthlyContribution)}/month → ${fmt(fvContributions)} at retirement. ` +
    `Projected portfolio: ${fmt(projectedPortfolio)}. ` +
    `WHAT THE CLIENT NEEDS: ` +
    `${p.replacementRatio}% of gross income = ${fmt(targetIncome)}/year (${fmt(monthlyIncomeRetirement)}/month) in today's rand. ` +
    `At ${(p.drawdownRate * 100).toFixed(1)}% sustainable drawdown, target capital = ${fmt(targetCapital)}. ` +
    (gap > 0
      ? `SHORTFALL: ${fmt(gap)}. Additional contribution needed: ${fmt(additionalMonthlyNeeded)}/month in real terms. ` +
        `After-tax cost (${(p.marginalTaxRate * 100).toFixed(0)}% marginal rate RA deduction): ${fmt(additionalMonthlyAfterTax)}/month. `
      : `ON TRACK: Surplus of ${fmt(projectedPortfolio - targetCapital)} projected. `) +
    (earlyRetirementFlag
      ? `⚠️ LONGEVITY WARNING: Retirement at age ${p.retirementAge} with ${(p.drawdownRate * 100).toFixed(1)}% drawdown over ${Math.round(90 - p.retirementAge)}+ years. ` +
        `Consider reducing drawdown rate to 2.5–3.0% to guard against sequence-of-returns risk.`
      : '');

  return {
    targetCapital, targetIncome, monthlyIncomeRetirement,
    fvSavings, fvContributions, projectedPortfolio,
    gap, additionalMonthlyNeeded, additionalMonthlyAfterTax,
    earlyRetirementFlag, motivation,
  };
}

// ─── Emergency Fund ───────────────────────────────────────────────────────────

/**
 * @param {number} monthlyEssential
 * @param {number} monthsTarget
 * @param {number} existingLiquid
 */
export function calcEmergencyFund(monthlyEssential, monthsTarget, existingLiquid) {
  const target = monthlyEssential * monthsTarget;
  const gap    = Math.max(0, target - existingLiquid);
  const motivation =
    `Essential monthly expenses ${fmt(monthlyEssential)} × ${monthsTarget} months = ${fmt(target)}. ` +
    `Existing liquid savings: ${fmt(existingLiquid)}. ` +
    `Shortfall: ${fmt(gap)}.`;
  return { target, gap, motivation };
}

// ─── Estate Liquidity (full FNA model — in/out-of-estate split, CGT) ──────────
// Executor fees (Administration of Estates Act 66 of 1965): 3.5% + 15% VAT on
// IN-ESTATE assets only. CGT at deemed disposal (s9(4)) excludes assets to a
// surviving spouse via the s9(2)(a) rollover. Conveyancing: R30k floor,
// scales with property value — a DIFFERENT, simpler estimate than the tiered
// table used by calcEstateCosts() below; the two serve different UIs
// (liquidity-gap analysis vs. total-cost-to-beneficiaries) and are both kept.

/**
 * @typedef {Object} EstateLiquidityInputs
 * @property {number} grossInEstateAssets assets that fall into the estate (attract executor fees)
 * @property {number} grossOutOfEstateAssets life policies/RAs to nominees — outside estate
 * @property {number} cgtBaseCost total original acquisition cost of all assets
 * @property {number} liquidAssets immediately available liquid assets
 * @property {number} lifeCoverInEstate life cover NOT nominated to beneficiaries
 * @property {number} marginalRate from calculateTax()
 * @property {TaxParams} tp
 * @property {number} liabilities
 * @property {number} spousalBequest value of assets bequeathed to surviving spouse (CGT rollover)
 * @property {number} propertyValue for conveyancing estimate
 */

/** @param {EstateLiquidityInputs} p */
export function calcEstateLiquidity(p) {
  const grossEstate = p.grossInEstateAssets + p.grossOutOfEstateAssets;

  const dutiableEstate = Math.max(
    0,
    grossEstate - p.liabilities - p.spousalBequest - p.tp.estate_duty_abatement,
  );
  let estateDuty = 0;
  if (dutiableEstate > 0) {
    if (dutiableEstate <= p.tp.estate_duty_high_threshold) {
      estateDuty = dutiableEstate * p.tp.estate_duty_rate_standard;
    } else {
      estateDuty = p.tp.estate_duty_high_threshold * p.tp.estate_duty_rate_standard
        + (dutiableEstate - p.tp.estate_duty_high_threshold) * p.tp.estate_duty_rate_high;
    }
  }

  const executorFee = p.grossInEstateAssets * p.tp.executor_fee_rate * (1 + p.tp.executor_fee_vat);

  const cgtableEstate    = Math.max(0, grossEstate - p.spousalBequest);
  const spousalBaseCost  = p.spousalBequest > 0 && grossEstate > 0
    ? p.cgtBaseCost * (p.spousalBequest / grossEstate)
    : 0;
  const cgtableBaseCost  = p.cgtBaseCost - spousalBaseCost;
  const cgtGain          = Math.max(0, cgtableEstate - cgtableBaseCost - p.tp.cgt_death_exemption);
  const cgtTax           = cgtGain * p.tp.cgt_inclusion_rate * p.marginalRate;

  const conveyancing = Math.max(30_000, Math.round(p.propertyValue * 0.012));

  const totalCosts = estateDuty + executorFee + cgtTax + conveyancing;
  const available  = p.liquidAssets + p.lifeCoverInEstate;
  const gap        = Math.max(0, totalCosts - available);

  const motivation =
    `Gross estate (in-estate ${fmt(p.grossInEstateAssets)} + out-of-estate via nomination ${fmt(p.grossOutOfEstateAssets)}) = ${fmt(grossEstate)}. ` +
    (p.liabilities > 0    ? `− Liabilities ${fmt(p.liabilities)}. ` : '') +
    (p.spousalBequest > 0 ? `− Spousal bequest ${fmt(p.spousalBequest)} (Section 4(q) deduction + Section 9(2)(a) CGT rollover). ` : '') +
    `− Abatement ${fmt(p.tp.estate_duty_abatement)} = Dutiable estate ${fmt(dutiableEstate)}. ` +
    `Estate duty: ${fmt(estateDuty)}. ` +
    `Executor fees (3.5% + VAT on in-estate assets ${fmt(p.grossInEstateAssets)} only — assets passing outside estate excluded): ${fmt(executorFee)}. ` +
    `CGT on deemed disposal at death (assets to spouse excluded per S9(2)(a)): gain ${fmt(cgtGain)} × ${(p.tp.cgt_inclusion_rate * 100).toFixed(0)}% × ${(p.marginalRate * 100).toFixed(0)}% marginal rate = ${fmt(cgtTax)}${p.marginalRate === 0 ? ' (complete income step first)' : ''}. ` +
    `Conveyancing estimate: ${fmt(conveyancing)}. ` +
    `Total estate settlement cost: ${fmt(totalCosts)}. ` +
    `Available (liquid + in-estate life cover): ${fmt(available)}. ` +
    `Liquidity gap: ${fmt(gap)}.`;

  return { grossEstate, dutiableEstate, estateDuty, executorFee, cgtTax, conveyancing, totalCosts, gap, motivation };
}

/**
 * Backward-compatible wrapper for callers that pass a flat grossEstate value.
 * Assumes all assets are in-estate and no out-of-estate assets.
 */
export function calcEstateLiquiditySimple(
  grossEstate, cgtBaseCost, liquidAssets, lifeCoverInEstate, marginalRate, tp,
  liabilities = 0, spousalBequest = 0, propertyValue = 0,
) {
  return calcEstateLiquidity({
    grossInEstateAssets: grossEstate,
    grossOutOfEstateAssets: 0,
    cgtBaseCost, liquidAssets, lifeCoverInEstate, marginalRate, tp,
    liabilities, spousalBequest, propertyValue,
  });
}

// ─── Estate Costs (public-facing "what does winding up cost" model) ──────────
// Source of truth: landing/estate-calculator.html. Tiered 20%/25% duty (fixed
// R3.5m/R7m abatement, no CGT/liabilities-detail split — this is the simpler,
// lead-generation-facing sibling of calcEstateLiquidity() above), VAT-inclusive
// executor fee, Master's Office tariff table, tiered conveyancing table.
// Answers "what does my estate cost, what's left for my beneficiaries" rather
// than "do I have enough liquidity" — different question, different UI,
// deliberately kept as a separate function rather than merged.

/** Master's Office tariff table. @param {number} grossEstate */
export function estateMastersFee(grossEstate) {
  if (grossEstate <= 250000) return 600;
  if (grossEstate <= 500000) return 1000;
  if (grossEstate <= 750000) return 1500;
  if (grossEstate <= 1000000) return 2000;
  return Math.min(7000, 2000 + Math.ceil((grossEstate - 1000000) / 100000) * 600);
}

/** Tiered conveyancing (transfer) fee table by property value. @param {number} propertyValue */
export function estateConveyancingFee(propertyValue) {
  if (propertyValue <= 100000) return 4000;
  if (propertyValue <= 250000) return 6000;
  if (propertyValue <= 500000) return 9000;
  if (propertyValue <= 1000000) return 14000;
  if (propertyValue <= 2000000) return 22000;
  if (propertyValue <= 5000000) return 35000;
  return 55000;
}

/**
 * @typedef {Object} EstateCostsInputs
 * @property {number} grossEstate
 * @property {number} debts outstanding debts, deducted before abatement
 * @property {boolean} hasSpouse doubles the abatement to R7m (Section 4A)
 * @property {boolean} hasProperty
 * @property {number} propertyValue
 */

/** @param {EstateCostsInputs} p */
export function calcEstateCosts(p) {
  const execFee = p.grossEstate * 0.035 * 1.15;
  const netEstate = Math.max(0, p.grossEstate - p.debts);
  const abatement = p.hasSpouse ? 7000000 : 3500000;
  const dutiable = Math.max(0, netEstate - abatement);
  let duty = 0;
  if (dutiable > 0) {
    const at20 = Math.min(dutiable, 30000000);
    duty = at20 * 0.20 + Math.max(0, dutiable - at20) * 0.25;
  }
  const masters = estateMastersFee(p.grossEstate);
  const advert = 1500;
  const conv = p.hasProperty ? estateConveyancingFee(p.propertyValue) : 0;
  const total = execFee + duty + masters + advert + conv;
  const net = Math.max(0, p.grossEstate - p.debts - total);
  const pct = p.grossEstate > 0 ? (total / p.grossEstate) * 100 : 0;
  const liquidityRisk = total > p.grossEstate * 0.15;

  return { execFee, duty, masters, advert, conv, total, net, pct, liquidityRisk, abatement, dutiable };
}

// ─── Education ────────────────────────────────────────────────────────────────
// Education inflation by school type (source: Stats SA, SAIRR, BankservAfrica):
// Private 9% p.a., Public 6% p.a., University 5% p.a. (post-#FeesMustFall cap).

const EDU_INFLATION = {
  PRIVATE:    0.09,
  PUBLIC:     0.06,
  UNIVERSITY: 0.05,
};

/**
 * @param {number} currentAnnualCost
 * @param {number} yearsToEducation
 * @param {number} educationYears
 * @param {number} investmentReturn
 * @param {number} existingSavings
 * @param {'PUBLIC'|'PRIVATE'|'UNIVERSITY'} [schoolType]
 */
export function calcEducation(currentAnnualCost, yearsToEducation, educationYears, investmentReturn, existingSavings, schoolType = 'PRIVATE') {
  const inflationRate = EDU_INFLATION[schoolType] ?? EDU_INFLATION.PRIVATE;
  let totalFutureCost = 0;
  let lumpSumNeeded   = 0;
  for (let y = 0; y < educationYears; y++) {
    const yearsFromNow = yearsToEducation + y;
    const futureCost   = currentAnnualCost * Math.pow(1 + inflationRate, yearsFromNow);
    totalFutureCost   += futureCost;
    lumpSumNeeded     += futureCost / Math.pow(1 + investmentReturn, yearsFromNow);
  }
  return {
    totalFutureCost,
    lumpSumNeeded,
    gap: Math.max(0, lumpSumNeeded - existingSavings),
    inflationRate,
  };
}

// ─── Emergency Fund is above; Budget / Debt Payoff / Savings Goal ────────────
// No perpetuity/finite-annuity ambiguity for these three — sourced from
// client-portal's ClientTools.tsx (the most complete existing versions).

/**
 * @typedef {Object} BudgetCategory
 * @property {string} key
 * @property {string} label
 * @property {'needs'|'wants'|'savings'} group
 * @property {number} [target] target % of income
 */

/** @type {BudgetCategory[]} */
export const BUDGET_CATEGORIES = [
  { key: 'housing',    label: 'Housing',                   group: 'needs',   target: 30 },
  { key: 'transport',  label: 'Transport',                 group: 'needs',   target: 15 },
  { key: 'food',       label: 'Food & Groceries',          group: 'needs',   target: 15 },
  { key: 'insurance',  label: 'Insurance & Medical Aid',   group: 'needs',   target: 10 },
  { key: 'debt',       label: 'Debt Repayments',           group: 'needs',   target: 10 },
  { key: 'savings',    label: 'Savings & Investments',     group: 'savings', target: 20 },
  { key: 'education',  label: 'Education',                 group: 'wants',  target: 10 },
  { key: 'lifestyle',  label: 'Lifestyle & Entertainment', group: 'wants',  target: 10 },
  { key: 'other',      label: 'Other',                     group: 'wants' },
];

/**
 * @param {number} income
 * @param {Record<string, number>} values keyed by BUDGET_CATEGORIES[].key
 */
export function calcBudget(income, values) {
  const get = (key) => values[key] ?? 0;
  const totalExpenses = BUDGET_CATEGORIES.reduce((s, c) => s + get(c.key), 0);
  const surplus       = income - totalExpenses;
  const needsTotal    = BUDGET_CATEGORIES.filter(c => c.group === 'needs').reduce((s, c) => s + get(c.key), 0);
  const wantsTotal    = BUDGET_CATEGORIES.filter(c => c.group === 'wants').reduce((s, c) => s + get(c.key), 0);
  const savingsTotal  = get('savings');
  const pct = (v) => income > 0 ? (v / income) * 100 : 0;

  return {
    totalExpenses, surplus, surplusPct: pct(surplus),
    needsTotal, wantsTotal, savingsTotal,
    needsPct: pct(needsTotal), wantsPct: pct(wantsTotal), savingsPct: pct(savingsTotal),
    savingsRate: pct(savingsTotal), debtRatio: pct(get('debt')), housingRatio: pct(get('housing')),
  };
}

/**
 * @typedef {Object} Debt
 * @property {string} id
 * @property {string} name
 * @property {number} balance
 * @property {number} rate annual %, e.g. 22 for 22%
 * @property {number} minPayment
 */

/**
 * Amortization schedule for a debt payoff plan.
 * @param {Debt[]} debts
 * @param {number} extra additional monthly payment applied to the priority debt
 * @param {'snowball'|'avalanche'} strategy
 */
export function amortizeDebts(debts, extra, strategy) {
  if (debts.length === 0 || debts.every(d => d.balance <= 0)) {
    return { months: 0, totalInterest: 0, savings: 0, order: [], monthsMinOnly: 0 };
  }

  function run(sortedDebts, extraPayment) {
    const ds = sortedDebts.map(d => ({ ...d, bal: d.balance, paid: false, paidMonth: 0 }));
    let month = 0;
    let totalInterest = 0;
    let rollingExtra = extraPayment;

    while (ds.some(d => d.bal > 0.01) && month < 600) {
      month++;
      for (const d of ds) {
        if (d.bal <= 0.01) continue;
        const mr = d.rate / 100 / 12;
        const interest = d.bal * mr;
        totalInterest += interest;
        const principal = Math.min(Math.max(0, d.minPayment - interest), d.bal);
        d.bal = Math.max(0, d.bal - principal);
      }
      let remaining = rollingExtra;
      for (const d of ds) {
        if (d.bal <= 0.01) continue;
        const pay = Math.min(remaining, d.bal);
        d.bal = Math.max(0, d.bal - pay);
        remaining -= pay;
        if (remaining <= 0.01) break;
      }
      for (const d of ds) {
        if (!d.paid && d.bal <= 0.01) {
          d.paid = true;
          d.paidMonth = month;
          rollingExtra += d.minPayment;
        }
      }
    }

    const payoffOrder = ds
      .filter(d => d.paidMonth > 0)
      .sort((a, b) => a.paidMonth - b.paidMonth)
      .map(d => ({ id: d.id, name: d.name, paidMonth: d.paidMonth }));

    return { months: month, totalInterest, payoffOrder };
  }

  const sorted = debts.map(d => ({ ...d }));
  if (strategy === 'snowball') sorted.sort((a, b) => a.balance - b.balance);
  else sorted.sort((a, b) => b.rate - a.rate);

  const { months, totalInterest, payoffOrder } = run(sorted, extra);
  const minOnly = run(sorted.map(d => ({ ...d })), 0);

  return {
    months,
    totalInterest,
    monthsMinOnly: minOnly.months,
    savings: minOnly.totalInterest - totalInterest,
    order: payoffOrder,
  };
}

/**
 * Month-by-month projection for a savings goal (not a closed-form annuity —
 * avoids edge cases when rate or contribution is zero). Capped at 600 months.
 * @param {number} current
 * @param {number} target
 * @param {number} monthly
 * @param {number} annualRatePct
 */
export function monthsToGoal(current, target, monthly, annualRatePct) {
  if (target <= 0 || current >= target) return 0;
  const r = annualRatePct / 100 / 12;
  let bal = current;
  let months = 0;
  while (bal < target && months < 600) {
    bal = bal * (1 + r) + monthly;
    months++;
  }
  return months;
}

// ─── Funeral cover defaults ───────────────────────────────────────────────────
// Objective need schedule (business rule, set 2026-08-14): Main Life and
// Spouse R50 000 each, children R30 000 (age 6+) or R15 000 (under 6). Only
// these relationships count toward the calculated "need" — extended family
// can still be added and covered, but are informational only.

/** @type {Record<string, number>} */
export const FUNERAL_DEFAULTS = {
  'Main Life':                50000,
  'Spouse / Life Partner':    50000,
  'Child (under 6)':          15000,
  'Child (6 and older)':      30000,
  'Parent':                   30000,
  'Parent-in-law':            30000,
  'Sibling':                  20000,
  'Grandparent':              20000,
  'Extended Family Member':   15000,
};

export const FUNERAL_RELATIONSHIPS = Object.keys(FUNERAL_DEFAULTS);

export const FUNERAL_NEED_RELATIONSHIPS = new Set([
  'Main Life', 'Spouse / Life Partner', 'Child (under 6)', 'Child (6 and older)',
]);

export const MAIN_LIFE_FUNERAL_CAP = 133000;

// ─── Formatters ───────────────────────────────────────────────────────────────

/** @param {number|null|undefined} n */
export function fmt(n) {
  if (n == null || isNaN(n)) return '—';
  return 'R ' + Math.round(n).toLocaleString('en-ZA');
}

/** @param {number} n */
export function fmtPct(n) {
  return (n * 100).toFixed(1) + '%';
}
