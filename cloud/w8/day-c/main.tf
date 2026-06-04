module "vpc" {
  source = "./modules/vpc"
}

locals {
  name_prefix = trimsuffix(substr(replace(replace(lower(var.project_name), " ", "-"), "_", "-"), 0, 24), "-")
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_security_group" "web_sg" {
  name_prefix = "${local.name_prefix}-web-"
  vpc_id      = module.vpc.vpc_id
  description = "Allow HTTP inbound traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-web-sg"
  }
}

resource "aws_security_group" "db_sg" {
  name_prefix = "${local.name_prefix}-db-"
  vpc_id      = module.vpc.vpc_id
  description = "Allow MySQL traffic from Web Server only"

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-db-sg"
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.web_instance_type
  subnet_id              = module.vpc.public_subnet_id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  user_data_replace_on_change = true
  user_data              = <<-EOF
    #!/bin/bash
    set -eux

    dnf update -y
    dnf install -y httpd

    cat > /var/www/html/index.html <<'HTML'
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>${var.project_name} Demo</title>
        <style>
          body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 32px;
            background: #f4f7fb;
            color: #1f2937;
          }
          .panel {
            max-width: 760px;
            margin: 0 auto;
            background: #ffffff;
            border: 1px solid #dbe3ee;
            padding: 24px;
          }
          h1 {
            margin-top: 0;
          }
          dl {
            display: grid;
            grid-template-columns: 180px 1fr;
            gap: 12px 16px;
          }
          dt {
            font-weight: 700;
          }
          code {
            background: #eef2f7;
            padding: 2px 6px;
          }
        </style>
      </head>
      <body>
        <div class="panel">
          <h1>${var.project_name}</h1>
          <p>Demo web deployed by Terraform on EC2.</p>
          <dl>
            <dt>Region</dt>
            <dd>${var.region}</dd>
            <dt>Web Instance</dt>
            <dd>${local.name_prefix}-web</dd>
            <dt>S3 Bucket</dt>
            <dd><code>${aws_s3_bucket.assets.bucket}</code></dd>
            <dt>DB Endpoint</dt>
            <dd><code>${aws_db_instance.mysql.address}</code></dd>
            <dt>Database</dt>
            <dd><code>${aws_db_instance.mysql.db_name}</code></dd>
          </dl>
        </div>
      </body>
    </html>
    HTML

    systemctl enable httpd
    systemctl start httpd
  EOF

  tags = {
    Name = "${local.name_prefix}-web"
  }
}

resource "aws_db_subnet_group" "db_subnet_grp" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = module.vpc.private_subnet_ids

  tags = {
    Name = "${local.name_prefix}-db-subnet-group"
  }
}

resource "aws_db_instance" "mysql" {
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.db_instance_class
  identifier             = "${local.name_prefix}-mysql"
  db_name                = "app_database"
  username               = var.db_username
  password               = var.db_password
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_grp.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
  storage_encrypted      = true
}

resource "aws_s3_bucket" "assets" {
  bucket_prefix = "${local.name_prefix}-assets-"
  force_destroy = true

  tags = {
    Name = "${local.name_prefix}-assets"
  }
}
