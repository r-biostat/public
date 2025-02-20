# サンプルデータ作成のためのRコード

# 1. 再現性のために乱数シードを設定
set.seed(123)

# 2. サンプルサイズを指定（ここでは100例）
n <- 100

# 3. 各変数の作成
# 患者ID: "P001", "P002", …, "P100"
PatientID <- sprintf("P%03d", 1:n)

# 年齢: 40〜85歳の整数値
Age <- sample(40:85, n, replace = TRUE)

# 性別: "Male"または"Female"をランダムに割り当て
Sex <- sample(c("Male", "Female"), n, replace = TRUE)

# PerformanceStatus: 0〜4の整数値（例: ECOG PSスコア）
PerformanceStatus <- sample(0:4, n, replace = TRUE)

# リンパ節転移数: 0〜10の整数値
LymphNodeCount <- sample(0:10, n, replace = TRUE)

# 腫瘍の大きさ: 20〜100 mmの実数値（小数第1位まで）
TumorSize <- round(runif(n, min = 20, max = 100), 1)

# 免疫チェックポイント阻害薬併用: 0（非併用）または1（併用）をランダムに割り当て
ICI_Therapy <- sample(c(0, 1), n, replace = TRUE)

# 追跡期間: 1〜60ヶ月の実数値（小数第1位まで）
FollowUpMonths <- round(runif(n, min = 1, max = 60), 1)

# イベント指標: 0（打ち切り/生存）または1（死亡）をランダムに割り当て
Event <- sample(c(0, 1), n, replace = TRUE)

# 4. すべての変数をデータフレームにまとめる
sample_data <- data.frame(
  PatientID,
  Age,
  Sex,
  PerformanceStatus,
  LymphNodeCount,
  TumorSize,
  ICI_Therapy,
  FollowUpMonths,
  Event,
  stringsAsFactors = FALSE
)

# 5. "sample_data.csv"ファイルとして出力する（ヘッダーあり、行番号は出力しない）
write.csv(sample_data, file = "sample_data.csv", row.names = FALSE)
