# Partridg3 Hero Cards — Posting Guide (Batch 2: Adviser-side value prop)

12 cards, 1080x1080. All destinations are real, live links — nothing here is a placeholder.

| File | Category | Post with this link |
|---|---|---|
| adv-benefit-independent-leads.png | benefit | https://partridg3-landing.vercel.app/#contact |
| adv-benefit-less-admin.png | benefit | https://partridg3-landing.vercel.app/#contact |
| adv-benefit-compliance-handled.png | benefit | https://partridg3-landing.vercel.app/#contact |
| adv-feature-fna-wizard.png | feature | https://partridg3-landing.vercel.app/#contact |
| adv-feature-lead-pipeline.png | feature | https://partridg3-landing.vercel.app/#contact |
| adv-feature-commission.png | feature | https://partridg3-landing.vercel.app/#contact |
| adv-feature-referral-tracking.png | feature | https://partridg3-landing.vercel.app/#contact |
| adv-feature-compliance-suite.png | feature | https://partridg3-landing.vercel.app/#contact |
| adv-share-refer-adviser.png | share | https://partridg3-landing.vercel.app/#contact |
| adv-share-whatsapp-channel.png | share | https://whatsapp.com/channel/0029Vb8omRh5fM5epo1EwH2l |
| adv-book-apply.png | book | https://partridg3-landing.vercel.app/#contact |
| adv-book-talk-to-team.png | book | https://partridg3-landing.vercel.app/#contact |

## Important scope note
There's no dedicated public 'apply to become a Partridg3 adviser' page anywhere in the codebase yet — Scrap3's /onboarding route is inside the authenticated app, for advisers who are already approved. Every card except the WhatsApp-channel one routes to landing's #contact form, the only real, live 'express interest' mechanism that exists today. If/when a dedicated adviser-application flow gets built, these links should be swapped to point there instead.

## Why no 'calculators' category
Client-side already covers the public calculators (landing #tools, Covey /tools) — advisers don't need a second promotional push for the same tools. The only genuinely public adviser-side calculator (adviser-app's /calc page) is prospect-facing, not adviser-facing, so featuring it here would have been redundant with Batch 1, not a genuine adviser value prop. Reallocated that category's slots to 'features' (adviser tooling) instead, which is where the real adviser-specific value lives.

## Also fixed along the way
adviser-app/PublicCalc.tsx (the /calc page mentioned above) had the same unsourced '10% growth / 6% inflation' assumption already fixed on the client-side calculators — fixed to a cited 4.5% real return, since this page was about to get more traffic scrutiny. Its 'Chat with an Adviser' WhatsApp button still points at an unconfigured placeholder number — not fixed (no real number exists yet), just flagged.
