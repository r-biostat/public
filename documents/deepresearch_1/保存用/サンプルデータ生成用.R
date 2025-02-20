# 再現性のためのシード設定
set.seed(123)

# サンプルサイズ100例のサンプルデータ作成
sample_data <- data.frame(
  patient_id = 1:100,
  age = round(runif(100, 40, 90)),  # 40歳から90歳の間の年齢
  sex = sample(c("Male", "Female"), 100, replace = TRUE),
  performance_status = sample(0:4, 100, replace = TRUE),
  treatment = sample(0:1, 100, replace = TRUE),
  outcome_2yr = sample(0:1, 100, replace = TRUE)
)

# "sample_data.csv"ファイルとして出力
write.csv(sample_data, file = "sample_data.csv", row.names = FALSE)