resource "aws_s3_bucket" "private" {
  bucket = "private-pragmatic-terraform"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

# S3バケットのパブリックアクセスをブロックする
resource "aws_s3_bucket_public_access_block" "private" {
  bucket                  = aws_s3_bucket.private.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 外部パブリックアクセスを許可するS3バケットを作成する
resource "aws_s3_bucket" "public" {
  bucket = "public-pragmatic-terraform"
  # インターネットからのアクセスを許可するために、パブリック読み取りアクセスを有効にする
  acl    = "public-read"

  cors_rule {
    allowed_origins = ["https://example.com"]
    allowed_methods = ["GET"]
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket" "alb_log" {
  bucket = "alb-log-pragmatic-terraform"

  # 180日後にオブジェクトを削除するライフサイクルルールを設定する
  lifecycle_rule {
    enabled = true

    expiration {
      days = "180"
    }
  }
}

# S3バケットのパブリックアクセスをブロックする
resource "aws_s3_bucket_policy" "alb_log" {
  bucket = aws_s3_bucket.alb_log.id
  policy = data.aws_iam_policy_document.alb_log.json
}

data "aws_iam_policy_document" "alb_log" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.alb_log.id}/*"]

    principals {
      type        = "AWS"
      identifiers = ["582318560864"] # AWS ALBのログ配信サービスのアカウントID
    }
  }
}