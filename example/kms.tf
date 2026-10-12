# KMSはエンべローブ暗号化が採用されている
# 暗号化戦略を意識せずに使うことが可能であり、カスタマーマスターキーを指定すれば、自動的にデータの暗号化と復号を行うことができる
resource "aws_kms_key" "example" {
  description             = "Example Customer Master Key"
  # ローテーションの頻度は年に一度
  enable_key_rotation     = true
  is_enabled              = true
  # カスタマーマスターキーの削除待機期間（削除は推奨されない）
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "example" {
  # alias/ というプレフィックスが必要
  name          = "alias/example"
  target_key_id = aws_kms_key.example.key_id
}