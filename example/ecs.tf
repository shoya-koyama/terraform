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
  # DockerコンテナがCloud Watch Logsにログを投げられるようにする。
  execution_role_arn = module.ecs_task_execution_role.iam_role_arn
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

  # lifecycle {
  #   # タスク定義が更新された場合に、ECSサービスを更新する際に、タスク定義の変更を無視するように設定する。これにより、タスク定義が更新されても、ECSサービスは既存のタスクを維持し、新しいタスクを起動しないようになります。
  #   ignore_changes = [task_definition]
  # }

  depends_on = [aws_lb_listener.http]
}

module "nginx_sg" {
  source      = "./security_group"
  name        = "nginx-sg"
  vpc_id      = aws_vpc.example.id
  port        = 80
  cidr_blocks = [aws_vpc.example.cidr_block]
}

resource "aws_cloudwatch_log_group" "for_ecs" {
  name              = "/ecs/example"
  retention_in_days = 180
}

# ECSタスク実行 IAMロール
data "aws_iam_policy" "ecs_task_execution_role_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_task_execution" {
  # 既存のポリシーを継承
  source_json = data.aws_iam_policy.ecs_task_execution_role_policy.policy

  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameters", "kms:Decrypt"]
    resources = ["*"]
  }
}

module "ecs_task_execution_role" {
  source = "./iam_role"
  name   = "ecs-task-execution"
  # このIAMロールをECSで使うことを宣言
  identifier = "ecs-tasks.amazonaws.com"
  policy     = data.aws_iam_policy_document.ecs_task_execution.json
}

# リトライできるようアプリケーションを設計する必要がある
# バッチ用
resource "aws_cloudwatch_log_group" "for_ecs_scheduled_tasks" {
  name              = "/ecs-scheduled-tasks/example"
  retention_in_days = 180
}

resource "aws_ecs_task_definition" "example_batch" {
  family                   = "example-batch"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  container_definitions    = file("./batch_container_definitions.json")
  execution_role_arn       = module.ecs_task_execution_role.iam_role_arn
}

# CloudWatchイベントからECSを起動するためのIAMロールを作成
module "ecs_events_role" {
  source     = "./iam_role"
  name       = "ecs-events"
  identifier = "events.amazonaws.com"
  policy     = data.aws_iam_policy.ecs_events_role_policy.policy
}

data "aws_iam_policy" "ecs_events_role_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceEventsRole"
}

# CloudWatchイベントルール
resource "aws_cloudwatch_event_rule" "example_batch" {
  name                = "example-batch"
  description         = "とても重要なバッチ処理です"
  schedule_expression = "cron(*/2 * * * ? *)"
}

resource "aws_cloudwatch_event_target" "example_batch" {
  target_id = "example-batch"
  # イベントルールを指定
  rule = aws_cloudwatch_event_rule.example_batch.name
  # イベントIAMロールを指定
  role_arn = module.ecs_events_role.iam_role_arn
  # ターゲットをarnで指定
  arn = aws_ecs_cluster.example.arn

  ecs_target {
    launch_type         = "FARGATE"
    task_count          = 1
    platform_version    = "LATEST"
    task_definition_arn = aws_ecs_task_definition.example_batch.arn

    network_configuration {
      assign_public_ip = "false"
      subnets          = [aws_subnet.private_0.id]
    }
  }
}