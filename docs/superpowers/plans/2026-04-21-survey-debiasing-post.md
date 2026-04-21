# Survey-debiasing Substack post — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a publishable Substack post titled *"How to actually use survey and feedback responses from your users"* from the validated design in `docs/plans/2026-04-21-survey-debiasing-post-design.md`.

**Architecture:** This is a content deliverable, not a code feature. The six post sections (TL;DR, opening hook, Sections 1–5) are already drafted in full in the design doc. This plan assembles them into a single publishable markdown file, runs three quality-gate passes (URL resolution, numerical-claim audit, fluid-prose style check), and optionally refactors the R script to marketplace-native variable names so code snippets read cleanly with the prose.

**Tech stack:** Markdown (for the post), R 4.5.2 (already confirmed installed — for optional script refactor), curl + bash (for URL resolution checks).

**Adaptation note:** Because the deliverable is prose, not code, "tests" in this plan are content quality gates rather than unit tests. Where the writing-plans skill asks for complete code in every step, we instead point to the authoritative prose location in the design doc plus any transformations needed (e.g., header level, link format). Re-printing ~3,500 words of already-validated prose inside this plan would be more error-prone than maintaining a single source of truth in the design doc.

**Source of truth:** `docs/plans/2026-04-21-survey-debiasing-post-design.md` — all final prose, citations, and numerical claims are validated there. If any content conflict surfaces during execution, the design doc wins unless the user explicitly overrides.

---

## File structure

**Files this plan creates:**
- `posts/2026-04-survey-debiasing.md` — the final publishable Substack post (primary deliverable).
- `survey_debiasing_marketplace.R` — companion script for the post with marketplace-native variable names (Task 12).

**Files this plan does NOT modify:**
- `survey_debiasing_simulation.R` — reference implementation stays untouched. Task 12 creates a *new* file (`survey_debiasing_marketplace.R`) instead of editing this one.

**Files this plan does NOT touch:**
- Figures are left to the author — the plan notes *where* they go in the post but does not generate PNGs.
- Existing `README.md` and source PDF are untouched.

---

## Placeholders that must be resolved before publication

The post contains one placeholder URL that the author must fill in before posting:
- `[survey_debiasing_simulation.R](https://github.com/...)` in Section 3 — replace `https://github.com/...` with the actual public repo URL. Task 8 flags this.

---

## Tasks

### Task 1: Scaffold post file with frontmatter and TL;DR

**Files:**
- Create: `posts/2026-04-survey-debiasing.md`

- [ ] **Step 1: Create the `posts/` directory**

```bash
mkdir -p posts
```

- [ ] **Step 2: Write the file's header (title) and TL;DR block**

Create `posts/2026-04-survey-debiasing.md` with the content below. The TL;DR text is copied verbatim from the design doc's "TL;DR" section (page-search anchor: `### TL;DR`).

```markdown
# How to actually use survey and feedback responses from your users

**TL;DR**

- You surveyed 150,000 users on whether they'd use your new one-hour delivery tier, 1,001 responded, and 41% said yes — but don't act on that number yet.
- Those respondents are self-selected, which means they tend to be your most engaged, highest-value users, and those are also the users most likely to want one-hour delivery, so the double-selection inflates your estimate.
- The fix is **inverse probability weighting**: you model each respondent's probability of answering, then upweight underrepresented respondents so that a user with a 5% probability of responding speaks for roughly twenty users like them.
- The rest of this post walks through the method, the R code, and the four assumptions that can still trip you up even after you reweight.
```

- [ ] **Step 3: Verify the file exists and has the expected content**

```bash
test -f posts/2026-04-survey-debiasing.md && head -20 posts/2026-04-survey-debiasing.md
```
Expected: prints the H1 title and the TL;DR bullets.

- [ ] **Step 4: Commit**

```bash
git add posts/2026-04-survey-debiasing.md
git commit -m "post: scaffold with title and TL;DR"
```

---

### Task 2: Append opening hook

**Files:**
- Modify: `posts/2026-04-survey-debiasing.md`

Source: design doc section `### Opening hook` (~205 words).

- [ ] **Step 1: Append opening hook to the post file**

Append to `posts/2026-04-survey-debiasing.md`:

```markdown

---

You're a PM at a marketplace, and ultra-fast delivery is the category's arms race of 2026 — Amazon just rolled out a 1-hour delivery tier across hundreds of U.S. cities in March, Rappi Turbo is doing 10-to-15-minute grocery runs across Latin America, and Mercado Livre is expanding seller-managed same-day shipping through Envio Flex. Your team wants to know whether your company should enter and at what price, so you fire off a survey to 150,000 active users asking whether they'd use a new one-hour delivery tier. 1,001 respond — a 0.67% response rate that everyone in the room knows is low but nobody panics about. Of those, 41% say "very likely" or "somewhat likely."

A team is already costing out warehouse upgrades against that number, another is sketching pricing tiers, and someone on Slack types *"so ~40% of our users would use this?"*

That's where this post starts, because the honest answer to that Slack message is *we don't know yet* — and the reason has nothing to do with the survey being poorly designed. Your respondents meant what they said; the problem is that **they are not your users**, or more precisely, they're a tilted slice of them.
```

- [ ] **Step 2: Verify the opening hook is in place**

```bash
grep -q "one-hour delivery tier" posts/2026-04-survey-debiasing.md && grep -q "not your users" posts/2026-04-survey-debiasing.md
```
Expected: both greps return exit code 0 (matches found).

- [ ] **Step 3: Commit**

```bash
git add posts/2026-04-survey-debiasing.md
git commit -m "post: add opening hook"
```

---

### Task 3: Append Section 1 — "The 41% is a trap"

**Files:**
- Modify: `posts/2026-04-survey-debiasing.md`

Source: design doc section `### Section 1 — The 41% is a trap` (~475 words). Contains load-bearing anchors [Groves 2006], [Meng 2018], [Bradley et al. 2021].

- [ ] **Step 1: Append Section 1 header and prose**

Append verbatim from the design doc's Section 1 block, prefixed with an H2 header:

```markdown

## The 41% is a trap

If you take that 41% at face value and multiply by 150,000, you're telling yourself that roughly 61,000 users want one-hour delivery — a number that will end up underwriting a pricing deck and a capacity plan, which makes it worth asking how you got there. Out of 150,000 invited users, 1,001 chose to answer and 149,000 chose not to; nobody flipped a coin to decide who ended up in the 1,001, which means the respondents share characteristics that differ systematically from the users who ignored the email.

In a marketplace, those characteristics are predictable: respondents skew toward users who are more engaged with the app (more opens per month), more transactional (higher order frequency or basket size), slightly older, and more likely to sit in your high-value cohort. That's the well-documented phenomenon of **nonresponse bias** — when who-answers is correlated with who-you-are, the respondent average drifts away from the population average. The uncomfortable corollary, formalized by [Groves (2006)](https://academic.oup.com/poq/article/70/5/646/4084443), is that the response rate alone doesn't tell you how biased the estimate is: what matters is the correlation between who responded and what you're trying to measure.

Here's the twist specific to product surveys: the same characteristics that predict *responding* also predict *wanting the feature*. Heavy users of your marketplace are the ones who'd get the most value out of one-hour delivery, which means they're both the users who open the survey and the users who click "very likely." You are double-selected into interest, and that double-selection inflates your estimate in a direction you can predict but not directly measure.

You might hope that a bigger sample would wash this out — send to 1.5 million users, collect 10,000 responses — but it won't. Xiao-Li Meng's **"big data paradox"** ([Meng, 2018](https://projecteuclid.org/journals/annals-of-applied-statistics/volume-12/issue-2/Statistical-paradises-and-paradoxes-in-big-data-I--Law/10.1214/18-AOAS1161SF.full)) shows that under selection bias, the larger your dataset, the surer you are of the wrong answer. In his canonical analysis, ~2.3 million respondents to the 2016 Cooperative Congressional Election Study — roughly 1% of the U.S. electorate — had an effective sample size of only about **400** for estimating Donald Trump's vote share, a 99.98% reduction driven by a data-defect correlation of just –0.005 between responding and voting for Trump. The same pattern appeared in 2021 COVID-19 tracking: [Bradley et al. (2021, *Nature*)](https://www.nature.com/articles/s41586-021-04198-4) found that the Delphi–Facebook survey, with ~250,000 responses per week, overestimated U.S. first-dose vaccine uptake by **17 percentage points** against CDC benchmarks, and the Census Household Pulse (~75,000 per two weeks) by 14 points — despite both surveys applying post-hoc weighting corrections.

Scale doesn't fix selection; it just gives you tighter confidence intervals around a biased mean. That's why the response-rate alarm bell everyone ignores at 0.67% is pointing at something real — not the sample size, but the correlation between who answered and what you're trying to measure.
```

- [ ] **Step 2: Verify all three anchors in Section 1 are present**

```bash
grep -c "academic.oup.com/poq" posts/2026-04-survey-debiasing.md
grep -c "projecteuclid.org" posts/2026-04-survey-debiasing.md
grep -c "nature.com/articles/s41586-021-04198-4" posts/2026-04-survey-debiasing.md
```
Expected: each returns 1.

- [ ] **Step 3: Commit**

```bash
git add posts/2026-04-survey-debiasing.md
git commit -m "post: add Section 1 (The 41% is a trap)"
```

---

### Task 4: Append Section 2 — "Reweight, don't discard"

**Files:**
- Modify: `posts/2026-04-survey-debiasing.md`

Source: design doc section `### Section 2 — Reweight, don't discard` (~475 words + 1 footnote). Contains anchors [Horvitz-Thompson 1952], [Rosenbaum-Rubin 1983], [Robins-Rotnitzky-Zhao 1994], and Hájek (1971) in a footnote.

- [ ] **Step 1: Append Section 2**

Append to the post file:

```markdown

## Reweight, don't discard

Here's the intuition before any formula. Imagine you ran the one-hour-delivery survey at the entrance of a flagship store instead of by email, and by coincidence, heavy-spending regulars are five times more likely to walk past that entrance on a given morning than casual visitors, and every shopper who walks past gets surveyed. If 100 regulars and 20 casuals answer and you take the simple average, you've written a report about regulars with a cameo from casuals — but the fix is obvious: weight each casual's answer five times more than each regular's, because casuals were five times less likely to walk past the entrance in the first place.

Online surveys work the same way, except the "entrance" is your email deliverability, inbox noise, app engagement, push-notification opt-ins, and a dozen other things that determine whether a user sees and responds to your survey. You don't know any specific user's true response probability, but you can estimate it, because the same characteristics that drive response probability are sitting right there in your data: app opens, order frequency, basket size, account tenure, and so on. Fit a model that predicts *responded* from those features, and for each respondent you get back a number between 0 and 1 — their **propensity score**, the probability that a user like them responded.

Once you have that number, the correction is a weighted average: each respondent carries a weight equal to the inverse of their propensity score, so a user with a 5% estimated probability of responding counts for twenty users like them, and a user with a 50% estimated probability counts for two. The estimator traces back to [Horvitz and Thompson (1952)](https://www.tandfonline.com/doi/abs/10.1080/01621459.1952.10483446) for survey sampling, was extended to observational data via the propensity-score concept by [Rosenbaum and Rubin (1983)](https://academic.oup.com/biomet/article-abstract/70/1/41/240879), and was formalized for nonresponse and missing-data settings — which is exactly what we're doing here — by [Robins, Rotnitzky and Zhao (1994)](https://www.jstor.org/stable/2290910). In its working form:

```
estimate = Σ (y_i · w_i) / Σ w_i,    where   w_i = 1 / ê(x_i)
```

`y_i` is the outcome (1 if respondent *i* said "very likely," 0 otherwise) and `ê(x_i)` is that respondent's estimated propensity score given their observables `x_i`.[^1] That's it — no data is thrown away; every respondent still shows up in the estimate, but underrepresented respondents show up with more weight. That's what we mean by "non-destructive": the bias becomes a correction to the weights, not a deletion from the sample.

[^1]: The ratio form here is technically the Hájek (1971) refinement of pure Horvitz-Thompson — slightly biased but much lower variance, and the default in most survey-weighting packages.
```

- [ ] **Step 2: Verify the three citations in Section 2 are present**

```bash
grep -c "tandfonline.com/doi/abs/10.1080/01621459.1952" posts/2026-04-survey-debiasing.md
grep -c "academic.oup.com/biomet/article-abstract/70/1/41" posts/2026-04-survey-debiasing.md
grep -c "jstor.org/stable/2290910" posts/2026-04-survey-debiasing.md
```
Expected: each returns 1.

- [ ] **Step 3: Commit**

```bash
git add posts/2026-04-survey-debiasing.md
git commit -m "post: add Section 2 (Reweight, don't discard)"
```

---

### Task 5: Append Section 3 — "The worked example"

**Files:**
- Modify: `posts/2026-04-survey-debiasing.md`

Source: design doc section `### Section 3 — The worked example` (~525 words + 3 R snippets).

**IMPORTANT:** this section contains the `[survey_debiasing_simulation.R](https://github.com/...)` placeholder URL. Do not resolve it in this task — Task 8 audits and flags it.

- [ ] **Step 1: Append Section 3**

Append to the post file:

```markdown

## The worked example

The simulation in the repo ([`survey_debiasing_simulation.R`](https://github.com/...)) generates 150,000 users with realistic marketplace characteristics, selects 1,001 respondents with a bias toward engaged and high-spending users, and walks through the IPW correction. Here's what each step looks like in code and what the numbers say.

**Step 1 — Look at respondents vs. population.** The invited users average 38 years old, are 29% female, spend ~$2,100 per year on the platform, and open the app ~13 times per month. The 1,001 who actually responded are older (41), less female (21%), spend about five times more (~$10,800/year), and open the app ~60% more often (21 times per month). The direction of the tilt is what you'd expect, and the magnitude is larger than you might guess on priors.

**Step 2 — Fit a propensity model.** Regress *responded* on user observables:

​```r
propensity_model <- glm(
  responded ~ age + female + has_revenue + deposits_per_year +
              withdrawals_per_year + monthly_app_opens,
  data = population,
  family = binomial(link = "logit")
)
​```

Every predictor is significant at p < 0.01; app opens dominate practically (each additional monthly open bumps log-odds of responding by ~0.14, which compounds fast). The resulting propensity scores average **15.6% among actual respondents** vs. **0.6% among non-respondents** — respondents are, on average, twenty-seven times more likely to respond than non-respondents. That's your selection bias, measured directly.

**Step 3 — Compute weights.** For each respondent, the inverse-propensity weight `w_i = 1/ê(x_i)`. Some respondents have tiny estimated propensities, which produces huge weights — the mean raw weight is 89 and the max is 3,073. Extreme weights inflate variance, so practitioners usually compute a **trimmed** variant that caps weights at, say, the 95th percentile (here: 395) and a **stabilized** variant that scales by the overall response rate. All three are in the script:

​```r
trim_threshold <- min(quantile(weight_raw, 0.95, na.rm = TRUE),
                      5 * mean(weight_raw, na.rm = TRUE))
weight_trimmed    <- pmin(weight_raw, trim_threshold)
weight_stabilized <- (n_respondents / n_invited) / propensity_score
​```

**Step 4 — Compute the weighted estimate.**

​```r
debiased <- sum(interest * weight_trimmed) / sum(weight_trimmed)
​```

**The headline:** the naive estimate is **40.9%**, the debiased estimate with trimmed weights is **26.7%**, and with raw or stabilized weights is **22.9%**. The naive number overstated demand by **14–18 percentage points** — in headcount terms, the difference between telling your team *"~61,000 users want one-hour delivery"* and telling them *"~34,000–40,000 do."* Same survey, very different business decision.

The trimmed estimate (26.7%) sits between naive and raw because capping extreme weights pulls the correction back toward the center. Raw (22.9%) is closer to unbiased under correct specification; trimmed is more robust to extreme weights and has a larger effective sample size (290 vs 130 in this run). Report both: **trimmed as your point estimate, raw alongside as a robustness check.**
```

NOTE to executor: the `​```r` blocks above are shown with zero-width spaces before the triple-backtick to avoid confusing this plan's own markdown parser. When you paste into the post file, use plain triple-backtick `r` code fences (no zero-width spaces).

- [ ] **Step 2: Verify all numerical claims match the simulation output**

```bash
for claim in "40.9%" "26.7%" "22.9%" "14–18 percentage points" "15.6%" "0.6%" "twenty-seven" "~61,000" "34,000–40,000"; do
  if grep -q "$claim" posts/2026-04-survey-debiasing.md; then
    echo "FOUND: $claim"
  else
    echo "MISSING: $claim"
  fi
done
```
Expected: every claim prints "FOUND".

- [ ] **Step 3: Commit**

```bash
git add posts/2026-04-survey-debiasing.md
git commit -m "post: add Section 3 (worked R example)"
```

---

### Task 6: Append Section 4 — "Assumptions, triaged by how much they can bite you"

**Files:**
- Modify: `posts/2026-04-survey-debiasing.md`

Source: design doc section `### Section 4 — Assumptions, triaged by how much they can bite you` (~565 words). Contains anchors [Little & Rubin 2019], [Rosenbaum 1987], [VanderWeele & Ding 2017].

- [ ] **Step 1: Append Section 4**

Append the following to the post file. Sub-section labels (`**Conditional independence...**`, etc.) are intentionally bold inline labels, not H3 headers, so the section reads as a single prose flow rather than a bureaucratic listicle.

```markdown

## Assumptions, triaged by how much they can bite you

Inverse-probability weighting recovers an unbiased population estimate **if** four things hold: conditional independence, positivity, correct model specification, and no interference. Two of those are load-bearing and the other two are usually acknowledged and moved past. Here's the honest version.

**Conditional independence (selection on observables).** This is the whole ballgame. The assumption says that once you've controlled for the observables you put into the propensity model, the only thing separating respondents from non-respondents is random noise *with respect to the outcome you're measuring*. Put differently: after conditioning on app opens, spend, tenure, and the rest of your covariates, nothing *else* about a user correlates both with responding and with wanting one-hour delivery. This is the IPW-for-nonresponse version of the **missing-at-random (MAR) assumption** from the missing-data literature ([Little & Rubin, 2019](https://onlinelibrary.wiley.com/doi/book/10.1002/9781119482260)).

The uncomfortable fact is that **this assumption is inherently untestable from the observed data** — there is no empirical check that validates it, only partial falsifications that can rule out particular violations. Practitioners reason about it with domain knowledge: is there anything that drives both who responds and what they want that isn't in my dataset? A plausible violator in our example is *time pressure* — users who experience chronic time pressure are both more likely to respond to a shopping survey and more likely to want one-hour delivery, but "time pressure" isn't in your feature store. If that's what's going on, the debiased estimate still overstates interest, just less obviously, because the output now looks rigorous.

The best defenses are additive: (i) include every plausibly relevant covariate in the propensity model, (ii) compare multiple propensity specifications for stability (see "correct model specification" below), and (iii) run a formal sensitivity analysis such as [Rosenbaum bounds (1987)](https://academic.oup.com/biomet/article-abstract/74/1/13/217167) or the [E-value (VanderWeele & Ding, 2017)](https://www.acpjournals.org/doi/abs/10.7326/M16-2607) to quantify how much unmeasured selection would be needed to overturn your conclusion.

**Positivity (common support).** Every user must have some nonzero probability of responding. If there are subgroups that literally never respond — a dormant cohort, users in a region your emails don't reach — the method has nothing to extrapolate from, and any near-zero-propensity respondent who does slip through will carry an enormous weight. Unlike conditional independence, this one is directly diagnosable: plot the distribution of estimated propensity scores, look at the weights in the tails, and check for respondent types whose characteristics have no non-respondent analogs.

When positivity fails, you have two options: trim the weights (which shifts your estimand toward the **overlap population** — the cohort where respondent-types and non-respondent-types actually coexist — and stabilizes variance), or restrict the target population to the subset where positivity holds and report for that subset only. In our simulation, 50 respondents had raw weights above the trimming threshold of 395, and capping them shifted the debiased estimate from 22.9% to 26.7% — a 3.9 pp swing driven entirely by a handful of unusual respondents. That sensitivity is why trimmed and raw estimates should both be reported.

**Correct specification, interference, and measurement error (briefly).** Three other assumptions fail more quietly. *Model specification*: your propensity model has to actually capture P(respond | X). Logistic regression with main effects is a defensible starting point; gradient-boosted trees or random forests give you more flexibility, and comparing specifications is a cheap way to spot-check stability. *No interference*: one user's response shouldn't affect another's — usually fine, occasionally broken if users discuss the survey in group chats. *No measurement error*: your covariates are observed accurately. For marketplace signals like app opens and spend this is almost always met; for self-reported fields, less so.
```

- [ ] **Step 2: Verify the three citations and the unfalsifiability framing are present**

```bash
grep -c "onlinelibrary.wiley.com/doi/book/10.1002/9781119482260" posts/2026-04-survey-debiasing.md
grep -c "academic.oup.com/biomet/article-abstract/74/1/13" posts/2026-04-survey-debiasing.md
grep -c "acpjournals.org/doi/abs/10.7326/M16-2607" posts/2026-04-survey-debiasing.md
grep -c "inherently untestable from the observed data" posts/2026-04-survey-debiasing.md
```
Expected: each returns 1.

- [ ] **Step 3: Commit**

```bash
git add posts/2026-04-survey-debiasing.md
git commit -m "post: add Section 4 (assumptions, triaged)"
```

---

### Task 7: Append Section 5 — "Putting it to work" (closer)

**Files:**
- Modify: `posts/2026-04-survey-debiasing.md`

Source: design doc section `### Section 5 — Putting it to work (closer)` (~185 words).

- [ ] **Step 1: Append Section 5**

Append to the post file:

```markdown

## Putting it to work

A three-step workflow for your next sub-5%-response-rate survey:

1. **Inspect the tilt.** Compare summary statistics for respondents vs. the invited population on every observable you have. If they're indistinguishable, stop — you don't have a bias problem to fix. They won't be.
2. **Fit a propensity model.** Logistic regression with all your covariates is a reasonable default; swap in gradient-boosted trees when your feature set grows or effects are nonlinear. Save the predicted propensities.
3. **Report both numbers plus the sensitivity.** Publish the naive estimate, the trimmed-IPW debiased estimate, and the raw-IPW debiased estimate side-by-side. The gap between them is your best summary of how much the selection bias is doing. In our example that gap was **40.9% → 26.7% → 22.9%** — the difference between shipping one-hour delivery as a mass-market product or a premium niche.

The non-destructive principle: don't throw biased survey data away, and don't pretend it isn't biased. Fit the propensity model, weight honestly, and tell the whole story.
```

- [ ] **Step 2: Verify the three-step checklist reads correctly**

```bash
grep -c "Inspect the tilt" posts/2026-04-survey-debiasing.md
grep -c "Fit a propensity model" posts/2026-04-survey-debiasing.md
grep -c "Report both numbers plus the sensitivity" posts/2026-04-survey-debiasing.md
grep -c "non-destructive principle" posts/2026-04-survey-debiasing.md
```
Expected: each returns 1.

- [ ] **Step 3: Commit**

```bash
git add posts/2026-04-survey-debiasing.md
git commit -m "post: add Section 5 (closer with 3-step workflow)"
```

---

### Task 8: Append References block and resolve placeholder repo URL

**Files:**
- Modify: `posts/2026-04-survey-debiasing.md`

Source: design doc section `## 3. References`. The post's References block uses numbered references (1–11).

- [ ] **Step 1: Append the References block**

Append to the post file, preceded by a horizontal rule (`---`) to visually separate it from the closer:

```markdown

---

## References

1. Bradley, V. C., Kuriwaki, S., Isakov, M., Sejdinovic, D., Meng, X.-L., & Flaxman, S. (2021). Unrepresentative big surveys significantly overestimated US vaccine uptake. *Nature*, 600, 695–700.
2. Groves, R. M. (2006). Nonresponse rates and nonresponse bias in household surveys. *Public Opinion Quarterly*, 70(5), 646–675.
3. Hájek, J. (1971). Comment on "An Essay on the Logical Foundations of Survey Sampling, Part One" by D. Basu. In *Foundations of Statistical Inference*, p. 236. Holt, Rinehart & Winston.
4. Horvitz, D. G., & Thompson, D. J. (1952). A generalization of sampling without replacement from a finite universe. *Journal of the American Statistical Association*, 47(260), 663–685.
5. Little, R. J. A., & Rubin, D. B. (2019). *Statistical Analysis with Missing Data* (3rd ed.). Wiley.
6. Meng, X.-L. (2018). Statistical paradises and paradoxes in big data (I): Law of large populations, big data paradox, and the 2016 US presidential election. *Annals of Applied Statistics*, 12(2), 685–726.
7. Robins, J. M., Rotnitzky, A., & Zhao, L. P. (1994). Estimation of regression coefficients when some regressors are not always observed. *Journal of the American Statistical Association*, 89(427), 846–866.
8. Rosenbaum, P. R. (1987). Sensitivity analysis for certain permutation inferences in matched observational studies. *Biometrika*, 74(1), 13–26.
9. Rosenbaum, P. R., & Rubin, D. B. (1983). The central role of the propensity score in observational studies for causal effects. *Biometrika*, 70(1), 41–55.
10. Tigre, R. (2023). *A Data-Driven Way of Using Client Feedback in Product Development*. Medium.
11. VanderWeele, T. J., & Ding, P. (2017). Sensitivity analysis in observational research: Introducing the E-value. *Annals of Internal Medicine*, 167(4), 268–274.
```

- [ ] **Step 2: Audit the `github.com/...` placeholder and prompt the author**

```bash
grep -n "https://github.com/\.\.\." posts/2026-04-survey-debiasing.md
```
Expected: prints one line (the placeholder in Section 3). The author must replace `https://github.com/...` with the actual public repo URL before publication.

Once the author provides the URL (or decides to drop the link), replace in-place:
```bash
# Example once the URL is known:
# sed -i '' 's|https://github.com/\.\.\.|https://github.com/robsontigre/survey-debiasing|' posts/2026-04-survey-debiasing.md
```

- [ ] **Step 3: Commit**

```bash
git add posts/2026-04-survey-debiasing.md
git commit -m "post: add References block; flag repo URL placeholder"
```

---

### Task 9: Quality gate — URL resolution check

**Purpose:** verify every external citation link in the post resolves to HTTP 200 (not 404, not a redirect chain that ends in error). Failed URLs must be corrected before publication.

- [ ] **Step 1: Extract all URLs from the post**

```bash
grep -oE 'https?://[^ )]+' posts/2026-04-survey-debiasing.md | sort -u > /tmp/post-urls.txt
wc -l /tmp/post-urls.txt
```
Expected: approximately 11 unique URLs (one per reference + possibly the repo URL once resolved).

- [ ] **Step 2: Check each URL resolves**

```bash
while read -r url; do
  status=$(curl -s -o /dev/null -w "%{http_code}" -L --max-time 15 "$url")
  echo "$status $url"
done < /tmp/post-urls.txt
```
Expected: every line begins with `200`. Any `404`, `403`, or timeouts must be investigated.

Note: academic publisher sites (Oxford Academic, Wiley, Taylor & Francis, JSTOR, Annals of Internal Medicine) sometimes return `200` with a paywall page — that's expected. The *URL itself* must resolve; page content may be gated.

- [ ] **Step 3: If any URL fails, fix it**

- For the `https://github.com/...` placeholder, confirm resolution with the author (Task 8 Step 2).
- For any citation URL that 404s, re-verify the citation via web search and update the link in the post.
- Do not commit broken URLs.

- [ ] **Step 4: Commit only if fixes were needed**

```bash
git add posts/2026-04-survey-debiasing.md
git commit -m "post: fix broken URL(s) from resolution audit"
```
If no fixes were needed, skip the commit.

---

### Task 10: Quality gate — numerical-claim audit

**Purpose:** confirm every numerical claim in the post matches either the R simulation output (for Section 3) or a verified external source (for Sections 1 and 4).

- [ ] **Step 1: Re-run the simulation and capture output**

```bash
Rscript survey_debiasing_simulation.R 2>&1 | tee /tmp/sim-output.txt
```
Expected: runs successfully. Output contains respondent profile, propensity model summary, weight statistics, and estimate comparison table.

- [ ] **Step 2: Cross-check numerical claims against simulation output**

The post's numerical claims and their sources:

| Claim in post | Source | Expected in sim output |
|---|---|---|
| 150,000 invited | sim constant | `Sample size: 150000` |
| 1,001 respondents | sim constant | `Sample size: 1001` |
| 40.9% naive | sim | `40.9%` |
| 22.9% raw IPW | sim | `22.9%` |
| 26.7% trimmed IPW | sim | `26.7%` |
| 14–18 pp bias | computed | `+18.0` and `+14.1` |
| 15.6% propensity among respondents | sim | `Mean: 0.1557` |
| 0.6% propensity among non-respondents | sim | `Mean: 0.0057` |
| twenty-seven times (0.1557 / 0.0057 ≈ 27.3) | computed | ratio check |
| mean raw weight 89 | sim | `Mean: 88.9` |
| max raw weight 3,073 | sim | `Range: 1 to 3073` |
| trimming threshold 395 | sim | `Trimming threshold: 395` |
| 50 respondents trimmed | sim | `# weights trimmed: 50` |
| effective N 130 (raw) | sim | `130.` in `Effective N` |
| effective N 290 (trimmed) | sim | `290.` in `Effective N` |

Run:
```bash
for pattern in "Sample size: 150000" "Sample size: 1001" "40.9%" "22.9%" "26.7%" "+18.0" "+14.1" "Mean: 0.1557" "Mean: 0.0057" "Mean: 88.9" "Range: 1 to 3073" "Trimming threshold: 395" "# weights trimmed: 50"; do
  if grep -q "$pattern" /tmp/sim-output.txt; then
    echo "VERIFIED: $pattern"
  else
    echo "MISSING in sim output: $pattern"
  fi
done
```
Expected: every pattern "VERIFIED".

Cross-check the respondent profile numbers:

| Claim | Expected in sim output |
|---|---|
| avg respondent age 41 | `Average age: 40.9` |
| respondents 21% female | `Female proportion: 20.8%` |
| respondents spend ~$10,800/year | `Mean deposits (per year): $10,754.91` |
| respondents open app 21 times/month | `Monthly app opens: 21` |

- [ ] **Step 3: Cross-check Section 1 numerical claims against Meng 2018 and Bradley 2021**

These cannot be re-derived programmatically. Verify by re-reading the source papers:
- Meng (2018): 2.3M CCES respondents, –0.005 data-defect correlation, effective n ≈ 400, 99.98% reduction.
- Bradley et al. (2021): Delphi–Facebook ~250K/week, +17 pp overestimate of vaccine uptake; Census Household Pulse ~75K/2 weeks, +14 pp overestimate. May 2021 snapshot.

If any of these are misstated in the post, correct against the primary sources.

- [ ] **Step 4: Commit only if fixes were needed**

```bash
git add posts/2026-04-survey-debiasing.md
git commit -m "post: correct numerical claim(s) against sources"
```

---

### Task 11: Quality gate — fluid-prose style pass

**Purpose:** enforce the saved user preference (memory: `feedback_writing_style.md`) that logically-connected clauses should be joined into fluid sentences rather than chained with periods.

- [ ] **Step 1: Read the post end-to-end and flag choppy passages**

Open `posts/2026-04-survey-debiasing.md`. Read each section as if reading aloud. For every place where two or three consecutive short sentences describe one coherent thought/scene/causal chain, consider joining them with a comma, em-dash, semicolon, or conjunction.

**Heuristic: this sentence starts with one of these openers, and the previous sentence ends without a full stop beat:**
- "It..." / "This..." / "That..." — often a continuation in disguise.
- "And..." / "But..." / "So..." — often joinable with the prior sentence.
- A sentence under 8 words directly following another short one on the same topic.

**Examples of joins that are NOT allowed:**
- Do not join sentences that mark a genuine break (new paragraph-level topic shift, a punch line, a deliberate pause).
- Do not create run-ons. If the joined sentence exceeds ~40 words, split it back.

- [ ] **Step 2: Apply joins inline**

For each flagged passage, edit to produce a fluid version. Keep the prose faithful to the content; only change punctuation and connectors.

- [ ] **Step 3: Word-count check**

```bash
wc -w posts/2026-04-survey-debiasing.md
```
Expected: approximately 2,400–2,650 words (design budget is ~2,540; style edits typically don't shift the count by more than ±100).

If the post is under 2,200 or over 2,800 words, re-read for accidental deletion or verbosity creep. Budgets per section (design doc):
- TL;DR ~110 words
- Hook ~205 words
- Section 1 ~475 words
- Section 2 ~475 words
- Section 3 ~525 words
- Section 4 ~565 words
- Section 5 (closer) ~185 words

- [ ] **Step 4: Commit only if fixes were needed**

```bash
git add posts/2026-04-survey-debiasing.md
git commit -m "post: fluid-prose style pass"
```

---

### Task 12: Create companion R script with marketplace-native variable names

**Purpose:** produce a companion R script for the Substack post that uses marketplace-native variable names (so the code snippets read cleanly with the prose), without modifying the original `survey_debiasing_simulation.R`. The original script stays as the reference implementation; the companion script is what the post links to.

**Files:**
- Keep unchanged: `survey_debiasing_simulation.R` (reference implementation)
- Create: `survey_debiasing_marketplace.R` (companion for the post)
- Modify: `posts/2026-04-survey-debiasing.md` (Section 3 code snippet + repo link to point at companion script)

- [ ] **Step 1: Copy the original script to the companion path**

```bash
cp survey_debiasing_simulation.R survey_debiasing_marketplace.R
```

- [ ] **Step 2: Rename variables in the companion script only**

Open `survey_debiasing_marketplace.R` and apply the following renames. Order matters: do the `_std` suffixed names BEFORE the base names to avoid substring collisions.

| Old name | New name |
|---|---|
| `deposits_std` | `spend_std` |
| `withdrawals_std` | `refunds_std` |
| `deposits_per_year` | `annual_spend` |
| `withdrawals_per_year` | `annual_refunds` |
| `has_revenue` | `has_made_purchase` |
| `"Mean deposits (per year):"` | `"Mean annual spend:"` |
| `"Mean withdrawals (per year):"` | `"Mean annual refunds:"` |
| `"Has revenue:"` | `"Has made purchase:"` |

Also update the header comment block at the top of the script to say "companion script for the Substack post" and reference `posts/2026-04-survey-debiasing.md`.

Also update the betting-specific comments (e.g., "would use the betting feature") to marketplace-native ("would use one-hour delivery"). The DGP (coefficient values, distributions, seeds) stays identical — only names and narrative comments change.

- [ ] **Step 3: Re-run the companion script and confirm numbers match the reference within tolerance**

```bash
Rscript survey_debiasing_marketplace.R 2>&1 | tee /tmp/sim-output-marketplace.txt
```
Expected: because `set.seed(42)` and the DGP are identical, key numbers must be **exactly** the same as the reference run — naive 40.9%, raw 22.9%, trimmed 26.7%, effective N 130/290, trimming threshold 395. Any deviation means a variable was renamed inconsistently; fix before proceeding.

Verification check:
```bash
for pattern in "Sample size: 150000" "Sample size: 1001" "40.9%" "22.9%" "26.7%" "Mean: 0.1557" "Trimming threshold: 395" "# weights trimmed: 50"; do
  if grep -q "$pattern" /tmp/sim-output-marketplace.txt; then
    echo "MATCH: $pattern"
  else
    echo "MISS: $pattern — companion script output diverged"
  fi
done
```
Expected: every line prints "MATCH".

- [ ] **Step 4: Update Section 3's first R snippet in the post to match new names**

In `posts/2026-04-survey-debiasing.md`, replace the `glm(...)` block in Section 3 with:

```r
propensity_model <- glm(
  responded ~ age + female + has_made_purchase + annual_spend +
              annual_refunds + monthly_app_opens,
  data = population,
  family = binomial(link = "logit")
)
```

The other two R snippets (weight calculation, weighted mean) don't name these variables and stay as-is.

- [ ] **Step 5: Update the repo link in Section 3 to point at the companion script**

Replace `[survey_debiasing_simulation.R](https://github.com/...)` in Section 3 with `[survey_debiasing_marketplace.R](https://github.com/...)`. (The `https://github.com/...` placeholder remains for author resolution per Task 8.)

- [ ] **Step 6: Skim Section 3 for lingering fintech language**

Search the post for any lingering `deposits` or `withdrawals` words:
```bash
grep -nE "deposits|withdrawals" posts/2026-04-survey-debiasing.md
```
Expected: zero matches. If any, correct in-place.

- [ ] **Step 7: Commit**

```bash
git add survey_debiasing_marketplace.R posts/2026-04-survey-debiasing.md
git commit -m "add companion R script with marketplace-native names; sync post"
```

---

## Self-review checklist

After executing Tasks 1–11 (plus Task 12 if opted in), confirm:

- [ ] **Spec coverage:** every section in the design doc (TL;DR, hook, Sections 1–5, References) has a corresponding task that produced it in the post.
- [ ] **No placeholders remain:** the only placeholder in this plan (`github.com/...`) is explicitly flagged by Task 8 for author resolution; no other "TBD", "TODO", or unresolved references.
- [ ] **URL resolution:** every external link in the post returned HTTP 200 in Task 9.
- [ ] **Numerical claims:** every number in the post matches the simulation output (Task 10) or a verified external source (Meng 2018 / Bradley 2021 / Groves 2006).
- [ ] **Style:** the fluid-prose pass (Task 11) was run end-to-end.
- [ ] **Word count:** the post is within the 2,400–2,650 word band.
- [ ] **Commit history:** each task produced a clean commit with a descriptive message; no amended history, no force-pushes.
- [ ] **Design doc integrity:** `docs/plans/2026-04-21-survey-debiasing-post-design.md` is unchanged by this execution — it remains the source of truth.

## Follow-ups explicitly out of scope for this plan

These items were noted in the design doc but are deferred — they require author input or judgment calls the plan shouldn't pre-empt:

1. **Figures.** Two figures suggested (weight distribution with trimming threshold; naive-vs-debiased bar chart). Author produces from the R script at publication time and inserts in the Substack compose view, not the markdown file.
2. **Overlap weights mention (Li, Morgan & Zaslavsky, 2018).** Modern alternative to trimming; not included. Add only if the author wants to signal frontier-practice awareness.
3. **Substack theme-specific formatting.** The IPW formula is in a plain code block; if the author's theme supports KaTeX, upgrading to `$$...$$` rendering is a publication-time polish, not a repo-level change.
4. **Commit of the design doc.** The design doc at `docs/plans/2026-04-21-survey-debiasing-post-design.md` has not been committed yet — the author should decide whether to include it in the same commit series as the post, or in a separate "design artifact" commit.
