#!/bin/bash
# ==============================================================================
# Salesforce カスタム項目 使用箇所調査スクリプト (v3: 初回ヒットのみ抽出版)
#
# 目的: 指定した項目リストをもとに、メタデータフォルダ内を検索する。
#       ★変更点: 1つのファイル内で複数回使用されていても、最初の1箇所だけを出力する。
#
# 作成者: Salesforce Technical Lead
# ==============================================================================

FIELDS_FILE=$1
TARGET_DIR=$2

if [ -z "$FIELDS_FILE" ] || [ -z "$TARGET_DIR" ]; then
  echo "Usage: ./field_usage.sh fields.txt target_dir"
  exit 1
fi

# CSVヘッダー
echo "field_api_name,file,line_no,content"

while read FIELD; do
  # 空行・コメント行のトリムとスキップ
  # 行頭・行末の空白削除処理を追加
  FIELD=$(echo "$FIELD" | xargs)
  [[ -z "$FIELD" || "$FIELD" == \#* ]] && continue

# -r: 再帰検索
  # -I: バイナリファイル無視 (StaticResource等の誤爆防止)
  # -n: 行番号出力
  # -i: 大文字小文字を区別しない (Salesforce必須)
  # -w: 単語境界で検索 (Partial match防止)
  #     ※ -w は "Field__c" が "My_Field__c" にマッチするのを防ぎますが、
  #        "Field__c;" や "Field__c)" には正しくマッチします。
  # -m 1 : 各ファイルで「1回」マッチしたら、そのファイルの検索を打ち切る。
  #        これにより、1ファイルにつき出力が最大1行になり、
  #        「使用されているかどうか」だけを効率的に判定できます。
  #
  # 他のオプションの復習:
  # -r: 再帰検索, -I: バイナリ無視, -n: 行番号, -i: 大文字小文字無視, -w: 単語境界
  
  grep -rInw "$FIELD" "$TARGET_DIR" | while read -r LINE; do
    # ファイルパス区切り文字としてのコロンと、コンテンツ内のコロンを分けるため、
    # cutコマンドの制限を考慮して変形
    
    FILE=$(echo "$LINE" | cut -d: -f1)
    LINE_NO=$(echo "$LINE" | cut -d: -f2)
    # 3フィールド目以降すべてをコンテンツとする（コード内にコロンが含まれる場合への対処）
    CONTENT=$(echo "$LINE" | cut -d: -f3-)

    # CSV破損対策: コンテンツ内のダブルクォートを2重ダブルクォートにエスケープ
    CONTENT_ESCAPED="${CONTENT//\"/\"\"}"

    echo "$FIELD,$FILE,$LINE_NO,\"$CONTENT_ESCAPED\""
  done
done < "$FIELDS_FILE"
