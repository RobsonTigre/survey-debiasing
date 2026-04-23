# survey-debiasing

Companion code for a Substack post on correcting selection bias in user surveys with inverse probability weighting (IPW).

The simulation generates a 150,000-user invited population, induces realistic response selection bias so that only 1,001 people respond and they differ systematically from the invited pool (older, more engaged, higher spend), then walks through fitting a propensity model, constructing raw, trimmed, and stabilized weights, and comparing the naive unweighted estimate against the three debiased estimates. In the default run the naive estimate overstates interest in the feature by roughly 14 percentage points, and the debiased estimates recover a population-representative value.

## Scripts

Data generation and analysis are split so that R and Python produce **identical numbers** end-to-end — the seed lives only in the R generator, and both analysis scripts read the same CSV.

- `generate_survey_data.R` — owns the seed (`set.seed(42)`) and the data-generating process; writes `data/survey_population.csv`. Run this once.
- `survey_debiasing_marketplace.R` — reads the CSV, fits the propensity model, builds weights, reports naive vs. debiased estimates, and saves the common-support figure to `figures/common_support.png`.
- `survey_debiasing_marketplace.py` — Python port of the analysis script (no RNG; deterministic given the CSV).
- `survey_debiasing_simulation.R` — the original monolithic version of the methodology applied to a betting-feature scenario; kept alongside the marketplace variant to show that the same workflow carries across contexts.

Each analysis script follows the same five steps: load the CSV, describe respondents vs. non-respondents vs. the invited population, fit a propensity model, build raw / trimmed / stabilized inverse-probability weights, and compare the naive estimate against the three debiased ones.

## Running

```bash
# 1. Generate the shared dataset (R, seeded)
Rscript generate_survey_data.R

# 2. Run either (or both) analysis script
Rscript survey_debiasing_marketplace.R
python3 survey_debiasing_marketplace.py
```

Both analysis scripts write to `figures/common_support.png`, overwriting each other — the two plots are the same story rendered by ggplot vs. matplotlib.

The R scripts depend on `tidyverse` and `scales`. The Python script depends on `numpy`, `pandas`, `scipy`, `statsmodels`, and `matplotlib` (`pip install numpy pandas scipy statsmodels matplotlib`).
