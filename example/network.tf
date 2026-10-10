resource "aws_vpc" "example" {
  cidr_block           = "10.0.0.0/16"
  # enable_dns_support と enable_dns_hostnames を true に設定することで、VPC 内のリソースが DNS 名を解決できるようになります。
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "example"
  }
}

# VPCをさらに分割し、サブネットを作成。VPC 内のリソースがインターネットにアクセスできるようにするために、パブリック IP アドレスを自動的に割り当てるように設定します。
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.example.id
  # サブネットのCIDRブロックを指定します。ここでは、VPCのCIDRブロックの一部を使用しています。特にこだわりがなければ、VPCでは/16, サブネットでは/24を使用するのが一般的です。
  cidr_block              = "10.0.0.0/24"
  # VPC 内のリソースがインターネットにアクセスできるようにするために、パブリック IP アドレスを自動的に割り当てるように設定します。
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-1a"
}

# VPC単体ではインターネットにアクセスできないため、インターネットゲートウェイを作成し、VPCにアタッチする必要があります。
resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id
}

# インターネットゲートウェイだけでは、VPC内のリソースがインターネットにアクセスできるようにはなりません。ルートテーブルを作成し、インターネットゲートウェイへのルートを追加する必要があります。
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.example.id
}

# ルートテーブルにルートを追加することで、VPC内のリソースがインターネットにアクセスできるようになります.
resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.example.id
  destination_cidr_block = "0.0.0.0/0"
}

# ルートテーブルをサブネットに関連付けることで、VPC内のリソースがインターネットにアクセスできるようになります。
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# プライベートサブネットを作成することで、VPC内のリソースがインターネットにアクセスできないようにすることができます。プライベートサブネットは、セキュリティ上の理由から、インターネットに直接アクセスする必要のないリソースに使用されます。
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.64.0/24"
  availability_zone       = "ap-northeast-1a"
  # VPC 内のリソースがインターネットにアクセスできないようにするために、パブリック IP アドレスを自動的に割り当てないように設定します。
  map_public_ip_on_launch = false
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# NATサーバーを作成することで、プライベートサブネット内のリソースがインターネットにアクセスできるようになります。NATサーバーは、プライベートサブネット内のリソースがインターネットにアクセスする際に、パブリックIPアドレスを使用して通信を行うためのゲートウェイとして機能します。
# EIPとは静的なパブリックIPアドレスを付与するサービスです。NATゲートウェイは、EIPが必要です。
resource "aws_eip" "nat_gateway" {
  vpc        = true
  # depends_onを使って、依存を明示的に指定することで、インターネットゲートウェイが作成後にEIPやNATゲートウェイが作成されるようにすることができます。
  depends_on = [aws_internet_gateway.example]
}

resource "aws_nat_gateway" "example" {
  allocation_id = aws_eip.nat_gateway.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.example]
}

resource "aws_route" "private" {
  route_table_id         = aws_route_table.private.id
  nat_gateway_id         = aws_nat_gateway.example.id
  destination_cidr_block = "0.0.0.0/0"
}

# ネットワークをマルチAZ構成にするために、別のパブリックサブネットを作成します。これにより、可用性が向上し、障害発生時のリスクを軽減できます。
resource "aws_subnet" "public_0" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = true
}

# パブリックサブネットとルートてーブルを関連付けることで、マルチAZ化
resource "aws_route_table_association" "public_0" {
  subnet_id      = aws_subnet.public_0.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

# プライベートサブネットをマルチAZ化
resource "aws_subnet" "private_0" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.65.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = false
}

resource "aws_subnet" "private_1" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.66.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = false
}

# NATゲートウェイをアベイrラビリティゾーンごとに作成する。単体で運用すると、あるアベイラビリティゾーンが障害になった場合、NATゲートウェイが利用できなくなるため。
resource "aws_eip" "nat_gateway_0" {
  vpc        = true
  depends_on = [aws_internet_gateway.example]
}

resource "aws_eip" "nat_gateway_1" {
  vpc        = true
  depends_on = [aws_internet_gateway.example]
}

resource "aws_nat_gateway" "nat_gateway_0" {
  allocation_id = aws_eip.nat_gateway_0.id
  subnet_id     = aws_subnet.public_0.id
  depends_on    = [aws_internet_gateway.example]
}

resource "aws_nat_gateway" "nat_gateway_1" {
  allocation_id = aws_eip.nat_gateway_1.id
  subnet_id     = aws_subnet.public_1.id
  depends_on    = [aws_internet_gateway.example]
}

resource "aws_route_table" "private_0" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route" "private_0" {
  route_table_id         = aws_route_table.private_0.id
  nat_gateway_id         = aws_nat_gateway.nat_gateway_0.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route" "private_1" {
  route_table_id         = aws_route_table.private_1.id
  nat_gateway_id         = aws_nat_gateway.nat_gateway_1.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "private_0" {
  subnet_id      = aws_subnet.private_0.id
  route_table_id = aws_route_table.private_0.id
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_1.id
}

# ルートテーブルもアベイラビリティゾーンごとに作成する。
resource "aws_route_table" "private_0" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route" "private_0" {
  route_table_id         = aws_route_table.private_0.id
  nat_gateway_id         = aws_nat_gateway.nat_gateway_0.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route" "private_1" {
  route_table_id         = aws_route_table.private_1.id
  nat_gateway_id         = aws_nat_gateway.nat_gateway_1.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "private_0" {
  subnet_id      = aws_subnet.private_0.id
  route_table_id = aws_route_table.private_0.id
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_1.id
}

# セキュリティグループを使うと、OSへ到達する前に、ネットワークレベルでアクセス制御を行うことができます。セキュリティグループは、VPC内のリソースに対して適用されます。
resource "aws_security_group" "example" {
  name   = "example"
  vpc_id = aws_vpc.example.id
}

resource "aws_security_group_rule" "ingress_example" {
  # インバウンド
  type              = "ingress"
  from_port         = "80"
  to_port           = "80"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.example.id
}

resource "aws_security_group_rule" "egress_example" {
  # アウトバウンド
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.example.id
}

# module "example_sg" {
#   source      = "./security_group"
#   name        = "module-sg"
#   vpc_id      = aws_vpc.example.id
#   port        = 80
#   cidr_blocks = ["0.0.0.0/0"]
# }