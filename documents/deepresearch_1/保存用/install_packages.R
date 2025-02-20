# 必要なパッケージのインストール
if (!require("pacman")) install.packages("pacman")
pacman::p_load(
  tidyverse,    # データ操作・可視化
  tableone,     # 記述統計
  MatchIt,      # 傾向スコアマッチング
  survey,       # IPTW解析
  twang,        # IPTW解析
  knitr,        # レポート作成
  kableExtra,   # テーブル整形
  ggplot2,      # 可視化
  rmarkdown,    # Rmarkdown
  quarto        # Quarto
) 