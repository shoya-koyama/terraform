# ロードバランサでリクエストを振り分ける
# NLB=Network Load Balancer
resource "aws_lb" "example" {
  name               = "example"
  load_balancer_type = "application"
  # インターネット向けのため, false
  internal     = false
  idle_timeout = 60
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

output "alb_url" {
  value = "http://${aws_lb.example.dns_name}"
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
  port = "80"
  #ALBはHTTP/HTTPSのプロトコルをサポートしているため、HTTPを指定
  protocol = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.example.arn
  }
}

/*
# Route 53 のホストゾーンとDNSレコードを使う場合は、所有ドメインが必要です。
# 所有ドメインがない間は、上の ALB DNS 名（alb_url）を使います。
resource "aws_route53_zone" "test_example" {
  name = "test.example.com"
}

# DNSレコードを作成する
resource "aws_route53_record" "example" {
  zone_id = aws_route53_zone.test_example.zone_id
  name    = aws_route53_zone.test_example.name
  # ALIASレコードを作成する場合、typeはAを指定する必要があります。
  type = "A"

  # ALIASレコードを作成する場合、aliasブロックを使用して、ALBのDNS名とゾーンIDを指定する必要があります。
  alias {
    name                   = aws_lb.example.dns_name
    zone_id                = aws_lb.example.zone_id
    evaluate_target_health = true
  }
}

output "domain_name" {
  value = aws_route53_record.example.name
}
*/

/*
# HTTPS化するためのSSL証明書をACMで作成する。SSL証明書の自動更新が可能。
resource "aws_acm_certificate" "example" {
  domain_name               = aws_route53_record.example.name
  # ドメイン名の追加
  subject_alternative_names = []
  # ドメイン所有権の検証方法をDNSに設定する（SSL証明書の自動更新をしたい場合）
  validation_method         = "DNS"

  # 新しいSSL証明書を作ってから、古いSSL証明書と差し替える
  lifecycle {
    create_before_destroy = true
  }
}

# DNS検証用のレコードを作成する。ACMで作成したSSL証明書のドメイン所有権を検証するために必要。
resource "aws_route53_record" "example_certificate" {
  for_each = {
    for dvo in aws_acm_certificate.example.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  zone_id = data.aws_route53_zone.example.id
  ttl     = 60
}

# SSL証明書の検証完了まで待機
resource "aws_acm_certificate_validation" "example" {
  certificate_arn = aws_acm_certificate.example.arn
  validation_record_fqdns = [
    for record in aws_route53_record.example_certificate : record.fqdn
  ]
}

# HTTPSでALBにアクセスできるようにするためのHTTPSリスナーを作成する。
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.example.arn
  port              = "443"
  protocol          = "HTTPS"
  # SSL証明書を指定する
  certificate_arn   = aws_acm_certificate.example.arn
  # AWSではこのセキュリティポリシーを使用することを推奨しているため、ELBSecurityPolicy-2016-08を指定する
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "これは『HTTPS』です"
      status_code  = "200"
    }
  }
}

# HTTPリクエストをHTTPSにリダイレクトするためのリスナーを作成する。
resource "aws_lb_listener" "redirect_http_to_https" {
  load_balancer_arn = aws_lb.example.arn
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    # HTTPリクエストをHTTPSにリダイレクトするように設定する
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
*/

resource "aws_lb_target_group" "example" {
  name = "example"
  # ECS Fargateを使用する場合、ターゲットタイプはipを指定する必要があります。
  target_type          = "ip"
  vpc_id               = aws_vpc.example.id
  port                 = 80
  protocol             = "HTTP"
  deregistration_delay = 300

  health_check {
    # ヘルスチェックのパスを指定する。
    path = "/"
    # 正常判定を行うまでのヘルスチェックの実行回数を指定する。
    healthy_threshold = 5
    # 異常判定を行うまでのヘルスチェックの実行回数を指定する。
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = 200
    # 80となる。
    port     = "traffic-port"
    protocol = "HTTP"
  }

  # エラーを回避するために、ALBの作成が完了するまで待機するように設定する。
  depends_on = [aws_lb.example]
}

/*
resource "aws_lb_listener_rule" "example" {
  listener_arn = aws_lb_listener.https.arn
  # リスナーの優先度を指定する。優先度は1から50000までの整数値で指定する必要があります。優先度が低いほど、リクエストがルールにマッチしやすくなります。
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.example.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}
*/