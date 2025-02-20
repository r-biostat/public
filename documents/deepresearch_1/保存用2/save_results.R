# 必要なパッケージの読み込み
library(tidyverse)
library(survival)
library(survminer)
library(MatchIt)
library(tableone)

# データの読み込みと前処理
data <- read.csv("sample_data.csv") %>%
  mutate(
    Sex = factor(Sex),
    PerformanceStatus = factor(PerformanceStatus),
    ICI_Therapy = factor(ICI_Therapy, labels = c("非併用", "併用")),
    Event = factor(Event, labels = c("生存", "死亡"))
  )

# 1. ベースライン特性の解析
vars <- c("Age", "Sex", "PerformanceStatus", "LymphNodeCount", 
          "TumorSize", "FollowUpMonths", "Event")
baseline_table <- CreateTableOne(vars = vars, strata = "ICI_Therapy", data = data, test = TRUE)
baseline_results <- print(baseline_table, smd = TRUE)

# 2. 傾向スコアマッチング
ps_model <- matchit(
  ICI_Therapy ~ Age + Sex + PerformanceStatus + LymphNodeCount + TumorSize,
  data = data,
  method = "nearest",
  ratio = 1
)
matched_data <- match.data(ps_model)
matched_table <- CreateTableOne(vars = vars, strata = "ICI_Therapy", data = matched_data, test = TRUE)
matched_results <- print(matched_table, smd = TRUE)

# 3. 生存分析
## 全体のKaplan-Meier解析
surv_obj <- Surv(data$FollowUpMonths, data$Event == "死亡")
km_fit <- survfit(surv_obj ~ ICI_Therapy, data = data)
km_test <- survdiff(surv_obj ~ ICI_Therapy, data = data)
km_pvalue <- 1 - pchisq(km_test$chisq, df = 1)

## Cox比例ハザード解析
cox_model <- coxph(
  Surv(FollowUpMonths, Event == "死亡") ~ ICI_Therapy + Age + Sex + 
    PerformanceStatus + LymphNodeCount + TumorSize,
  data = data
)
cox_results <- summary(cox_model)

## マッチング後のCox解析
matched_cox <- coxph(
  Surv(FollowUpMonths, Event == "死亡") ~ ICI_Therapy,
  data = matched_data
)
matched_cox_results <- summary(matched_cox)

# 4. 2年死亡率の解析
data_2year <- data %>% filter(FollowUpMonths <= 24)
mortality_2year <- data_2year %>%
  group_by(ICI_Therapy) %>%
  summarise(
    n_total = n(),
    n_death = sum(Event == "死亡"),
    mortality_rate = mean(Event == "死亡")
  )

logistic_model <- glm(
  Event == "死亡" ~ ICI_Therapy + Age + Sex + PerformanceStatus + 
    LymphNodeCount + TumorSize,
  family = binomial(),
  data = data_2year
)
logistic_results <- summary(logistic_model)

# 結果の保存
results <- list(
  baseline = list(
    table = baseline_results,
    n_total = nrow(data),
    n_by_group = table(data$ICI_Therapy)
  ),
  matching = list(
    table = matched_results,
    n_matched = nrow(matched_data),
    n_by_group = table(matched_data$ICI_Therapy)
  ),
  survival = list(
    km_test = list(
      chisq = km_test$chisq,
      pvalue = km_pvalue
    ),
    cox = list(
      full = cox_results,
      matched = matched_cox_results
    ),
    median_survival = summary(km_fit)$table
  ),
  mortality_2year = list(
    rates = mortality_2year,
    logistic = logistic_results
  )
)

# 結果をRDSファイルとして保存
saveRDS(results, "analysis_results.rds") 