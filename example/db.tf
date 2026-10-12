resource "aws_db_parameter_group" "example" {
  name   = "example"
  family = "mysql8.0"

  parameter {
    name = "character_set_database"
    # 文字コード
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }
}
resource "aws_db_option_group" "example" {
  name                 = "example"
  engine_name          = "mysql"
  major_engine_version = "8.0"

  option {
    option_name = "MARIADB_AUDIT_PLUGIN"
  }
}

resource "aws_db_subnet_group" "example" {
  name       = "example"
  subnet_ids = [aws_subnet.private_0.id, aws_subnet.private_1.id]
}

resource "aws_db_instance" "example" {
  identifier     = "example"
  engine         = "mysql"
  engine_version = "8.0.46"
  # Free Tierで利用可能なインスタンスクラス
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  max_allocated_storage = 100
  # 汎用SSD
  storage_type      = "gp2"
  storage_encrypted = true
  # ディスク暗号化
  kms_key_id = aws_kms_key.example.arn
  username   = "admin"
  password   = "VeryStrongPassword!"
  # Free TierではSingle-AZを使用
  multi_az            = false
  publicly_accessible = false
  # UTCで設定
  backup_window = "09:10-09:40"
  # Free Tierで許可される自動バックアップ保持期間
  backup_retention_period = 0
  # UTCで設定
  maintenance_window = "mon:10:10-mon:10:40"
  # 自動マイナーバージョンアップ無効化
  auto_minor_version_upgrade = false
  # 削除保護
  deletion_protection = true
  # インスタンス削除時のスナップショット作成のため、false
  skip_final_snapshot = false
  port                = 3306
  # 即時反映を避ける
  apply_immediately      = false
  vpc_security_group_ids = [module.mysql_sg.security_group_id]
  parameter_group_name   = aws_db_parameter_group.example.name
  option_group_name      = aws_db_option_group.example.name
  db_subnet_group_name   = aws_db_subnet_group.example.name

  lifecycle {
    ignore_changes = [password]
  }
}

# VPC内からの通信のみ許可
module "mysql_sg" {
  source      = "./security_group"
  name        = "mysql-sg"
  vpc_id      = aws_vpc.example.id
  port        = 3306
  cidr_blocks = [aws_vpc.example.cidr_block]
}

# クラスターモード無効化
resource "aws_elasticache_parameter_group" "example" {
  name   = "example"
  family = "redis5.0"

  parameter {
    name  = "cluster-enabled"
    value = "no"
  }
}

resource "aws_elasticache_subnet_group" "example" {
  name       = "example"
  subnet_ids = [aws_subnet.private_0.id, aws_subnet.private_1.id]
}

resource "aws_elasticache_replication_group" "example" {
  replication_group_id          = "example"
  replication_group_description = "Cluster Disabled"
  # redis or memcached
  engine                        = "redis"
  engine_version                = "5.0.4"
  # ノード数
  number_cache_clusters         = 3
  node_type                     = "cache.m3.medium"
  snapshot_window               = "09:10-10:10"
  snapshot_retention_limit      = 7
  maintenance_window            = "mon:10:40-mon:11:40"
  # 自動フェイルオーバー
  automatic_failover_enabled    = true
  port                          = 6379
  # ElastiCacheの設定変更のタイミングを制御
  apply_immediately             = false
  security_group_ids            = [module.redis_sg.security_group_id]
  parameter_group_name          = aws_elasticache_parameter_group.example.name
  subnet_group_name             = aws_elasticache_subnet_group.example.name
}

module "redis_sg" {
  source      = "./security_group"
  name        = "redis-sg"
  vpc_id      = aws_vpc.example.id
  port        = 6379
  cidr_blocks = [aws_vpc.example.cidr_block]
}