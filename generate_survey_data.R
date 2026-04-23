# ==============================================================================
# Survey debiasing simulation: data generation
# ==============================================================================
#
# Single source of truth for the simulated marketplace survey dataset used by
# the companion analysis scripts. Running this script produces
#
#     data/survey_population.csv
#
# which is read unchanged by both survey_debiasing_marketplace.R and
# survey_debiasing_marketplace.py, so the two languages produce identical
# numbers end-to-end.
#
# Scenario: 150,000 marketplace users are invited to a survey about a new
# one-hour delivery tier. Only 1,001 respond, and response probability is
# correlated with user characteristics (age, engagement, spend). The "invited"
# group is taken as representative of the population of interest; the
# respondents are the self-selected subset.
#
# Dependencies: tidyverse
# ==============================================================================

library(tidyverse)

set.seed(42)

# ------------------------------------------------------------------------------
# STEP 1: Generate the full invited population (150,000 users)
# ------------------------------------------------------------------------------

n_invited     <- 150000
n_respondents <- 1001

population <- tibble(
  user_id = 1:n_invited,

  # Age: mean 38 years, SD ~12, clipped to [18, 80]
  age = rnorm(n_invited, mean = 38, sd = 12) %>%
    pmax(18) %>% pmin(80),

  # Female: 29% of population
  female = rbinom(n_invited, size = 1, prob = 0.29),

  # Has revenue: 94.8% of users
  has_made_purchase = rbinom(n_invited, size = 1, prob = 0.948),

  # Annual spend: mean ~$2,145, right-skewed (log-normal)
  annual_spend = rlnorm(n_invited, meanlog = log(2145) - 0.5, sdlog = 1) %>%
    pmax(0),

  # Annual refunds: correlated with spend via multiplicative noise
  annual_refunds = annual_spend * rnorm(n_invited, mean = 0.8, sd = 0.3) %>%
    pmax(0),

  # Monthly app opens: mean 13, negative binomial with overdispersion
  monthly_app_opens = rnbinom(n_invited, mu = 13, size = 5) %>%
    pmax(0)
)

# ------------------------------------------------------------------------------
# STEP 2: Induce response selection bias
# ------------------------------------------------------------------------------
#
# More engaged, higher-value users are more likely to respond. The DGP below
# is what the analyst would NOT know in the real world; in the analysis script
# we only use observable user characteristics, not these latent probabilities.

population <- population %>%
  mutate(
    age_std       = (age - mean(age)) / sd(age),
    spend_std     = (annual_spend - mean(annual_spend)) / sd(annual_spend),
    refunds_std   = (annual_refunds - mean(annual_refunds)) / sd(annual_refunds),
    app_opens_std = (monthly_app_opens - mean(monthly_app_opens)) / sd(monthly_app_opens)
  )

population <- population %>%
  mutate(
    logit_response = -6.5 +
      0.4 * age_std +             # Older respond more
      -0.6 * female +             # Males respond more
      0.5 * has_made_purchase +   # Revenue users respond more
      0.6 * spend_std +           # High spenders respond more
      0.5 * refunds_std +         # High refunders respond more
      1.2 * app_opens_std,        # Engaged users respond MUCH more
    prob_response = plogis(logit_response)
  )

respondent_ids <- sample(
  x    = population$user_id,
  size = n_respondents,
  prob = population$prob_response
)

population <- population %>%
  mutate(responded = if_else(user_id %in% respondent_ids, 1, 0))

# ------------------------------------------------------------------------------
# STEP 3: Assign outcome (interest in one-hour delivery) for respondents
# ------------------------------------------------------------------------------
#
# Among respondents, 40.9% express interest. Interest correlates with
# engagement, which is also what drives response - this double selection is
# exactly the bias the debiasing analysis is meant to correct.

respondents <- population %>% filter(responded == 1)

respondents <- respondents %>%
  mutate(
    logit_interest = -0.8 +
      0.3 * age_std +
      0.2 * (1 - female) +
      0.4 * app_opens_std +
      0.3 * spend_std,
    prob_interest = plogis(logit_interest),
    interest_temp = rbinom(n(), size = 1, prob = prob_interest)
  )

# Force exact 40.9% interest rate by flipping the minimum number of entries
target_interested  <- round(n_respondents * 0.409)
current_interested <- sum(respondents$interest_temp)

if (current_interested != target_interested) {
  if (current_interested < target_interested) {
    zeros    <- which(respondents$interest_temp == 0)
    flip_idx <- sample(zeros, target_interested - current_interested)
    respondents$interest_temp[flip_idx] <- 1
  } else {
    ones     <- which(respondents$interest_temp == 1)
    flip_idx <- sample(ones, current_interested - target_interested)
    respondents$interest_temp[flip_idx] <- 0
  }
}

respondents <- respondents %>%
  mutate(interest = interest_temp) %>%
  select(user_id, interest)

# Merge interest back to the full population; non-respondents get NA
population <- population %>%
  left_join(respondents, by = "user_id")

# ------------------------------------------------------------------------------
# STEP 4: Write the CSV consumed by both analysis scripts
# ------------------------------------------------------------------------------
#
# Keep only the columns the analysis needs: user-level observables, the
# response indicator, and the outcome (NA for non-respondents). The standardized
# helper columns used inside the DGP are deliberately dropped - the analysis
# script should not see them.

out <- population %>%
  select(
    user_id,
    age,
    female,
    has_made_purchase,
    annual_spend,
    annual_refunds,
    monthly_app_opens,
    responded,
    interest
  )

dir.create("data", showWarnings = FALSE)
write_csv(out, "data/survey_population.csv")

cat("Wrote data/survey_population.csv\n")
cat("  rows:", nrow(out), "\n")
cat("  respondents:", sum(out$responded), "\n")
cat("  interested among respondents:", sum(out$interest, na.rm = TRUE), "\n")
