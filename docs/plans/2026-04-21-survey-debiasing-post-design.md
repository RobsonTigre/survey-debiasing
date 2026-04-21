# Substack post design — "How to actually use survey and feedback responses from your users"

**Date:** 2026-04-21
**Status:** Design validated section-by-section; ready for draft-to-final polish.
**Author brainstorm partner:** Claude (Opus 4.7)

---

## 1. Frame (what this document is)

A validated design for a ~2,000–2,500-word Substack post extending Robson Tigre's 2023 Medium piece *"A Data-Driven Way of Using Client Feedback in Product Development"* from product feedback to survey data more broadly. The post teaches a practitioner audience how to use biased survey/feedback responses without either (a) throwing them away or (b) pretending the bias isn't there — the "non-destructive" approach — via inverse-probability weighting, worked through in R.

### Locked design decisions

| Decision | Choice |
|---|---|
| Title | "How to actually use survey and feedback responses from your users" |
| Length | ~2,000–2,500 words (medium, hybrid prose + R snippets) |
| Audience | Curious practitioners (data scientists, PMs, analysts) — smart but non-academic |
| Example | One-hour delivery marketplace survey, single thread throughout |
| Citation density | Practitioner-standard (~10 citations), inline hyperlinks + References block |
| Technical depth | Balanced — one explicit formula (IPW estimator), assumptions named with formal labels + plain-English gloss, 3–4 R snippets |
| Assumptions treatment | Dedicated section, triaged by importance (CI + positivity full; spec/SUTVA/measurement brief) |
| Writing style | Fluid prose — avoid chaining period-separated clauses that describe one coherent thought. Join with commas, em-dashes, semicolons, conjunctions. |

### Post structure (word budget)

```
TL;DR box                                       (~110 words)
Opening hook — the PM's dilemma                 (~205 words)
1. The 41% is a trap (the bias)                 (~475 words)
2. Reweight, don't discard (the fix)            (~475 words)
3. The worked example (R walkthrough)           (~525 words)
4. Assumptions, triaged                         (~565 words)
5. Putting it to work (closer)                  (~185 words)
References block                                (not counted)

TOTAL: ~2,540 words
```

### Suggested figures (2)

Both derivable from `survey_debiasing_simulation.R`:
1. **Weight distribution with trimming threshold** — histogram of raw IPW weights with a vertical line at the trimming threshold (395); illustrates positivity diagnostics and why trimming exists.
2. **Naive vs. debiased comparison** — bar chart of the four estimates (40.9% naive, 22.9% raw, 26.7% trimmed, 22.9% stabilized) with the "61,000 vs. 34–40,000 users" headcount annotation.

### Verified numerical results (from running the simulation with `set.seed(42)`)

| Method | Estimate | Bias vs naive (pp) | Effective N |
|---|---:|---:|---:|
| Naive (unweighted) | 40.9% | — | 1001 |
| Debiased (raw IPW) | 22.9% | –18.0 | 130 |
| Debiased (trimmed) | 26.7% | –14.1 | 290 |
| Debiased (stabilized) | 22.9% | –18.0 | 130 |

Respondent profile vs population: older (40.9 vs 38.2 yrs), less female (21% vs 29%), 5× more spend ($10,755 vs $2,137/year), 60% more app opens (21 vs 13/month). Respondents have 27× higher average propensity than non-respondents (0.156 vs 0.006). All propensity-model predictors significant at p < 0.01.

---

## 2. Post content — validated section by section

### TL;DR

> - You surveyed 150,000 users on whether they'd use your new one-hour delivery tier, 1,001 responded, and 41% said yes — but don't act on that number yet.
> - Those respondents are self-selected, which means they tend to be your most engaged, highest-value users, and those are also the users most likely to want one-hour delivery, so the double-selection inflates your estimate.
> - The fix is **inverse probability weighting**: you model each respondent's probability of answering, then upweight underrepresented respondents so that a user with a 5% probability of responding speaks for roughly twenty users like them.
> - The rest of this post walks through the method, the R code, and the four assumptions that can still trip you up even after you reweight.

### Opening hook

> You're a PM at a marketplace, and ultra-fast delivery is the category's arms race of 2026 — Amazon just rolled out a 1-hour delivery tier across hundreds of U.S. cities in March, Rappi Turbo is doing 10-to-15-minute grocery runs across Latin America, and Mercado Livre is expanding seller-managed same-day shipping through Envio Flex. Your team wants to know whether your company should enter and at what price, so you fire off a survey to 150,000 active users asking whether they'd use a new one-hour delivery tier. 1,001 respond — a 0.67% response rate that everyone in the room knows is low but nobody panics about. Of those, 41% say "very likely" or "somewhat likely."
>
> A team is already costing out warehouse upgrades against that number, another is sketching pricing tiers, and someone on Slack types *"so ~40% of our users would use this?"*
>
> That's where this post starts, because the honest answer to that Slack message is *we don't know yet* — and the reason has nothing to do with the survey being poorly designed. Your respondents meant what they said; the problem is that **they are not your users**, or more precisely, they're a tilted slice of them.

### Section 1 — The 41% is a trap

> If you take that 41% at face value and multiply by 150,000, you're telling yourself that roughly 61,000 users want one-hour delivery — a number that will end up underwriting a pricing deck and a capacity plan, which makes it worth asking how you got there. Out of 150,000 invited users, 1,001 chose to answer and 149,000 chose not to; nobody flipped a coin to decide who ended up in the 1,001, which means the respondents share characteristics that differ systematically from the users who ignored the email.
>
> In a marketplace, those characteristics are predictable: respondents skew toward users who are more engaged with the app (more opens per month), more transactional (higher order frequency or basket size), slightly older, and more likely to sit in your high-value cohort. That's the well-documented phenomenon of **nonresponse bias** — when who-answers is correlated with who-you-are, the respondent average drifts away from the population average. The uncomfortable corollary, formalized by [Groves (2006)](https://academic.oup.com/poq/article/70/5/646/4084443), is that the response rate alone doesn't tell you how biased the estimate is: what matters is the correlation between who responded and what you're trying to measure.
>
> Here's the twist specific to product surveys: the same characteristics that predict *responding* also predict *wanting the feature*. Heavy users of your marketplace are the ones who'd get the most value out of one-hour delivery, which means they're both the users who open the survey and the users who click "very likely." You are double-selected into interest, and that double-selection inflates your estimate in a direction you can predict but not directly measure.
>
> You might hope that a bigger sample would wash this out — send to 1.5 million users, collect 10,000 responses — but it won't. Xiao-Li Meng's **"big data paradox"** ([Meng, 2018](https://projecteuclid.org/journals/annals-of-applied-statistics/volume-12/issue-2/Statistical-paradises-and-paradoxes-in-big-data-I--Law/10.1214/18-AOAS1161SF.full)) shows that under selection bias, the larger your dataset, the surer you are of the wrong answer. In his canonical analysis, ~2.3 million respondents to the 2016 Cooperative Congressional Election Study — roughly 1% of the U.S. electorate — had an effective sample size of only about **400** for estimating Donald Trump's vote share, a 99.98% reduction driven by a data-defect correlation of just –0.005 between responding and voting for Trump. The same pattern appeared in 2021 COVID-19 tracking: [Bradley et al. (2021, *Nature*)](https://www.nature.com/articles/s41586-021-04198-4) found that the Delphi–Facebook survey, with ~250,000 responses per week, overestimated U.S. first-dose vaccine uptake by **17 percentage points** against CDC benchmarks, and the Census Household Pulse (~75,000 per two weeks) by 14 points — despite both surveys applying post-hoc weighting corrections.
>
> Scale doesn't fix selection; it just gives you tighter confidence intervals around a biased mean. That's why the response-rate alarm bell everyone ignores at 0.67% is pointing at something real — not the sample size, but the correlation between who answered and what you're trying to measure.

### Section 2 — Reweight, don't discard

> Here's the intuition before any formula. Imagine you ran the one-hour-delivery survey at the entrance of a flagship store instead of by email, and by coincidence, heavy-spending regulars are five times more likely to walk past that entrance on a given morning than casual visitors, and every shopper who walks past gets surveyed. If 100 regulars and 20 casuals answer and you take the simple average, you've written a report about regulars with a cameo from casuals — but the fix is obvious: weight each casual's answer five times more than each regular's, because casuals were five times less likely to walk past the entrance in the first place.
>
> Online surveys work the same way, except the "entrance" is your email deliverability, inbox noise, app engagement, push-notification opt-ins, and a dozen other things that determine whether a user sees and responds to your survey. You don't know any specific user's true response probability, but you can estimate it, because the same characteristics that drive response probability are sitting right there in your data: app opens, order frequency, basket size, account tenure, and so on. Fit a model that predicts *responded* from those features, and for each respondent you get back a number between 0 and 1 — their **propensity score**, the probability that a user like them responded.
>
> Once you have that number, the correction is a weighted average: each respondent carries a weight equal to the inverse of their propensity score, so a user with a 5% estimated probability of responding counts for twenty users like them, and a user with a 50% estimated probability counts for two. The estimator traces back to [Horvitz and Thompson (1952)](https://www.tandfonline.com/doi/abs/10.1080/01621459.1952.10483446) for survey sampling, was extended to observational data via the propensity-score concept by [Rosenbaum and Rubin (1983)](https://academic.oup.com/biomet/article-abstract/70/1/41/240879), and was formalized for nonresponse and missing-data settings — which is exactly what we're doing here — by [Robins, Rotnitzky and Zhao (1994)](https://www.jstor.org/stable/2290910). In its working form:
>
> ```
> estimate = Σ (y_i · w_i) / Σ w_i,    where   w_i = 1 / ê(x_i)
> ```
>
> `y_i` is the outcome (1 if respondent *i* said "very likely," 0 otherwise) and `ê(x_i)` is that respondent's estimated propensity score given their observables `x_i`.[^1] That's it — no data is thrown away; every respondent still shows up in the estimate, but underrepresented respondents show up with more weight. That's what we mean by "non-destructive": the bias becomes a correction to the weights, not a deletion from the sample.

[^1]: The ratio form here is technically the Hájek (1971) refinement of pure Horvitz-Thompson — slightly biased but much lower variance, and the default in most survey-weighting packages.

### Section 3 — The worked example

> The simulation in the repo ([`survey_debiasing_simulation.R`](https://github.com/...)) generates 150,000 users with realistic marketplace characteristics, selects 1,001 respondents with a bias toward engaged and high-spending users, and walks through the IPW correction. Here's what each step looks like in code and what the numbers say.
>
> **Step 1 — Look at respondents vs. population.** The invited users average 38 years old, are 29% female, spend ~$2,100 per year on the platform, and open the app ~13 times per month. The 1,001 who actually responded are older (41), less female (21%), spend about five times more (~$10,800/year), and open the app ~60% more often (21 times per month). The direction of the tilt is what you'd expect, and the magnitude is larger than you might guess on priors.
>
> **Step 2 — Fit a propensity model.** Regress *responded* on user observables:
>
> ```r
> propensity_model <- glm(
>   responded ~ age + female + has_revenue + deposits_per_year +
>               withdrawals_per_year + monthly_app_opens,
>   data = population,
>   family = binomial(link = "logit")
> )
> ```
>
> Every predictor is significant at p < 0.01; app opens dominate practically (each additional monthly open bumps log-odds of responding by ~0.14, which compounds fast). The resulting propensity scores average **15.6% among actual respondents** vs. **0.6% among non-respondents** — respondents are, on average, twenty-seven times more likely to respond than non-respondents. That's your selection bias, measured directly.
>
> **Step 3 — Compute weights.** For each respondent, the inverse-propensity weight `w_i = 1/ê(x_i)`. Some respondents have tiny estimated propensities, which produces huge weights — the mean raw weight is 89 and the max is 3,073. Extreme weights inflate variance, so practitioners usually compute a **trimmed** variant that caps weights at, say, the 95th percentile (here: 395) and a **stabilized** variant that scales by the overall response rate. All three are in the script:
>
> ```r
> trim_threshold <- min(quantile(weight_raw, 0.95, na.rm = TRUE),
>                       5 * mean(weight_raw, na.rm = TRUE))
> weight_trimmed    <- pmin(weight_raw, trim_threshold)
> weight_stabilized <- (n_respondents / n_invited) / propensity_score
> ```
>
> **Step 4 — Compute the weighted estimate.**
>
> ```r
> debiased <- sum(interest * weight_trimmed) / sum(weight_trimmed)
> ```
>
> **The headline:** the naive estimate is **40.9%**, the debiased estimate with trimmed weights is **26.7%**, and with raw or stabilized weights is **22.9%**. The naive number overstated demand by **14–18 percentage points** — in headcount terms, the difference between telling your team *"~61,000 users want one-hour delivery"* and telling them *"~34,000–40,000 do."* Same survey, very different business decision.
>
> The trimmed estimate (26.7%) sits between naive and raw because capping extreme weights pulls the correction back toward the center. Raw (22.9%) is closer to unbiased under correct specification; trimmed is more robust to extreme weights and has a larger effective sample size (290 vs 130 in this run). Report both: **trimmed as your point estimate, raw alongside as a robustness check.**

### Section 4 — Assumptions, triaged by how much they can bite you

> Inverse-probability weighting recovers an unbiased population estimate **if** four things hold: conditional independence, positivity, correct model specification, and no interference. Two of those are load-bearing and the other two are usually acknowledged and moved past. Here's the honest version.
>
> **Conditional independence (selection on observables).** This is the whole ballgame. The assumption says that once you've controlled for the observables you put into the propensity model, the only thing separating respondents from non-respondents is random noise *with respect to the outcome you're measuring*. Put differently: after conditioning on app opens, spend, tenure, and the rest of your covariates, nothing *else* about a user correlates both with responding and with wanting one-hour delivery. This is the IPW-for-nonresponse version of the **missing-at-random (MAR) assumption** from the missing-data literature ([Little & Rubin, 2019](https://onlinelibrary.wiley.com/doi/book/10.1002/9781119482260)).
>
> The uncomfortable fact is that **this assumption is inherently untestable from the observed data** — there is no empirical check that validates it, only partial falsifications that can rule out particular violations. Practitioners reason about it with domain knowledge: is there anything that drives both who responds and what they want that isn't in my dataset? A plausible violator in our example is *time pressure* — users who experience chronic time pressure are both more likely to respond to a shopping survey and more likely to want one-hour delivery, but "time pressure" isn't in your feature store. If that's what's going on, the debiased estimate still overstates interest, just less obviously, because the output now looks rigorous.
>
> The best defenses are additive: (i) include every plausibly relevant covariate in the propensity model, (ii) compare multiple propensity specifications for stability (see "correct model specification" below), and (iii) run a formal sensitivity analysis such as [Rosenbaum bounds (1987)](https://academic.oup.com/biomet/article-abstract/74/1/13/217167) or the [E-value (VanderWeele & Ding, 2017)](https://www.acpjournals.org/doi/abs/10.7326/M16-2607) to quantify how much unmeasured selection would be needed to overturn your conclusion.
>
> **Positivity (common support).** Every user must have some nonzero probability of responding. If there are subgroups that literally never respond — a dormant cohort, users in a region your emails don't reach — the method has nothing to extrapolate from, and any near-zero-propensity respondent who does slip through will carry an enormous weight. Unlike conditional independence, this one is directly diagnosable: plot the distribution of estimated propensity scores, look at the weights in the tails, and check for respondent types whose characteristics have no non-respondent analogs.
>
> When positivity fails, you have two options: trim the weights (which shifts your estimand toward the **overlap population** — the cohort where respondent-types and non-respondent-types actually coexist — and stabilizes variance), or restrict the target population to the subset where positivity holds and report for that subset only. In our simulation, 50 respondents had raw weights above the trimming threshold of 395, and capping them shifted the debiased estimate from 22.9% to 26.7% — a 3.9 pp swing driven entirely by a handful of unusual respondents. That sensitivity is why trimmed and raw estimates should both be reported.
>
> **Correct specification, interference, and measurement error (briefly).** Three other assumptions fail more quietly. *Model specification*: your propensity model has to actually capture P(respond | X). Logistic regression with main effects is a defensible starting point; gradient-boosted trees or random forests give you more flexibility, and comparing specifications is a cheap way to spot-check stability. *No interference*: one user's response shouldn't affect another's — usually fine, occasionally broken if users discuss the survey in group chats. *No measurement error*: your covariates are observed accurately. For marketplace signals like app opens and spend this is almost always met; for self-reported fields, less so.

### Section 5 — Putting it to work (closer)

> A three-step workflow for your next sub-5%-response-rate survey:
>
> 1. **Inspect the tilt.** Compare summary statistics for respondents vs. the invited population on every observable you have. If they're indistinguishable, stop — you don't have a bias problem to fix. They won't be.
> 2. **Fit a propensity model.** Logistic regression with all your covariates is a reasonable default; swap in gradient-boosted trees when your feature set grows or effects are nonlinear. Save the predicted propensities.
> 3. **Report both numbers plus the sensitivity.** Publish the naive estimate, the trimmed-IPW debiased estimate, and the raw-IPW debiased estimate side-by-side. The gap between them is your best summary of how much the selection bias is doing. In our example that gap was **40.9% → 26.7% → 22.9%** — the difference between shipping one-hour delivery as a mass-market product or a premium niche.
>
> The non-destructive principle: don't throw biased survey data away, and don't pretend it isn't biased. Fit the propensity model, weight honestly, and tell the whole story.

---

## 3. References (consolidated, for the References block at end of post)

1. Bradley, V. C., Kuriwaki, S., Isakov, M., Sejdinovic, D., Meng, X.-L., & Flaxman, S. (2021). Unrepresentative big surveys significantly overestimated US vaccine uptake. *Nature*, 600, 695–700. https://www.nature.com/articles/s41586-021-04198-4
2. Groves, R. M. (2006). Nonresponse rates and nonresponse bias in household surveys. *Public Opinion Quarterly*, 70(5), 646–675. https://academic.oup.com/poq/article/70/5/646/4084443
3. Hájek, J. (1971). Comment on "An Essay on the Logical Foundations of Survey Sampling, Part One" by D. Basu. In *Foundations of Statistical Inference* (p. 236). Holt, Rinehart & Winston.
4. Horvitz, D. G., & Thompson, D. J. (1952). A generalization of sampling without replacement from a finite universe. *Journal of the American Statistical Association*, 47(260), 663–685. https://www.tandfonline.com/doi/abs/10.1080/01621459.1952.10483446
5. Little, R. J. A., & Rubin, D. B. (2019). *Statistical Analysis with Missing Data* (3rd ed.). Wiley. https://onlinelibrary.wiley.com/doi/book/10.1002/9781119482260
6. Meng, X.-L. (2018). Statistical paradises and paradoxes in big data (I): Law of large populations, big data paradox, and the 2016 US presidential election. *Annals of Applied Statistics*, 12(2), 685–726. https://projecteuclid.org/journals/annals-of-applied-statistics/volume-12/issue-2/Statistical-paradises-and-paradoxes-in-big-data-I--Law/10.1214/18-AOAS1161SF.full
7. Robins, J. M., Rotnitzky, A., & Zhao, L. P. (1994). Estimation of regression coefficients when some regressors are not always observed. *JASA*, 89(427), 846–866. https://www.jstor.org/stable/2290910
8. Rosenbaum, P. R. (1987). Sensitivity analysis for certain permutation inferences in matched observational studies. *Biometrika*, 74(1), 13–26. https://academic.oup.com/biomet/article-abstract/74/1/13/217167
9. Rosenbaum, P. R., & Rubin, D. B. (1983). The central role of the propensity score in observational studies for causal effects. *Biometrika*, 70(1), 41–55. https://academic.oup.com/biomet/article-abstract/70/1/41/240879
10. Tigre, R. (2023). *A Data-Driven Way of Using Client Feedback in Product Development*. Medium. (predecessor piece — link to author's Medium profile)
11. VanderWeele, T. J., & Ding, P. (2017). Sensitivity analysis in observational research: Introducing the E-value. *Annals of Internal Medicine*, 167(4), 268–274. https://www.acpjournals.org/doi/abs/10.7326/M16-2607

---

## 4. Open follow-ups (not blocking draft)

1. **Script refactor to marketplace-native variable names.** The R script uses fintech-inspired names (`deposits_per_year`, `withdrawals_per_year`, `has_revenue`). A lightweight refactor to marketplace-native names (`annual_spend`, `monthly_orders`, `has_made_purchase`) would make the code snippets read cleanly with the prose. ~5-minute task; numbers will be numerically identical modulo minor simulation noise. Deferred pending user decision.
2. **Overlap weights mention.** Li, Morgan & Zaslavsky (2018) overlap weights are a modern alternative to trimming that smoothly downweights propensity-tail observations. Currently not cited; could be added in ~40 words if frontier-practice signaling is worth the length. Default: leave out.
3. **GitHub repo link placeholder.** The worked-example section links to `[survey_debiasing_simulation.R](https://github.com/...)`. Replace with actual repo URL before publication.
4. **Figures.** Two figures suggested (weight distribution + naive-vs-debiased comparison). Author to generate from the R script at publication time.
5. **Substack formatting pass.** Verify that (a) the IPW formula code block renders cleanly (alternative: upgrade to KaTeX if theme supports it); (b) the Hájek footnote renders (Substack supports `^[...]` footnotes); (c) the markdown table in Section 3 renders.

---

## 5. Brainstorm log (decisions made during this session)

- Title iterated from "Surveys self-select. Your analysis shouldn't." → "How to actually use survey and feedback responses from your users" (user preference: declarative teach-you-how voice, not clickbait).
- Running example iterated: betting feature (R script) → Prime-style subscription → **one-hour delivery marketplace** (single thread throughout).
- Opening hook service references iterated: initial list included hallucinated "Envío Flash" (Mercado Livre) and retired "Prime Now" (Amazon); verified and corrected to Amazon 1-hour (March 2026 re-launch), Rappi Turbo (10–15 min), Mercado Livre Envio Flex (2026).
- Meng (2018) example tightened to verified specifics: 2.3M CCES respondents, –0.005 data-defect correlation, effective n ≈ 400, 99.98% reduction, Trump vote share. Added Bradley et al. (2021, *Nature*) as second empirical anchor.
- Citation lineage for IPW refined from "Horvitz-Thompson + Rosenbaum-Rubin" to the more accurate "Horvitz-Thompson (1952) → Rosenbaum-Rubin (1983) → Robins-Rotnitzky-Zhao (1994)," with Hájek (1971) footnoted for the ratio-form variant.
- Conditional-independence framing strengthened from "cannot test with observed data" to "inherently untestable from the observed data" (canonical phrasing); tied to the cognate MAR assumption via Little & Rubin (2019).
- Trimming interpretation refined from "biases toward commonly-surveyed subgroup" to the more precise "shifts your estimand toward the overlap population."
- Writing style memory saved: user prefers fluid prose with connected clauses joined by commas / em-dashes / semicolons / conjunctions, not choppy period-separated sentences.
