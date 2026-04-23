# ==============================================================================
# Survey debiasing analysis: marketplace one-hour delivery (Python)
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
# Because the dataset is loaded from disk rather than regenerated, the numbers
# here match the R analysis script exactly. There is no RNG in this script.
#
# Run generate_survey_data.R first if data/survey_population.csv does not yet
# exist.
#
# Dependencies: numpy, pandas, statsmodels, matplotlib
#     pip install numpy pandas statsmodels matplotlib
# ==============================================================================

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import statsmodels.api as sm


# ------------------------------------------------------------------------------
# Formatters
# ------------------------------------------------------------------------------

def pct(x, digits=1):
    return f"{x * 100:.{digits}f}%"


def dollar(x):
    return f"${x:,.2f}"


# ------------------------------------------------------------------------------
# Load the shared dataset
# ------------------------------------------------------------------------------

data_path = Path("data/survey_population.csv")
if not data_path.exists():
    raise FileNotFoundError(
        "data/survey_population.csv not found. Run generate_survey_data.R first."
    )

population = pd.read_csv(data_path)

n_invited = len(population)
n_respondents = int(population["responded"].sum())
response_rate = n_respondents / n_invited


# ------------------------------------------------------------------------------
# STEP 1: Respondents vs. non-respondents vs. invited population
# ------------------------------------------------------------------------------
#
# The 150,000 invited users are treated as representative of the population
# of interest. The 1,001 respondents self-selected in; the remaining 148,999
# are the non-respondents whose views we are trying to infer indirectly.


def describe_group(df, label):
    print(f"\n--- {label} (n = {len(df)}) ---")
    print(f"- Average age:         {df['age'].mean():.1f} years")
    print(f"- Female proportion:   {pct(df['female'].mean())}")
    print(f"- Has revenue:         {pct(df['has_made_purchase'].mean())}")
    print(f"- Mean annual spend:   {dollar(df['annual_spend'].mean())}")
    print(f"- Mean annual refunds: {dollar(df['annual_refunds'].mean())}")
    print(f"- Monthly app opens:   {round(df['monthly_app_opens'].mean())}")


describe_group(population,                              "Invited population")
describe_group(population[population["responded"] == 1], "Respondents")
describe_group(population[population["responded"] == 0], "Non-respondents")


# ------------------------------------------------------------------------------
# STEP 2: Fit the propensity score model
# ------------------------------------------------------------------------------

features = [
    "age",
    "female",
    "has_made_purchase",
    "annual_spend",
    "annual_refunds",
    "monthly_app_opens",
]
X = sm.add_constant(population[features])
y = population["responded"]

propensity_model = sm.GLM(y, X, family=sm.families.Binomial()).fit()
print("\n--- Propensity model coefficients ---")
print(propensity_model.summary())

population["propensity_score"] = propensity_model.predict(X)

resp_mask = population["responded"] == 1
print("\n--- Propensity score distribution ---")
print("Respondents:")
print(f"  - Mean:  {population.loc[resp_mask, 'propensity_score'].mean():.4f}")
print(
    f"  - Range: {population.loc[resp_mask, 'propensity_score'].min():.4f} "
    f"to {population.loc[resp_mask, 'propensity_score'].max():.4f}"
)
print("Non-respondents:")
print(f"  - Mean:  {population.loc[~resp_mask, 'propensity_score'].mean():.4f}")
print(
    f"  - Range: {population.loc[~resp_mask, 'propensity_score'].min():.4f} "
    f"to {population.loc[~resp_mask, 'propensity_score'].max():.4f}"
)


# ------------------------------------------------------------------------------
# STEP 3: Build three weight variants (raw, trimmed, stabilized)
# ------------------------------------------------------------------------------

population["weight_raw"] = np.where(
    population["responded"] == 1,
    1.0 / population["propensity_score"],
    np.nan,
)

raw_weights = population["weight_raw"].dropna()
trim_threshold = min(
    np.quantile(raw_weights, 0.95),
    5 * raw_weights.mean(),
)
print(
    f"\nTrimming threshold: {trim_threshold:.1f} "
    "(lower of 95th percentile or 5x mean)"
)

population["weight_trimmed"] = np.where(
    population["responded"] == 1,
    np.minimum(population["weight_raw"], trim_threshold),
    np.nan,
)

population["weight_stabilized"] = np.where(
    population["responded"] == 1,
    response_rate / population["propensity_score"],
    np.nan,
)


def summarize_weights(w, label, digits=1):
    w = w.dropna()
    print(f"\n--- {label} ---")
    print(f"- Mean:   {w.mean():.{digits}f}")
    print(f"- Median: {w.median():.{digits}f}")
    print(f"- Range:  {w.min():.{digits}f} to {w.max():.{digits}f}")
    print(f"- SD:     {w.std(ddof=1):.{digits}f}")


summarize_weights(population["weight_raw"],        "Raw weights")
summarize_weights(population["weight_trimmed"],    "Trimmed weights")
n_trimmed = int((population["weight_raw"] > trim_threshold).sum())
print(f"- # weights trimmed: {n_trimmed}")
summarize_weights(population["weight_stabilized"], "Stabilized weights", digits=3)


# ------------------------------------------------------------------------------
# STEP 4: Naive vs. debiased estimates
# ------------------------------------------------------------------------------

resp = population[population["responded"] == 1]


def weighted_mean(values, weights):
    return float(np.sum(values * weights) / np.sum(weights))


naive_estimate      = float(resp["interest"].mean())
debiased_raw        = weighted_mean(resp["interest"], resp["weight_raw"])
debiased_trimmed    = weighted_mean(resp["interest"], resp["weight_trimmed"])
debiased_stabilized = weighted_mean(resp["interest"], resp["weight_stabilized"])

print("\n--- Estimates ---")
print(f"Naive (unweighted):            {pct(naive_estimate)}")
print(
    f"Debiased (raw weights):        {pct(debiased_raw)}  "
    f"[naive - debiased = {(naive_estimate - debiased_raw) * 100:+.1f} pp]"
)
print(
    f"Debiased (trimmed weights):    {pct(debiased_trimmed)}  "
    f"[naive - debiased = {(naive_estimate - debiased_trimmed) * 100:+.1f} pp]"
)
print(
    f"Debiased (stabilized weights): {pct(debiased_stabilized)}  "
    f"[naive - debiased = {(naive_estimate - debiased_stabilized) * 100:+.1f} pp]"
)


def effective_n(w):
    w = w.dropna()
    return float(w.sum() ** 2 / (w ** 2).sum())


comparison_table = pd.DataFrame(
    {
        "Method": [
            "Naive (unweighted)",
            "Debiased (raw)",
            "Debiased (trimmed)",
            "Debiased (stabilized)",
        ],
        "Estimate": [naive_estimate, debiased_raw, debiased_trimmed, debiased_stabilized],
        "Bias vs Naive (pp)": [
            0.0,
            (naive_estimate - debiased_raw) * 100,
            (naive_estimate - debiased_trimmed) * 100,
            (naive_estimate - debiased_stabilized) * 100,
        ],
        "Effective N": [
            float(n_respondents),
            effective_n(population["weight_raw"]),
            effective_n(population["weight_trimmed"]),
            effective_n(population["weight_stabilized"]),
        ],
    }
)

print("\n--- Weight comparison table ---")
with pd.option_context(
    "display.width", 200, "display.max_columns", None, "display.float_format", "{:.4f}".format
):
    print(comparison_table.to_string(index=False))


# ------------------------------------------------------------------------------
# STEP 5: Common-support figure
# ------------------------------------------------------------------------------
#
# Overlaid densities of the estimated propensity scores for respondents and
# non-respondents (log x-axis). If the two densities overlap well over the
# range where respondents sit, positivity / common support is plausible. If
# respondents sit in a region where non-respondents essentially never appear,
# IPW has to extrapolate and weights there will be extreme.

resp_scores    = population.loc[resp_mask,  "propensity_score"].to_numpy()
nonresp_scores = population.loc[~resp_mask, "propensity_score"].to_numpy()

log_min = np.log10(max(min(resp_scores.min(), nonresp_scores.min()), 1e-6))
log_max = np.log10(max(resp_scores.max(), nonresp_scores.max()))
grid = np.logspace(log_min, log_max, 400)


def log_density(values, grid):
    # KDE in log space so the density is meaningful when we plot on a log x-axis.
    log_vals = np.log10(np.clip(values, 10 ** log_min, None))
    from scipy.stats import gaussian_kde
    kde = gaussian_kde(log_vals)
    return kde(np.log10(grid))


resp_density    = log_density(resp_scores,    grid)
nonresp_density = log_density(nonresp_scores, grid)

fig, ax = plt.subplots(figsize=(8, 5.2))
ax.fill_between(grid, nonresp_density, alpha=0.35, color="#3B82F6", label="Non-respondents")
ax.plot(grid,         nonresp_density, color="#1E40AF", linewidth=1.0)
ax.fill_between(grid, resp_density,    alpha=0.35, color="#EF4444", label="Respondents")
ax.plot(grid,         resp_density,    color="#B91C1C", linewidth=1.0)

ax.set_xscale("log")
ax.set_xlabel("Estimated probability of responding (log scale)")
ax.set_ylabel("Density")
fig.suptitle(
    "Common support: where respondents and non-respondents overlap",
    fontweight="bold", fontsize=13, y=0.98,
)
ax.set_title(
    "Density of estimated response probability, log scale",
    fontsize=10, color="gray", loc="left", pad=8,
)
ax.legend(loc="upper left", frameon=False)
fig.tight_layout(rect=[0, 0.08, 1, 0.95])
fig.text(
    0.02, 0.02,
    "IPW can reweight wherever the two distributions overlap. Respondents in the far right tail\n"
    "carry large weights because very few non-respondents look like them.",
    fontsize=9, color="gray",
)

Path("figures").mkdir(exist_ok=True)
fig.savefig("figures/common_support.png", dpi=200, bbox_inches="tight")
print("\nSaved figures/common_support.png")


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
