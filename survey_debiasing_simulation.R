# ==============================================================================
# Survey debiasing simulation: the case of the betting feature
# ==============================================================================
# 
# This script simulates a survey scenario where 150,000 users were invited to 
# answer whether they'd use a betting feature, but only 1,001 responded.
# 
# The problem: Respondents differ systematically from the full population
# (they're more engaged, older, more male, higher transactions).
# 
# The solution: Use propensity score weighting to "debias" the estimate,
# giving more weight to underrepresented types of respondents.
#
# ==============================================================================

# ------------------------------------------------------------------------------
# Setup: Load libraries
# ------------------------------------------------------------------------------

library(tidyverse)    # Data manipulation and visualization
library(scales)       # For formatting numbers and percentages
library(patchwork)    # For combining plots

# Set seed for reproducibility
set.seed(42)

# ------------------------------------------------------------------------------
# STEP 1: Generate the full population (150,000 invited users)
# ------------------------------------------------------------------------------

n_invited <- 150000
n_respondents <- 1001

# Create the full population with characteristics matching "Original Population"
population <- tibble(
  user_id = 1:n_invited,
  
  # Age: mean 38 years, standard deviation ~12
  age = rnorm(n_invited, mean = 38, sd = 12) %>% 
    pmax(18) %>% pmin(80),  # Constrain between 18 and 80
  
  # Female: 29% of population
  female = rbinom(n_invited, size = 1, prob = 0.29),
  
  # Has revenue: 94.8% of users
  has_revenue = rbinom(n_invited, size = 1, prob = 0.948),
  
  # Deposits per year: mean $2,145, with realistic right skew
  # Using log-normal distribution to get positive skew
  deposits_per_year = rlnorm(n_invited, meanlog = log(2145) - 0.5, sdlog = 1) %>%
    pmax(0),
  
  # Withdrawals per year: mean $1,747, correlated with deposits
  # People who deposit more tend to withdraw more
  withdrawals_per_year = deposits_per_year * rnorm(n_invited, mean = 0.8, sd = 0.3) %>%
    pmax(0),
  
  # Monthly app opens: mean 13, Poisson-like but with overdispersion
  monthly_app_opens = rnbinom(n_invited, mu = 13, size = 5) %>%
    pmax(0)
)

# Verifying characteristics: Mean values of the population invited to the survey.
cat("- Sample size:", nrow(population), "\n")
cat("- Average age:", round(mean(population$age), 1), "years\n")
cat("- Female proportion:", percent(mean(population$female), accuracy = 0.1), "\n")
cat("- Has revenue:", percent(mean(population$has_revenue), accuracy = 0.1), "\n")
cat("- Mean deposits (per year):", dollar(mean(population$deposits_per_year)), "\n")
cat("- Mean withdrawals (per year):", dollar(mean(population$withdrawals_per_year)), "\n")
cat("- Monthly app opens:", round(mean(population$monthly_app_opens), 0), "\n")

# ------------------------------------------------------------------------------
# STEP 2: Create selection bias - who responds?
# ------------------------------------------------------------------------------

# More engaged, higher-value users are MORE LIKELY to respond the survey.
# I use a logistic function that increases probability of response based on user characteristics.

# Standardize predictors for stable coefficients
## 1. Makes coefficients comparable when designing selection bias
## 2. Prevents numerical issues in the logistic regression
## Note: Standardization is NOT required for debiasing to work. I only standardized for the simulation setup (creating realistic selection bias with interpretable coefficients), not for the methodology itself.
population <- population %>%
  mutate(
    age_std = (age - mean(age)) / sd(age),
    deposits_std = (deposits_per_year - mean(deposits_per_year)) / sd(deposits_per_year),
    withdrawals_std = (withdrawals_per_year - mean(withdrawals_per_year)) / sd(withdrawals_per_year),
    app_opens_std = (monthly_app_opens - mean(monthly_app_opens)) / sd(monthly_app_opens)
  )

# This is the Data Generating Process (DGP) for selection bias. We're playing god here...
# In the real world, I would NEVER know this DGP. I would only know the characteristics of the respondents.
# These coefficients measure the selection bias as follows:
# - Older users more likely to respond (+)
# - More engaged users (app opens) more likely to respond (++)
# - Higher transaction users more likely to respond (+)
# - Male users more likely to respond (female has negative coefficient)
# - Users with revenue more likely to respond (+)

population <- population %>%
  mutate(
    # Linear predictor (log-odds of responding)
    logit_response = -6.5 +                      
                     0.4 * age_std +             # Older respond more
                     -0.6 * female +             # Males respond more
                     0.5 * has_revenue +         # Revenue users respond more
                     0.6 * deposits_std +        # High depositors respond more
                     0.5 * withdrawals_std +     # High withdrawers respond more
                     1.2 * app_opens_std,        # Engaged users respond MUCH more
    
    # Convert log-odds to probability
    prob_response = plogis(logit_response)
  )

# Now I sample respondents based on these probabilities
respondent_ids <- sample( # Here I'm sampling the 1001 respondents based on the probabilities of responding.
  x = population$user_id,
  size = n_respondents,
  prob = population$prob_response
)

# Create the `Responded` indicator (STEP 2 from methodology)
population <- population %>%
  mutate(
    responded = if_else(user_id %in% respondent_ids, 1, 0)
  )

# Verify respondent characteristics match the target
respondents <- population %>% filter(responded == 1) # Here I'm filtering the population to only include the 1001 respondents.

# Respondents Summary: Mean values of the respondents.
cat("- Sample size:", nrow(respondents), "\n")
cat("- Average age:", round(mean(respondents$age), 1), "years\n")
cat("- Female proportion:", percent(mean(respondents$female), accuracy = 0.1), "\n")
cat("- Has revenue:", percent(mean(respondents$has_revenue), accuracy = 0.1), "\n")
cat("- Mean deposits (per year):", dollar(mean(respondents$deposits_per_year)), "\n")
cat("- Mean withdrawals (per year):", dollar(mean(respondents$withdrawals_per_year)), "\n")
cat("- Monthly app opens:", round(mean(respondents$monthly_app_opens), 0), "\n")

# Selection bias successfully created! Respondents are older, more male, more engaged, and transact more.

# ------------------------------------------------------------------------------
# STEP 3: Assign survey responses (interest variable = user interested in betting feature)
# ------------------------------------------------------------------------------

# Among respondents, 40.9% express interest (Muy probable or Algo probable)
# But interest correlates with engagement!
# Users who are highly engaged are ALSO more interested in betting features.
# This creates the bias we need to correct for.

respondents <- respondents %>%
  mutate(
    # Interest probability depends on user engagement
    # More engaged users are more likely to be interested
    logit_interest = -0.8 +                     # Base interest rate
                     0.3 * age_std +            # Older slightly more interested
                     0.2 * (1 - female) +       # Males slightly more interested
                     0.4 * app_opens_std +      # Engaged users MORE interested
                     0.3 * deposits_std,        # High value users MORE interested
    
    prob_interest = plogis(logit_interest),
    
    # Sample interest to get approximately 40.9% overall
    # I'll adjust the intercept if needed to hit exact target
    interest_temp = rbinom(n(), size = 1, prob = prob_interest)
  )

# Adjust to get exactly 40.9% interested
target_interested <- round(n_respondents * 0.409)
current_interested <- sum(respondents$interest_temp)

if (current_interested != target_interested) {
  # Adjust by randomly flipping some responses
  if (current_interested < target_interested) {
    # Need more interested: flip some 0s to 1s
    zeros <- which(respondents$interest_temp == 0)
    flip_idx <- sample(zeros, target_interested - current_interested)
    respondents$interest_temp[flip_idx] <- 1
  } else {
    # Need fewer interested: flip some 1s to 0s
    ones <- which(respondents$interest_temp == 1)
    flip_idx <- sample(ones, current_interested - target_interested)
    respondents$interest_temp[flip_idx] <- 0
  }
}

respondents <- respondents %>%
  mutate(interest = interest_temp) %>%
  select(-interest_temp, -prob_interest, -logit_interest)

# Interest variable summary: # respondents with interest = 1 and the % respondents with interest.
cat("- Respondents with Interest = 1:", sum(respondents$interest), # 409 users interested in betting feature
    paste0("(", percent(mean(respondents$interest), accuracy = 0.1), ")\n"))
cat("- This represents those who answered 'Muy probable' or 'Algo probable'\n")

# Merge interest back to main population (only respondents have it)
population <- population %>%
  left_join(
    respondents %>% select(user_id, interest),
    by = "user_id"
  )

# Here ends the data generating process (DGP) for the selection bias. 
# The next step is the one starting the debiasing methodology

# ------------------------------------------------------------------------------
# STEP 4: Fit propensity score model (predict who responds)
# ------------------------------------------------------------------------------

# This is the core of the debiasing methodology.
# I fit a logistic regression to predict who responded based on observable 
# characteristics. The predicted probabilities are the "propensity scores".

propensity_model <- glm(
  responded ~ age + female + has_revenue + deposits_per_year + 
              withdrawals_per_year + monthly_app_opens,
  data = population,
  family = binomial(link = "logit")
)

# Propensity score model summary - each variable's coefficient and p-value.
print(summary(propensity_model))

# Extract propensity scores for everyone
population <- population %>%
  mutate(
    propensity_score = predict(propensity_model, type = "response")
  )

# Propensity score distribution:
# Respondents:
cat("  - Mean:", round(mean(population$propensity_score[population$responded == 1]), 4), "\n")
cat("  - Median:", round(median(population$propensity_score[population$responded == 1]), 4), "\n")
cat("  - Range:", round(min(population$propensity_score[population$responded == 1]), 4), 
    "to", round(max(population$propensity_score[population$responded == 1]), 4), "\n")

# Non-respondents:
cat("  - Mean:", round(mean(population$propensity_score[population$responded == 0]), 4), "\n")
cat("  - Median:", round(median(population$propensity_score[population$responded == 0]), 4), "\n")
cat("  - Range:", round(min(population$propensity_score[population$responded == 0]), 4), 
    "to", round(max(population$propensity_score[population$responded == 0]), 4), "\n")

# ------------------------------------------------------------------------------
# STEP 5: Calculate inverse propensity weights (three variants)
# ------------------------------------------------------------------------------

# I'll calculate three types of weights to compare their impact:
# 1. RAW weights: Simple inverse propensity weights
# 2. TRIMMED weights: Raw weights capped at upper threshold (prevents extreme influence)
# 3. STABILIZED weights: Scaled by overall response rate (reduces variance)
## Stabilized weights are raw weights scaled by a constant to center around 1

# Here is the intuition behind the RAW WEIGHTS:
## For respondents only, calculate weights as 1 / propensity_score.
## Intuition: If someone had only a 5% chance of responding but did respond,
## they should represent 20 people like them (1/0.05 = 20).

# Calculate overall response rate for stabilized weights
response_rate <- n_respondents / n_invited

population <- population %>%
  mutate(
    # 1. RAW WEIGHTS: Standard inverse propensity weights
    # Notice that weights are only defined for respondents
    weight_raw = if_else(responded == 1, 1 / propensity_score, NA_real_)
  )

# Determine trimming threshold (use the lower of 95th percentile or 5x mean - adhoc rule of thumb)
trim_threshold <- min(
  quantile(population$weight_raw, 0.95, na.rm = TRUE),
  5 * mean(population$weight_raw, na.rm = TRUE)
)

# Weight Calculation:
cat("Trimming threshold:", round(trim_threshold, 1), 
    "(lower of 95th percentile or 5x mean)\n")

population <- population %>%
  mutate(
    # 2. TRIMMED WEIGHTS: Cap raw weights at threshold (one-sided, high values only)
    # This prevents extreme weights from dominating the estimate
    weight_trimmed = if_else(responded == 1, 
                             pmin(weight_raw, trim_threshold), 
                             NA_real_),
    
    # 3. STABILIZED WEIGHTS: Multiply by overall response rate
    # Formula: (n_respondents/n_invited) / propensity_score
    # This centers weights around 1 and reduces variance
    # Property: sum(stabilized weights) ≈ n_respondents
    weight_stabilized = if_else(responded == 1, 
                                response_rate / propensity_score, 
                                NA_real_)
  )

# Examine weight distributions for all three types
# RAW WEIGHTS
cat("- Mean:", round(mean(population$weight_raw, na.rm = TRUE), 1), "\n")
cat("- Median:", round(median(population$weight_raw, na.rm = TRUE), 1), "\n")
cat("- Range:", round(min(population$weight_raw, na.rm = TRUE), 1), 
    "to", round(max(population$weight_raw, na.rm = TRUE), 1), "\n")
cat("- Standard deviation:", round(sd(population$weight_raw, na.rm = TRUE), 1), "\n")
cat("- Sum:", round(sum(population$weight_raw, na.rm = TRUE), 0), "\n")

# TRIMMED WEIGHTS
cat("- Mean:", round(mean(population$weight_trimmed, na.rm = TRUE), 1), "\n")
cat("- Median:", round(median(population$weight_trimmed, na.rm = TRUE), 1), "\n")
cat("- Range:", round(min(population$weight_trimmed, na.rm = TRUE), 1), 
    "to", round(max(population$weight_trimmed, na.rm = TRUE), 1), "\n")
cat("- Standard deviation:", round(sd(population$weight_trimmed, na.rm = TRUE), 1), "\n")
cat("- Sum:", round(sum(population$weight_trimmed, na.rm = TRUE), 0), "\n")
cat("- # weights trimmed:", sum(population$weight_raw > trim_threshold, na.rm = TRUE), "\n")

# STABILIZED WEIGHTS
cat("- Mean:", round(mean(population$weight_stabilized, na.rm = TRUE), 3), "\n")
cat("- Median:", round(median(population$weight_stabilized, na.rm = TRUE), 3), "\n")
cat("- Range:", round(min(population$weight_stabilized, na.rm = TRUE), 3), 
    "to", round(max(population$weight_stabilized, na.rm = TRUE), 1), "\n")
cat("- Standard deviation:", round(sd(population$weight_stabilized, na.rm = TRUE), 3), "\n")
cat("- Sum:", round(sum(population$weight_stabilized, na.rm = TRUE), 0), "\n")

# Check for extreme weights in raw weights
n_extreme <- sum(population$weight_raw > (5 * mean(population$weight_raw, na.rm = TRUE)), na.rm = TRUE)
if (n_extreme > 0) {
  cat("\nNote:", n_extreme, "respondents have raw weights > 5x mean.\n")
  cat("Trimming addresses this by capping extreme values.\n")
}

# ------------------------------------------------------------------------------
# STEP 6: Calculate naive vs. debiased estimates (comparing weight approaches)
# ------------------------------------------------------------------------------

# NAIVE ESTIMATE: Simple average among respondents
# This is what you'd get if you just calculated: "What % of respondents said yes?"
naive_estimate <- population %>%
  filter(responded == 1) %>%
  summarise(estimate = mean(interest)) %>%
  pull(estimate)

# 1. NAIVE ESTIMATE (simple average)
cat("   ", percent(naive_estimate, accuracy = 0.1), "would use the betting feature\n")
cat("   This is BIASED because respondents differ from the full population\n")

# 2. DEBIASED ESTIMATES: Weighted averages using three types of weights

# 2.1. Raw weights (standard inverse propensity weighting)
# Formula: sum(Interest * Weight) / sum(Weight)
debiased_raw <- population %>%
  filter(responded == 1) %>%
  summarise(
    numerator = sum(interest * weight_raw),
    denominator = sum(weight_raw),
    estimate = numerator / denominator
  ) %>%
  pull(estimate)

# 2.1 raw weights:
cat("   ", percent(debiased_raw, accuracy = 0.1), "would use the betting feature\n")
cat("   Bias vs naive: ", sprintf("%+.1f", (naive_estimate - debiased_raw) * 100), " pp\n")

# 2.2 Trimmed weights (capped at threshold)
debiased_trimmed <- population %>%
  filter(responded == 1) %>%
  summarise(
    numerator = sum(interest * weight_trimmed),
    denominator = sum(weight_trimmed),
    estimate = numerator / denominator
  ) %>%
  pull(estimate)

# 2.2. trimmed weights
cat("   ", percent(debiased_trimmed, accuracy = 0.1), "would use the betting feature\n")
cat("   Bias vs naive: ", sprintf("%+.1f", (naive_estimate - debiased_trimmed) * 100), " pp\n")
cat("   Difference from raw: ", sprintf("%+.1f", (debiased_trimmed - debiased_raw) * 100), " pp\n")

# 2.3 Stabilized weights, scaled by response rate
debiased_stabilized <- population %>%
  filter(responded == 1) %>%
  summarise(
    numerator = sum(interest * weight_stabilized),
    denominator = sum(weight_stabilized),
    estimate = numerator / denominator
  ) %>%
  pull(estimate)

# 2.3 stabilized weights:
cat("   ", percent(debiased_stabilized, accuracy = 0.1), "would use the betting feature\n")
cat("   Bias vs naive: ", sprintf("%+.1f", (naive_estimate - debiased_stabilized) * 100), " pp\n")
cat("   Difference from raw: ", sprintf("%+.1f", (debiased_stabilized - debiased_raw) * 100), " pp\n")

# Summary interpretation
cat("\n--- KEY INSIGHT ---\n")
if (abs(debiased_raw - debiased_trimmed) < 0.01 && abs(debiased_raw - debiased_stabilized) < 0.01) {
  cat("All three debiased estimates are very similar (< 1 pp difference).\n")
  cat("This suggests the estimate is ROBUST to weight adjustments.\n")
  cat("Extreme weights are not driving the results.\n")
} else {
  cat("Debiased estimates differ by ", 
      sprintf("%.1f", max(abs(debiased_raw - debiased_trimmed), 
                          abs(debiased_raw - debiased_stabilized)) * 100), 
      " pp or more.\n")
  cat("This suggests the estimate is SENSITIVE to extreme weights.\n")
  cat("Trimmed or stabilized weights may be preferable for stability.\n")
}

# Create comparison table summarizing all methods
comparison_table <- tibble(
  Method = c("Naive (unweighted)", "Debiased (raw weights)", 
             "Debiased (trimmed weights)", "Debiased (stabilized weights)"),
  Estimate = c(naive_estimate, debiased_raw, debiased_trimmed, debiased_stabilized),
  `Bias vs Naive (pp)` = c(0, 
                            (naive_estimate - debiased_raw) * 100,
                            (naive_estimate - debiased_trimmed) * 100,
                            (naive_estimate - debiased_stabilized) * 100),
  `Mean Weight` = c(1, 
                    mean(population$weight_raw, na.rm = TRUE),
                    mean(population$weight_trimmed, na.rm = TRUE),
                    mean(population$weight_stabilized, na.rm = TRUE)),
  `Max Weight` = c(1,
                   max(population$weight_raw, na.rm = TRUE),
                   max(population$weight_trimmed, na.rm = TRUE),
                   max(population$weight_stabilized, na.rm = TRUE)),
  `SD Weight` = c(0,
                  sd(population$weight_raw, na.rm = TRUE),
                  sd(population$weight_trimmed, na.rm = TRUE),
                  sd(population$weight_stabilized, na.rm = TRUE)),
  `Effective N` = c(n_respondents,
                    sum(population$weight_raw, na.rm = TRUE)^2 / 
                      sum(population$weight_raw^2, na.rm = TRUE),
                    sum(population$weight_trimmed, na.rm = TRUE)^2 / 
                      sum(population$weight_trimmed^2, na.rm = TRUE),
                    sum(population$weight_stabilized, na.rm = TRUE)^2 / 
                      sum(population$weight_stabilized^2, na.rm = TRUE))
)

# WEIGHT COMPARISON TABLE
print(comparison_table, width = Inf)

# --------------------------------------------------------------
# Next steps
# --------------------------------------------------------------

# 1. Conditional independence (selection on observables)
# Assumption: Once you control for observed characteristics (age, deposits, app opens, etc.), there are no other hidden factors that affect both who responds and their interest in betting.
# Action: insert more features. Do we have a feature store?
#
# 2. Positivity (common support / overlap)
# Assumption: Every user has some positive probability of responding, no matter their characteristics.
# Action: Weights > 0 and < 1 for all users. Check the distribution of weights.
#
# 3. Correct model specification
# Assumption: Your propensity model (logistic regression) includes the right variables and functional form.
# Action: Use machine learning (random forests, boosting) for propensity estimation - more flexible and robust.
#
# 4. No interference (SUTVA-like)
# Assumption: One user's response decision doesn't affect another user's response or interest.
#
# 5. No measurement error in covariates
# Assumption: Variables like deposits, age, app opens are measured accurately.