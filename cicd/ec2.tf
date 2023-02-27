resource "aws_instance" "web" {
  ami           = var.ami
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.web.id]

  key_name                    = var.key_name
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              sudo yum -y update
              sudo yum -y install httpd
              sudo systemctl start httpd
              sudo systemctl enable httpd
              echo "<html><body><h1>Welcome to ${var.environment} environment</h1></body></html>" > /var/www/html/index.html
              EOF
  tags = {
    Name = "web-${var.environment}"
  }
}

resource "aws_security_group" "web" {
  name_prefix = "web-${var.environment}-"
}

resource "aws_security_group_rule" "http_ingress" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web.id
}
