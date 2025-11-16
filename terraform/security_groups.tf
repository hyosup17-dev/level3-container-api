# --- 1. DB용 보안 그룹 (방화벽) ---
# (이 블록 전체를 복사해서 덮어쓰세요)
resource "aws_security_group" "rds_sg" {
  name        = "level3-rds-sg"
  description = "Allow Postgres traffic"
  vpc_id      = aws_vpc.main.id

  # Ingress (들어오는 트래픽 규칙)
  
  # 규칙 1: Private Subnet 'A'에서 오는 5432 포트 허용
  ingress {
    description     = "Allow Postgres from Private Subnet A"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    cidr_blocks     = [aws_subnet.private_a.cidr_block]
  }
  
  # 규칙 2: Private Subnet 'C'에서 오는 5432 포트 허용
  ingress {
    description     = "Allow Postgres from Private Subnet C"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    cidr_blocks     = [aws_subnet.private_c.cidr_block]
  }

  # 규칙 3: 'ECS 앱'(ecs_service_sg)으로부터 오는 5432 포트 허용
  ingress {
    description     = "Allow Postgres from ECS Service"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_service_sg.id]
  }

  # Egress (나가는 트래픽 규칙)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "level3-rds-sg" }
}

# --- 👇 2. (추가) ALB용 보안 그룹 (방화벽) ---
resource "aws_security_group" "alb_sg" {
    name = "level3-alb-sg"
    description = "Allow HTTP trafic from Internet"
    vpc_id = aws_vpc.main.id

    # Ingress: 인터넷(0.0.0.0/0)에서 오는 80번 포트(HTTP) 허용
    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"] # 모든 IP
    }

    # Egress: 모든 트래픽 허용
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = { Name = "level3-alb-sg" }
}

# --- 👇 3. (추가) ECS 서비스용 보안 그룹 (방화벽) ---
resource "aws_security_group" "ecs_service_sg" {
    name = "level3-ecs-service-sg"
    description = "Allow traffic only from ALB"
    vpc_id = aws_vpc.main.id

    # Ingress: 'ALB'(alb_sg)로부터 오는 5000번 포트(앱 포트)만 허용
    ingress {
        from_port       = 5000
        to_port         = 5000
        protocol        = "tcp"
        security_groups = [aws_security_group.alb_sg.id] # ALB 방화벽
    }

    # Egress: 모든 트래픽 허용 (DB 연결 및 NAT Gateway 경유)
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = { Name = "level3-ecs-service-sg" }
}