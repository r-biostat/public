import json
import os
import re
import logging
import sys 
from pathlib import Path

# ── 引数チェック ──────────────────────────
if len(sys.argv) < 2:
    print("使い方: python 完成スクリプト.py <入力JSONのフルパス>")
    sys.exit(1)

input_json_file = Path(sys.argv[1])   

print("読み込みファイル →", input_json_file)

############################################
# ★★ここにObsidianの保管先となるディレクトリを指定★★
output_dir = './obsidian/paperpile_import'
############################################

# --- ロギング設定 ---
log_file = 'script_log.txt'

# ロガーを取得 (ルートロガーを使用)
logger = logging.getLogger('')
logger.setLevel(logging.INFO) # INFOレベル以上のメッセージを記録

# 既存のハンドラーをクリア (スクリプトを複数回実行する場合などに重複を避けるため)
if logger.hasHandlers():
    logger.handlers.clear()

# フォーマッターの作成
# 例: 2023-10-27 10:30:00,123 - INFO - メッセージ
formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')

# コンソール出力用ハンドラーの作成
console_handler = logging.StreamHandler(sys.stdout)
console_handler.setLevel(logging.INFO) # コンソールにはINFOレベル以上を出力
console_handler.setFormatter(formatter)
logger.addHandler(console_handler)

# ファイル出力用ハンドラーの作成
# encoding='utf-8' を指定して日本語も正しく記録できるようにする
file_handler = logging.FileHandler(log_file, encoding='utf-8')
file_handler.setLevel(logging.INFO) # ファイルにはINFOレベル以上を出力
file_handler.setFormatter(formatter)
logger.addHandler(file_handler)

logging.info(f"ログファイル '{log_file}' を開始しました。")

# --- 関数定義 ---
def sanitize_filename(title):
    """ファイル名として安全な文字列に変換します。"""
    # 問題のある文字を削除または置換
    sanitized = re.sub(r'[\/:*?"<>|]', '', title)
    # 先頭や末尾のスペースやドットを削除
    sanitized = sanitized.strip(' .')
    # スペースをアンダースコアに置換（オプション）
    # sanitized = sanitized.replace(' ', '_')
    # ファイル名の長さを制限（オプション、必要に応じて調整）
    max_length = 150
    if len(sanitized) > max_length:
        sanitized = sanitized[:max_length] + '...'
    return sanitized

def format_date(published_data):
    """公開日の辞書を YYYY-MM-DD 形式の文字列に整形します。"""
    if not published_data:
        return "N/A-N/A-N/A"
    year = published_data.get('year', 'N/A')
    # 月と日を2桁にゼロ埋め
    month = str(published_data.get('month', 'N/A')).zfill(2)
    day = str(published_data.get('day', 'N/A')).zfill(2)
    return f"{year}-{month}-{day}"

def get_gdrive_ids(attachments):
    """attachmentsの中からgdrive_idが存在するもののIDをすべて見つけてリストで返します。"""
    gdrive_ids = []
    if not attachments:
        return gdrive_ids # 添付ファイルがない場合は空のリストを返す

    for att in attachments:
        # 'gdrive_id' が存在し、Noneまたは空でないことを確認
        if att.get('gdrive_id'):
            gdrive_ids.append(att['gdrive_id'])

    return gdrive_ids # 見つかったgdrive_idのリストを返す

def format_authors(author_list):
    """著者のリストをカンマ区切りの文字列に整形します。"""
    if not author_list:
        return "N/A"
    author_names = []
    for author in author_list:
        if 'formatted' in author:
            author_names.append(author['formatted'])
        elif 'first' in author and 'last' in author:
            author_names.append(f"{author['first']} {author['last']}")
        elif 'collective' in author:
            author_names.append(author['collective']) # 集合著者に対応
    return ", ".join(author_names) if author_names else "N/A"

def format_list_with_hashtags(items): # この関数は現在は使われていません
    """文字列のリストをハッシュタグ付きの文字列に整形します。"""
    if not items:
        return "N/A"
    # 最初の項目に#を付け、それ以外はスペースを挟んで#を付けて結合
    return "#" + " #".join(items)

def format_urls(url_list):
    """URLのリストをカンマ区切りの文字列に整形します。"""
    if not url_list:
        return "N/A"
    return ", ".join(url_list)

# --- メインスクリプト ---


# 出力ディレクトリが存在しない場合は作成
if not os.path.exists(output_dir):
    os.makedirs(output_dir)
    logging.info(f"出力ディレクトリを作成しました: {output_dir}")

try:
    with open(input_json_file, 'r', encoding='utf-8') as f:
        references = json.load(f)
except FileNotFoundError:
    logging.error(f"エラー: 入力ファイル '{input_json_file}' が見つかりません。")
    sys.exit(1) # エラーコード1で終了
except json.JSONDecodeError:
    logging.error(f"エラー: '{input_json_file}' からJSONをデコードできませんでした。ファイル形式を確認してください。")
    sys.exit(1) # エラーコード1で終了

logging.info(f"{len(references)}件の文献を処理します...")


for reference in references:
    # 既存の ref_id の取得ロジック (ファイル名フォールバックやデフォルトタイトル用)
    # JSONサンプルには 'id' キーがないため、この値は 'N/A' になることが多い。
    ref_id_for_fallback = reference.get('id', 'N/A')

    # --- YAMLヘッダー用のデータ抽出と生成 ---
    yaml_header_parts = []
    yaml_header_str = ""  # デフォルトは空の文字列

    doc_id_for_citekey = reference.get('_id')

    if doc_id_for_citekey:
        # 1. citekey (必須)
        yaml_header_parts.append(f"citekey: {doc_id_for_citekey}")

        # 2. title (オプショナル)
        title_for_yaml = reference.get('title')
        if title_for_yaml:
            yaml_header_parts.append(f"title: {json.dumps(title_for_yaml)}")

        # 3. doi (オプショナル)
        doi_for_yaml = reference.get('doi')
        if doi_for_yaml:
            yaml_header_parts.append(f"doi: {json.dumps(doi_for_yaml)}")

        # 4. tags (labelsNamed と foldersNamed を結合し、スペースをアンダースコアに置換, オプショナル)
        def ensure_list(data):
            if isinstance(data, str):
                return [data]
            elif isinstance(data, list):
                return data
            return []

        labels_named_list = ensure_list(reference.get('labelsNamed', []))
        folders_named_list = ensure_list(reference.get('foldersNamed', []))
        
        raw_combined_tags = labels_named_list + folders_named_list
        
        processed_tags = []
        if raw_combined_tags:
            for tag_item in raw_combined_tags:
                if isinstance(tag_item, str):
                    processed_tags.append(tag_item.replace(' ', '_'))
                else:
                    logging.warning(f"タグリストに文字列でない要素が含まれています: {tag_item} (文献 citekey: {doc_id_for_citekey})。文字列に変換して処理します。")
                    processed_tags.append(str(tag_item).replace(' ', '_'))

        if processed_tags:
            yaml_header_parts.append(f"tags: {json.dumps(processed_tags)}")
        
        if yaml_header_parts:
             yaml_header_str = "---\n" + "\n".join(yaml_header_parts) + "\n---\n\n"
    else:
        title_for_log = reference.get('title', f'Untitled{ref_id_for_fallback}')
        logging.warning(f"文献 (タイトル: {title_for_log}) に '_id' が見つかりません。YAMLヘッダーは生成されません。")
    # --- YAMLヘッダー生成ここまで ---

    # Markdown本文用のデータ抽出
    title_for_filename = reference.get('title', f'Untitled{ref_id_for_fallback}')
    abstract = reference.get('abstract', 'N/A')
    authors = reference.get('author', [])
    published_data = reference.get('published')
    journal = reference.get('journal', 'N/A')
    pmid = reference.get('pmid', 'N/A')
    keywords_data = reference.get('keywords', "N/A")
    language = reference.get('language', 'N/A')
    urls_list = reference.get('url', [])
    note = reference.get('note', 'N/A')
    attachments = reference.get('attachments', [])

    ### MODIFIED ###
    # JSONファイルのattachmentsについて、"article_pdf": 1 のものを対象に
    # filenameの文字列の中で .pdf の拡張子を持つファイル名のみ（フォルダ名は含めない）抽出
    pdf_filenames_for_markdown = []
    if attachments: # attachments が None や空リストでないことを確認
        for att in attachments:
            # "article_pdf": 1 であることを確認
            if att.get('article_pdf') == 1:
                filename_from_json = att.get('filename', '') # filenameキーの存在とNoneを考慮
                # filename が .pdf で終わることを確認 (大文字・小文字を区別しない)
                if filename_from_json and filename_from_json.lower().endswith('.pdf'):
                    # フォルダ名を含まないファイル名のみを抽出
                    pdf_filename_only = os.path.basename(filename_from_json)
                    pdf_filenames_for_markdown.append(pdf_filename_only)
    ### MODIFIED END ###

    # 抽出したデータを整形
    gdrive_ids = get_gdrive_ids(attachments)

    if gdrive_ids:
        attachment_links = [f"- [添付ファイル {i+1}](https://drive.google.com/file/d/{id}/view?usp=sharing)" for i, id in enumerate(gdrive_ids)]
        attachment_link_str = "\n".join(attachment_links)
    else:
        attachment_link_str = "[添付ファイルリンクなし]"

    published_date_str = format_date(published_data)
    author_str = format_authors(authors)
    urls_str = format_urls(urls_list)

    # Markdown本文を構築
    markdown_body = f"""{attachment_link_str}

Abstract

{abstract}

Information

Authors: {author_str}
Journal: {journal}
Published date: {published_date_str}
PMID: {pmid}
Keywords: {keywords_data}
Language: {language}
URL: {urls_str}
Note: {note}
"""
    ### MODIFIED ###
    # markdownファイルの最下部に`![[{filename}]]`を追加
    if pdf_filenames_for_markdown:
        markdown_body += "\n" # Noteの行と最初のPDFリンクの間に空行を入れる
        for pdf_file in pdf_filenames_for_markdown:
            markdown_body += f"![[{pdf_file}]]\n" # 各PDFファイル名を追記し、改行
    ### MODIFIED END ###

    # YAMLヘッダーと本文を結合
    markdown_content = yaml_header_str + markdown_body

    # ファイル名を作成し、ファイルを書き込み
    filename = sanitize_filename(title_for_filename) + '.md'
    filepath = os.path.join(output_dir, filename)

    try:
        with open(filepath, 'w', encoding='utf-8') as md_file:
            md_file.write(markdown_content)
        logging.info(f"ファイル '{filepath}' を作成しました。")
    except IOError as e:
        logging.error(f"ファイル '{filepath}' への書き込み中にエラーが発生しました: {e}", exc_info=True)
        fallback_filename = f"{ref_id_for_fallback}.md"
        fallback_filepath = os.path.join(output_dir, fallback_filename)
        logging.info(f"フォールバックファイル名 '{fallback_filename}' で保存を試みます。")
        try:
             with open(fallback_filepath, 'w', encoding='utf-8') as md_file:
                md_file.write(markdown_content)
             logging.info(f"ファイル '{fallback_filepath}' を作成しました (フォールバック)。")
        except IOError as e_fallback:
            logging.error(f"フォールバックでもファイル '{fallback_filepath}' に書き込み中にエラーが発生しました: {e_fallback}", exc_info=True)


logging.info("処理が完了しました。")