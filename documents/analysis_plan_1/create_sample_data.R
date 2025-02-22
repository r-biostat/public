# -------------------------------------------------------------
# サンプルデータ生成コード（修正後：介入効果の効果修飾＋一部介入群で上昇）
# -------------------------------------------------------------
set.seed(123)  # 乱数シードの固定

# ---- パラメータ設定 ----
N <- 300                # 被験者数（ID数：300人）
get_n_visits <- function(){
  min(rpois(1, lambda=4) + 1, 20)
}
p_interv <- 0.5  
race_dist <- c(0.5, 0.3, 0.2)
age_mean <- 50
age_sd   <- 10
weight_mean <- 70
weight_sd   <- 15
height_mean <- 170
height_sd   <- 10
HbA1c_baseline_mean <- 6.5
HbA1c_baseline_sd   <- 0.5
slope_control <- 0.1     
slope_interv  <- -0.05   
race_effect <- c(-0.03, 0.0, -0.015)
smoke_effect     <- 0.1
drink_effect     <- 0.05
exercise_effect  <- c(0.1, 0.05, 0, -0.05)  
# 新規：介入効果に対する regular_exercise の効果修飾
exercise_interv_effect <- c(0, -0.2, -0.4, -0.6)

# ---- 各変数を生成 ----
ID <- 1:N
interv <- rbinom(N, size=1, prob=p_interv)
race_category <- sample(x=c(1,2,3), size=N, replace=TRUE, prob=race_dist)
sex <- rbinom(N, size=1, prob=0.5) + 1  
age    <- round(rnorm(N, mean=age_mean, sd=age_sd))
weight <- round(rnorm(N, mean=weight_mean, sd=weight_sd), 1)
height <- round(rnorm(N, mean=height_mean, sd=height_sd), 1)
smoke <- rbinom(N, size=1, prob=0.3)
drink <- rbinom(N, size=1, prob=0.4)
regular_exercise <- sample(x=0:3, size=N, replace=TRUE, prob=c(0.3, 0.3, 0.3, 0.1))
HbA1c_base <- rnorm(N, mean=HbA1c_baseline_mean, sd=HbA1c_baseline_sd)

# ---- ロングフォーマット用リストの作成 ----
long_data_list <- list()

for(i in 1:N){
  
  base_i <- HbA1c_base[i]
  interv_i  <- interv[i]
  race_i    <- race_category[i]
  sex_i     <- sex[i]
  smoke_i   <- smoke[i]
  drink_i   <- drink[i]
  exercise_i<- regular_exercise[i]
  
  n_visits_i <- get_n_visits()
  
  baseline_date <- as.Date("2020-01-01") + sample(-30:30, 1)
  visit_gaps <- sample(30:120, n_visits_i - 1, replace=TRUE)
  visit_dates <- c(baseline_date, baseline_date + cumsum(visit_gaps))
  time_points <- as.numeric(visit_dates - baseline_date) / 30
  
  # 介入群の場合、一部（約20%）で経時的にHbA1cが上昇する設定を追加
  if(interv_i == 1){
    if(runif(1) < 0.2){  
      # 20% の確率で正の傾き（例：0.02～0.1の範囲内）を設定
      slope_i <- runif(1, min = 0.02, max = 0.1)
    } else {
      slope_i <- slope_interv + race_effect[race_i] + exercise_interv_effect[exercise_i + 1]
    }
  } else {
    slope_i <- slope_control
  }
  
  # 補正項（喫煙、飲酒、運動の効果）
  offset_i <- 0
  if(smoke_i == 1) { offset_i <- offset_i + smoke_effect }
  if(drink_i == 1) { offset_i <- offset_i + drink_effect }
  offset_i <- offset_i + exercise_effect[exercise_i + 1]
  
  # HbA1cの経時的な変化の設定
  HbA1c_i <- base_i + slope_i * time_points + offset_i + rnorm(n_visits_i, 0, 0.1)
  
  tmp_df <- data.frame(
    ID               = rep(i, n_visits_i),
    visit_date       = visit_dates,
    age              = rep(age[i], n_visits_i),
    sex              = rep(sex_i, n_visits_i),
    race             = rep(race_i, n_visits_i),
    weight           = rep(weight[i], n_visits_i),
    height           = rep(height[i], n_visits_i),
    smoke            = rep(smoke_i, n_visits_i),
    drink            = rep(drink_i, n_visits_i),
    regular_exercise = rep(exercise_i, n_visits_i),
    interv           = rep(interv_i, n_visits_i),
    HbA1c            = HbA1c_i
  )
  
  long_data_list[[i]] <- tmp_df
}

df_long <- do.call(rbind, long_data_list)
df_long <- df_long[order(df_long$ID, df_long$visit_date), ]

# -------------------------------------------------------------
# 修正部分：欠測と異常値の文字列置換の追加
# -------------------------------------------------------------

# 【修正1】各被験者のベースライン（最初のレコード）はそのまま、
#           以降のレコードのうち約10%を欠測（NA）にする
unique_IDs <- unique(df_long$ID)
for(i in unique_IDs){
  idx <- which(df_long$ID == i)
  if(length(idx) > 1){
    non_baseline_idx <- idx[-1]  # 1番目（ベースライン）以外
    n_missing <- ceiling(length(non_baseline_idx) * 0.1)
    missing_indices <- sample(non_baseline_idx, n_missing)
    df_long$HbA1c[missing_indices] <- NA
  }
}

# 【修正2】欠測でないHbA1c値の中から約3%を異常値として置換する
# 異常値のパターンを複数用意する（例："6～7", "7～8", "5～6", "異常", "測定不能"）
non_na_idx <- which(!is.na(df_long$HbA1c))
n_replace <- ceiling(length(non_na_idx) * 0.03)
replace_idx <- sample(non_na_idx, n_replace)
abnormal_patterns <- c("6～7", "7～8", "5～6", "異常", "測定不能")
df_long$HbA1c[replace_idx] <- sample(abnormal_patterns, size=length(replace_idx), replace = TRUE)

# -------------------------------------------------------------
# 追加部分：クレアチニン (CRE) 値の追加
# -------------------------------------------------------------
df_long$CRE <- rlnorm(nrow(df_long), meanlog = -0.722, sdlog = 0.65)

# 結果の確認
nrow(df_long)
head(df_long)

# 必要に応じてファイル保存
write.csv(df_long, file = "practice_data_modified.csv")

# ---------------------------
# 最終的なデータ型の変換
# ---------------------------
# visit_dateを文字列型に変換
df_long$visit_date <- as.character(df_long$visit_date)

# regular_exerciseを実数型に変換
df_long$regular_exercise <- as.numeric(df_long$regular_exercise)

# ---------------------------
# データ定義書の作成（日本語）
# ---------------------------
data_dict <- data.frame(
  列名 = c("ID", "visit_date", "age", "sex", "race", 
           "weight", "height", "smoke", "drink", 
           "regular_exercise", "interv", "HbA1c", "CRE"),
  データ型 = c("整数", "文字列", "整数", "整数（1: 男性, 2: 女性）",
             "整数（1: 白人, 2: 黒人, 3: その他）", "数値", "数値",
             "整数（0: 非喫煙, 1: 喫煙）", "整数（0: 飲酒なし, 1: 飲酒あり）",
             "数値", "整数（0: 対照群, 1: 介入群）",
             "数値/文字列", "数値"),
  説明 = c(
    "被験者識別子",
    "受診日（YYYY-MM-DD）",
    "受診時の年齢（歳）",
    "性別（1: 男性, 2: 女性）",
    "人種（1: 白人, 2: 黒人, 3: その他）",
    "体重（kg）",
    "身長（cm）",
    "喫煙状況（0: 非喫煙, 1: 喫煙）",
    "飲酒状況（0: 飲酒なし, 1: 飲酒あり）",
    "定期的な運動頻度（0～3）",
    "介入群識別（0: 対照群, 1: 介入群）",
    "HbA1c 値。大部分は数値だが、約3%は異常値パターンに置換済み",
    "クレアチニン値（mg/dL）"
  ),
  stringsAsFactors = FALSE
)

# ---------------------------
# Markdownファイルとして出力
# ---------------------------
md_lines <- c(
  "| 列名 | データ型 | 説明 |",
  "| --- | --- | --- |"
)
for(i in 1:nrow(data_dict)){
  line <- sprintf("| %s | %s | %s |",
                  data_dict$列名[i],
                  data_dict$データ型[i],
                  data_dict$説明[i])
  md_lines <- c(md_lines, line)
}
writeLines(md_lines, con = "data_dictionary.md")
cat("Markdownファイル 'data_dictionary.md' を出力しました。\n")

# ---------------------------
# CSVファイルとして出力（SJISエンコーディング）
# ---------------------------
write.csv(data_dict, file = "data_dictionary.csv", row.names = FALSE, fileEncoding = "SJIS")
cat("CSVファイル 'data_dictionary.csv' をSJISエンコーディングで出力しました。\n")
