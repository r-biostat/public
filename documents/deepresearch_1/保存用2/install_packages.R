# 必要なパッケージのインストール
packages <- c(
  "tidyverse",
  "survival",
  "survminer",
  "MatchIt",
  "tableone",
  "mice",
  "WeightIt",
  "knitr",
  "kableExtra",
  "broom"
)

# パッケージがインストールされていない場合のみインストール
for (package in packages) {
  if (!require(package, character.only = TRUE)) {
    install.packages(package)
  }
}

# パッケージのバージョン情報を表示
installed.packages()[packages, "Version"] 