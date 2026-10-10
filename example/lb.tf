# ロードバランサでリクエストを振り分ける
# NLB=Network Load Balancer
resource "aws_lb" "example" {
  name                       = "example"
  load_balancer_type         = "application"
  # インターネット向けのため, false
  internal                   = false
  idle_timeout               = 60
  # 削除保護有効
  enable_deletion_protection = true

  subnets = [
    aws_subnet.public_0.id,
    aws_subnet.public_1.id,
  ]

  # アクセスログ S3 バケットの設定
  access_logs {
    bucket  = aws_s3_bucket.alb_log.id
    enabled = true
  }

  security_groups = [
    module.http_sg.security_group_id,
    module.https_sg.security_group_id,
    module.http_redirect_sg.security_group_id,
  ]
}

output "alb_dns_name" {
  value = aws_lb.example.dns_name
}

# ロードバランサのセキュリティグループを作成する
module "http_sg" {
  source      = "./security_group"
  name        = "http-sg"
  vpc_id      = aws_vpc.example.id
  port        = 80
  cidr_blocks = ["0.0.0.0/0"]
}

module "https_sg" {
  source      = "./security_group"
  name        = "https-sg"
  vpc_id      = aws_vpc.example.id
  port        = 443
  cidr_blocks = ["0.0.0.0/0"]
}

module "http_redirect_sg" {
  source      = "./security_group"
  name        = "http-redirect-sg"
  vpc_id      = aws_vpc.example.id
  port        = 8080
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  # HTTPなので80番ポートを指定
  port              = "80"
  #ALBはHTTP/HTTPSのプロトコルをサポートしているため、HTTPを指定
  protocol          = "HTTP"

  default_action {
    # 固定のレスポンスを返すように設定する
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "これは『HTTP』です"
      status_code  = "200"
    }
  }
}