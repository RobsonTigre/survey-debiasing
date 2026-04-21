# How to actually use survey and feedback responses from your users

**TL;DR**

- You surveyed 150,000 users on whether they'd use your new one-hour delivery tier, 1,001 responded, and 41% said yes — but don't act on that number yet.
- Those respondents are self-selected, which means they tend to be your most engaged, highest-value users, and those are also the users most likely to want one-hour delivery, so the double-selection inflates your estimate.
- The fix is **inverse probability weighting**: you model each respondent's probability of answering, then upweight underrepresented respondents so that a user with a 5% probability of responding speaks for roughly twenty users like them.
- The rest of this post walks through the method, the R code, and the four assumptions that can still trip you up even after you reweight.

---

You're a PM at a marketplace, and ultra-fast delivery is the category's arms race of 2026 — Amazon just rolled out a 1-hour delivery tier across hundreds of U.S. cities in March, Rappi Turbo is doing 10-to-15-minute grocery runs across Latin America, and Mercado Livre is expanding seller-managed same-day shipping through Envio Flex. Your team wants to know whether your company should enter and at what price, so you fire off a survey to 150,000 active users asking whether they'd use a new one-hour delivery tier. 1,001 respond — a 0.67% response rate that everyone in the room knows is low but nobody panics about. Of those, 41% say "very likely" or "somewhat likely."

A team is already costing out warehouse upgrades against that number, another is sketching pricing tiers, and someone on Slack types *"so ~40% of our users would use this?"*

That's where this post starts, because the honest answer to that Slack message is *we don't know yet* — and the reason has nothing to do with the survey being poorly designed. Your respondents meant what they said; the problem is that **they are not your users**, or more precisely, they're a tilted slice of them.
