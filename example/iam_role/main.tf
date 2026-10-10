variable "name" {}
variable "policy" {}
variable "identifier" {}

# IAMロールを作成する
resource "aws_iam_role" "default" {
  name               = var.name
  # 信頼ポリシーを指定する。
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# 信頼ポリシー
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = [var.identifier] # どのサービスがこのロールを引き受けることができるかを指定する。例: "ec2.amazonaws.com"
    }
  }
}

# IAMポリシーを作成する
resource "aws_iam_policy" "default" {
  name   = var.name
  policy = var.policy
}

# IAMロールにIAMポリシーをアタッチする
resource "aws_iam_role_policy_attachment" "default" {
  role       = aws_iam_role.default.name
  policy_arn = aws_iam_policy.default.arn
}

# IAMロールのARNと名前を出力する
output "iam_role_arn" {
  value = aws_iam_role.default.arn
}

# IAMロールの名前を出力する
output "iam_role_name" {
  value = aws_iam_role.default.name
}