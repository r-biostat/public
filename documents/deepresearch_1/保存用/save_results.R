# Load required packages
if (!require("pacman")) install.packages("pacman")
pacman::p_load(
  tidyverse,    # Data manipulation and visualization
  tableone,     # Descriptive statistics
  MatchIt,      # Propensity score matching
  survey,       # IPTW analysis
  twang,        # IPTW analysis
  sandwich,     # Robust standard errors
  broom         # Tidy model outputs
)

# Load data
data <- read.csv("sample_data.csv")

# Data preprocessing
data <- data %>%
  mutate(
    sex = factor(sex),
    performance_status = factor(performance_status, ordered = TRUE),
    treatment = factor(treatment, labels = c("Conventional", "ICI")),
    outcome_2yr = factor(outcome_2yr, labels = c("Alive", "Dead"))
  )

# 1. Multivariable logistic regression
log_model <- glm(
  outcome_2yr ~ treatment + age + sex + performance_status,
  family = binomial(),
  data = data
)

log_results <- tidy(log_model, conf.int = TRUE, exponentiate = TRUE)

# 2. Propensity score matching
ps_model <- matchit(
  treatment ~ age + sex + performance_status,
  data = data,
  method = "nearest",
  ratio = 1
)

matched_data <- match.data(ps_model)
matched_model <- glm(
  outcome_2yr ~ treatment,
  family = binomial(),
  data = matched_data
)

psm_results <- tidy(matched_model, conf.int = TRUE, exponentiate = TRUE)

# 3. IPTW analysis
ps_fit <- glm(
  treatment ~ age + sex + performance_status,
  family = binomial(),
  data = data
)

data$ps <- predict(ps_fit, type = "response")
data$weight <- ifelse(
  data$treatment == "ICI",
  1/data$ps,
  1/(1-data$ps)
)

data$weight_stabilized <- data$weight * mean(data$treatment == "ICI")
data$weight_trimmed <- pmin(data$weight_stabilized, quantile(data$weight_stabilized, 0.99))

design_iptw <- svydesign(
  ids = ~1,
  weights = ~weight_trimmed,
  data = data
)

iptw_model <- svyglm(
  outcome_2yr ~ treatment,
  family = binomial(),
  design = design_iptw
)

iptw_results <- tidy(iptw_model, conf.int = TRUE, exponentiate = TRUE)

# Save results
results <- list(
  baseline_characteristics = print(CreateTableOne(
    vars = c("age", "sex", "performance_status", "outcome_2yr"),
    strata = "treatment",
    data = data,
    test = TRUE,
    smd = TRUE
  ), printToggle = FALSE),
  logistic = log_results,
  psm = psm_results,
  iptw = iptw_results,
  balance_stats = summary(ps_model)$reduction
)

saveRDS(results, "analysis_results.rds") 