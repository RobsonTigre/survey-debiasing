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

## The 41% is a trap

If you take that 41% at face value and multiply by 150,000, you're telling yourself that roughly 61,000 users want one-hour delivery — a number that will end up underwriting a pricing deck and a capacity plan, which makes it worth asking how you got there. Out of 150,000 invited users, 1,001 chose to answer and 149,000 chose not to; nobody flipped a coin to decide who ended up in the 1,001, which means the respondents share characteristics that differ systematically from the users who ignored the email.

In a marketplace, those characteristics are predictable: respondents skew toward users who are more engaged with the app (more opens per month), more transactional (higher order frequency or basket size), slightly older, and more likely to sit in your high-value cohort. That's the well-documented phenomenon of **nonresponse bias** — when who-answers is correlated with who-you-are, the respondent average drifts away from the population average. The uncomfortable corollary, formalized by [Groves (2006)](https://academic.oup.com/poq/article/70/5/646/4084443), is that the response rate alone doesn't tell you how biased the estimate is: what matters is the correlation between who responded and what you're trying to measure.

Here's the twist specific to product surveys: the same characteristics that predict *responding* also predict *wanting the feature*. Heavy users of your marketplace are the ones who'd get the most value out of one-hour delivery, which means they're both the users who open the survey and the users who click "very likely." You are double-selected into interest, and that double-selection inflates your estimate in a direction you can predict but not directly measure.

You might hope that a bigger sample would wash this out — send to 1.5 million users, collect 10,000 responses — but it won't. Xiao-Li Meng's **"big data paradox"** ([Meng, 2018](https://projecteuclid.org/journals/annals-of-applied-statistics/volume-12/issue-2/Statistical-paradises-and-paradoxes-in-big-data-I--Law/10.1214/18-AOAS1161SF.full)) shows that under selection bias, the larger your dataset, the surer you are of the wrong answer. In his canonical analysis, ~2.3 million respondents to the 2016 Cooperative Congressional Election Study — roughly 1% of the U.S. electorate — had an effective sample size of only about **400** for estimating Donald Trump's vote share, a 99.98% reduction driven by a data-defect correlation of just –0.005 between responding and voting for Trump. The same pattern appeared in 2021 COVID-19 tracking: [Bradley et al. (2021, *Nature*)](https://www.nature.com/articles/s41586-021-04198-4) found that the Delphi–Facebook survey, with ~250,000 responses per week, overestimated U.S. first-dose vaccine uptake by **17 percentage points** against CDC benchmarks, and the Census Household Pulse (~75,000 per two weeks) by 14 points — despite both surveys applying post-hoc weighting corrections.

Scale doesn't fix selection; it just gives you tighter confidence intervals around a biased mean. That's why the response-rate alarm bell everyone ignores at 0.67% is pointing at something real — not the sample size, but the correlation between who answered and what you're trying to measure.

## Reweight, don't discard

Here's the intuition before any formula. Imagine you ran the one-hour-delivery survey at the entrance of a flagship store instead of by email, and by coincidence, heavy-spending regulars are five times more likely to walk past that entrance on a given morning than casual visitors, and every shopper who walks past gets surveyed. If 100 regulars and 20 casuals answer and you take the simple average, you've written a report about regulars with a cameo from casuals — but the fix is obvious: weight each casual's answer five times more than each regular's, because casuals were five times less likely to walk past the entrance in the first place.

Online surveys work the same way, except the "entrance" is your email deliverability, inbox noise, app engagement, push-notification opt-ins, and a dozen other things that determine whether a user sees and responds to your survey. You don't know any specific user's true response probability, but you can estimate it, because the same characteristics that drive response probability are sitting right there in your data: app opens, order frequency, basket size, account tenure, and so on. Fit a model that predicts *responded* from those features, and for each respondent you get back a number between 0 and 1 — their **propensity score**, the probability that a user like them responded.

Once you have that number, the correction is a weighted average: each respondent carries a weight equal to the inverse of their propensity score, so a user with a 5% estimated probability of responding counts for twenty users like them, and a user with a 50% estimated probability counts for two. The estimator traces back to [Horvitz and Thompson (1952)](https://www.tandfonline.com/doi/abs/10.1080/01621459.1952.10483446) for survey sampling, was extended to observational data via the propensity-score concept by [Rosenbaum and Rubin (1983)](https://academic.oup.com/biomet/article-abstract/70/1/41/240879), and was formalized for nonresponse and missing-data settings — which is exactly what we're doing here — by [Robins, Rotnitzky and Zhao (1994)](https://www.jstor.org/stable/2290910). In its working form:

```
estimate = Σ (y_i · w_i) / Σ w_i,    where   w_i = 1 / ê(x_i)
```

`y_i` is the outcome (1 if respondent *i* said "very likely," 0 otherwise) and `ê(x_i)` is that respondent's estimated propensity score given their observables `x_i`.[^1] That's it — no data is thrown away; every respondent still shows up in the estimate, but underrepresented respondents show up with more weight. That's what we mean by "non-destructive": the bias becomes a correction to the weights, not a deletion from the sample.

[^1]: The ratio form here is technically the Hájek (1971) refinement of pure Horvitz-Thompson — slightly biased but much lower variance, and the default in most survey-weighting packages.
