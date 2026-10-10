resource "aws_instance" "example" {
  ami                    = "ami-0c3fd0f5d33134a76"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.example_ec2.id]

  user_data = <<EOF
    #!/bin/bash
    yum install -y httpd
    systemctl start httpd.service
EOF
}

output "example_public_dns" {
  value = aws_instance.example.public_dns
}

# http server module を使用する場合は、以下のコードを使用してください。
# provider "aws" {
#   region = "ap-northeast-1"
# }
#
# module "web_server" {
#   source        = "./http_server"
#   instance_type = "t3.micro"
# }
#
# output "public_dns" {
#   value = module.web_server.public_dns
# }