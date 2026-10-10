resource "aws_s3_bucket" "private" {
  bucket = "private-pragmatic-terraform-k8m4v2q9"

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
  bucket = "public-pragmatic-terraform-k8m4v2q9"

  cors_rule {
    allowed_origins = ["https://example.com"]
    allowed_methods = ["GET"]
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_public_access_block" "public" {
  bucket                  = aws_s3_bucket.public.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_identity" "public" {
  comment = "Access to ${aws_s3_bucket.public.bucket} from CloudFront"
}

resource "aws_s3_bucket_policy" "public" {
  bucket = aws_s3_bucket.public.id
  policy = data.aws_iam_policy_document.public_bucket.json
}

data "aws_iam_policy_document" "public_bucket" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.public.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.public.iam_arn]
    }
  }
}

resource "aws_cloudfront_distribution" "public" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  origin {
    domain_name = aws_s3_bucket.public.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.public.id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.public.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    target_origin_id       = aws_s3_bucket.public.id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "public_cloudfront_domain_name" {
  value = aws_cloudfront_distribution.public.domain_name
}

resource "aws_s3_bucket" "alb_log" {
  bucket = "alb-log-pragmatic-terraform-k8m4v2q9"

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