resource "aws_ecs_cluster" "example" {
  name = "example"
}

resource "aws_ecs_task_definition" "example" {
  # タスク定義名のプレフィックス
  family = "example"
  # タスクサイズ
  cpu    = "256"
  memory = "512"
  # Fargate起動タイプの場合は、ネットワークモードはawsvpcを指定する必要があります。
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  container_definitions    = file("./container_definitions.json")
}

# 通常、コンテナを起動しても、処理が完了したらすぐに終了する。それを防ぐため、ECSサービスを使う。
resource "aws_ecs_service" "example" {
  name    = "example"
  cluster = aws_ecs_cluster.example.arn
  # タスク定義を設定する。
  task_definition = aws_ecs_task_definition.example.arn
  # タスク数　1を指定してしまうと、タスクが終了したら再起動されるため、タスクが終了しないようにするためには2以上を指定する必要があります。
  desired_count = 2
  launch_type   = "FARGATE"
  # 利用可能な最新の Fargate プラットフォームバージョンを使用する。
  platform_version = "LATEST"
  # タスク起動時のヘルスチェック猶予期間を指定する。タスク起動時にヘルスチェックが失敗することがあるため、猶予期間を設けることで、タスクが正常に起動するまでの時間を確保することができます。
  health_check_grace_period_seconds = 60

  # サブネットとセキュリティグループを設定する。
  network_configuration {
    assign_public_ip = false
    security_groups  = [module.nginx_sg.security_group_id]

    subnets = [
      aws_subnet.private_0.id,
      aws_subnet.private_1.id,
    ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.example.arn
    container_name   = "example"
    container_port   = 80
  }

  lifecycle {
    # タスク定義が更新された場合に、ECSサービスを更新する際に、タスク定義の変更を無視するように設定する。これにより、タスク定義が更新されても、ECSサービスは既存のタスクを維持し、新しいタスクを起動しないようになります。
    ignore_changes = [task_definition]
  }

  depends_on = [aws_lb_listener.http]
}

module "nginx_sg" {
  source      = "./security_group"
  name        = "nginx-sg"
  vpc_id      = aws_vpc.example.id
  port        = 80
  cidr_blocks = [aws_vpc.example.cidr_block]
}