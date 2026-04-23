# ==============================================================================
# Survey debiasing analysis: marketplace one-hour delivery (R)
# ==============================================================================
#
# Companion analysis script for the Substack post at
# posts/2026-04-survey-debiasing.md.
#
# Reads the simulated dataset produced by generate_survey_data.R, fits a
# propensity model, constructs raw / trimmed / stabilized inverse-propensity
# weights, and compares the naive estimate against the three debiased ones.
# Also saves a common-support figure to figures/common_support.png.
#
# Run generate_survey_data.R first if data/survey_population.csv does not yet
# exist. That script owns the seed and the data-generating process; this one
# is deterministic given the CSV.
#
# Dependencies: tidyverse, scales
# ==============================================================================

library(tidyverse)
library(scales)

# ------------------------------------------------------------------------------
# Load the shared dataset
# ------------------------------------------------------------------------------

if (!file.exists("data/survey_population.csv")) {
  stop("data/survey_population.csv not found. Run generate_survey_data.R first.")
}

population <- read_csv("data/survey_population.csv", show_col_types = FALSE)

n_invited     <- nrow(population)
n_respondents <- sum(population$responded)
response_rate <- n_respondents / n_invited

# ------------------------------------------------------------------------------
# STEP 1: Compare respondents vs. non-respondents vs. the invited population
# ------------------------------------------------------------------------------
#
# The 150,000 invited users are treated as representative of the population
# of interest. The 1,001 respondents self-selected in; the remaining 148,999
# are the non-respondents whose views we are trying to infer indirectly.

describe_group <- function(df, label) {
  cat("\n--- ", label, " (n = ", nrow(df), ") ---\n", sep = "")
  cat("- Average age:        ", round(mean(df$age), 1), " years\n", sep = "")
  cat("- Female proportion:  ", percent(mean(df$female), accuracy = 0.1), "\n", sep = "")
  cat("- Has revenue:        ", percent(mean(df$has_made_purchase), accuracy = 0.1), "\n", sep = "")
  cat("- Mean annual spend:  ", dollar(mean(df$annual_spend)), "\n", sep = "")
  cat("- Mean annual refunds:", dollar(mean(df$annual_refunds)), "\n", sep = "")
  cat("- Monthly app opens:  ", round(mean(df$monthly_app_opens), 0), "\n", sep = "")
}

describe_group(population,                              "Invited population")
describe_group(filter(population, responded == 1),      "Respondents")
describe_group(filter(population, responded == 0),      "Non-respondents")

# ------------------------------------------------------------------------------
# STEP 2: Fit the propensity score model
# ------------------------------------------------------------------------------

propensity_model <- glm(
  responded ~ age + female + has_made_purchase + annual_spend +
    annual_refunds + monthly_app_opens,
  data   = population,
  family = binomial(link = "logit")
)

cat("\n--- Propensity model coefficients ---\n")
print(summary(propensity_model))

population <- population %>%
  mutate(propensity_score = predict(propensity_model, type = "response"))

cat("\n--- Propensity score distribution ---\n")
cat("Respondents:\n")
cat("  - Mean:  ", round(mean(population$propensity_score[population$responded == 1]), 4), "\n")
cat("  - Range: ", round(min(population$propensity_score[population$responded == 1]), 4),
    " to ", round(max(population$propensity_score[population$responded == 1]), 4), "\n")
cat("Non-respondents:\n")
cat("  - Mean:  ", round(mean(population$propensity_score[population$responded == 0]), 4), "\n")
cat("  - Range: ", round(min(population$propensity_score[population$responded == 0]), 4),
    " to ", round(max(population$propensity_score[population$responded == 0]), 4), "\n")

# ------------------------------------------------------------------------------
# STEP 3: Build three weight variants (raw, trimmed, stabilized)
# ------------------------------------------------------------------------------

population <- population %>%
  mutate(
    weight_raw = if_else(responded == 1, 1 / propensity_score, NA_real_)
  )

trim_threshold <- min(
  quantile(population$weight_raw, 0.95, na.rm = TRUE),
  5 * mean(population$weight_raw, na.rm = TRUE)
)

population <- population %>%
  mutate(
    weight_trimmed = if_else(
      responded == 1,
      pmin(weight_raw, trim_threshold),
      NA_real_
    ),
    weight_stabilized = if_else(
      responded == 1,
      response_rate / propensity_score,
      NA_real_
    )
  )

cat("\nTrimming threshold:", round(trim_threshold, 1),
    "(lower of 95th percentile or 5x mean)\n")

summarize_weights <- function(w, label, digits = 1) {
  cat("\n--- ", label, " ---\n", sep = "")
  cat("- Mean:   ", format(round(mean(w, na.rm = TRUE), digits), nsmall = digits), "\n", sep = "")
  cat("- Median: ", format(round(median(w, na.rm = TRUE), digits), nsmall = digits), "\n", sep = "")
  cat("- Range:  ", format(round(min(w, na.rm = TRUE), digits), nsmall = digits),
      " to ", format(round(max(w, na.rm = TRUE), digits), nsmall = digits), "\n", sep = "")
  cat("- SD:     ", format(round(sd(w, na.rm = TRUE), digits), nsmall = digits), "\n", sep = "")
}

summarize_weights(population$weight_raw,        "Raw weights")
summarize_weights(population$weight_trimmed,    "Trimmed weights")
cat("- # weights trimmed:", sum(population$weight_raw > trim_threshold, na.rm = TRUE), "\n")
summarize_weights(population$weight_stabilized, "Stabilized weights", digits = 3)

# ------------------------------------------------------------------------------
# STEP 4: Naive vs. debiased estimates
# ------------------------------------------------------------------------------

naive_estimate <- population %>%
  filter(responded == 1) %>%
  summarise(estimate = mean(interest)) %>%
  pull(estimate)

weighted_estimate <- function(df, weight_col) {
  df %>%
    filter(responded == 1) %>%
    summarise(
      estimate = sum(interest * .data[[weight_col]]) / sum(.data[[weight_col]])
    ) %>%
    pull(estimate)
}

debiased_raw        <- weighted_estimate(population, "weight_raw")
debiased_trimmed    <- weighted_estimate(population, "weight_trimmed")
debiased_stabilized <- weighted_estimate(population, "weight_stabilized")

cat("\n--- Estimates ---\n")
cat("Naive (unweighted):            ", percent(naive_estimate, accuracy = 0.1), "\n")
cat("Debiased (raw weights):        ", percent(debiased_raw, accuracy = 0.1),
    "  [naive - debiased = ", sprintf("%+.1f", (naive_estimate - debiased_raw) * 100), " pp]\n", sep = "")
cat("Debiased (trimmed weights):    ", percent(debiased_trimmed, accuracy = 0.1),
    "  [naive - debiased = ", sprintf("%+.1f", (naive_estimate - debiased_trimmed) * 100), " pp]\n", sep = "")
cat("Debiased (stabilized weights): ", percent(debiased_stabilized, accuracy = 0.1),
    "  [naive - debiased = ", sprintf("%+.1f", (naive_estimate - debiased_stabilized) * 100), " pp]\n", sep = "")

effective_n <- function(w) {
  w <- w[!is.na(w)]
  sum(w)^2 / sum(w^2)
}

comparison_table <- tibble(
  Method = c("Naive (unweighted)", "Debiased (raw)",
             "Debiased (trimmed)", "Debiased (stabilized)"),
  Estimate = c(naive_estimate, debiased_raw, debiased_trimmed, debiased_stabilized),
  `Bias vs Naive (pp)` = c(
    0,
    (naive_estimate - debiased_raw)        * 100,
    (naive_estimate - debiased_trimmed)    * 100,
    (naive_estimate - debiased_stabilized) * 100
  ),
  `Effective N` = c(
    n_respondents,
    effective_n(population$weight_raw),
    effective_n(population$weight_trimmed),
    effective_n(population$weight_stabilized)
  )
)

cat("\n--- Weight comparison table ---\n")
print(comparison_table, width = Inf)

# ------------------------------------------------------------------------------
# STEP 5: Common-support figure
# ------------------------------------------------------------------------------
#
# Overlaid densities of the estimated propensity scores for respondents and
# non-respondents. If the two densities overlap well over the range where
# respondents sit, the positivity / common-support assumption is plausible.
# If respondents sit in a region where non-respondents essentially never
# appear, IPW has to extrapolate and weights there will be extreme.

plot_df <- population %>%
  mutate(
    group = if_else(responded == 1, "Respondents", "Non-respondents"),
    group = factor(group, levels = c("Non-respondents", "Respondents"))
  )

common_support_plot <- ggplot(plot_df, aes(x = propensity_score, fill = group, colour = group)) +
  geom_density(alpha = 0.35, linewidth = 0.6) +
  scale_x_log10(
    labels = label_percent(accuracy = 0.01),
    breaks = c(1e-5, 1e-4, 1e-3, 1e-2, 1e-1, 1)
  ) +
  scale_fill_manual(values  = c("Non-respondents" = "#3B82F6", "Respondents" = "#EF4444")) +
  scale_colour_manual(values = c("Non-respondents" = "#1E40AF", "Respondents" = "#B91C1C")) +
  labs(
    title    = "Common support: where respondents and non-respondents overlap",
    subtitle = "Density of estimated response probability, log scale",
    x        = "Estimated probability of responding (log scale)",
    y        = "Density",
    fill     = NULL,
    colour   = NULL,
    caption  = "IPW can reweight wherever the two distributions overlap. Respondents in the far right tail\ncarry large weights because very few non-respondents look like them."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "top",
    plot.title      = element_text(face = "bold"),
    plot.caption    = element_text(hjust = 0, colour = "grey30")
  )

dir.create("figures", showWarnings = FALSE)
ggsave(
  filename = "figures/common_support.png",
  plot     = common_support_plot,
  width    = 8,
  height   = 5,
  dpi      = 200
)

cat("\nSaved figures/common_support.png\n")

# ------------------------------------------------------------------------------
# Notes on assumptions
# ------------------------------------------------------------------------------
#
# 1. Conditional independence (MAR given observables): untestable; mitigated
#    by including every plausibly relevant covariate and running sensitivity
#    analyses (Rosenbaum bounds, E-values).
# 2. Positivity / common support: diagnosable from the figure above and from
#    the weight distribution.
# 3. Correct model specification: try gradient-boosted trees as a robustness
#    check; compare the resulting estimates.
# 4. No interference (SUTVA-like): usually holds for survey responses.
# 5. No measurement error in covariates: usually fine for logged behavioral
#    signals, weaker for self-reported fields.
