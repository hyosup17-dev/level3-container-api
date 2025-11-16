# --- 1. ALB (Application Load Balancer) ---
# 인터넷 트래픽을 받아 ECS(앱)로 전달합니다.
# 로드 밸런서 자체는 'Public Subnet'에 위치해야 합니다.
resource "aws_lb" "main_alb" {
    name               = "level3-alb"
    internal           = false
    load_balancer_type = "application"

    # ALB가 위치할 '공용 구역'(Public Subnet) 2곳
    subnets            = [aws_subnet.public_a.id, aws_subnet.public_c.id]

    # '방화벽'은 잠시 후 security_groups.tf에서 만들 'alb_sg'를 사용
    security_groups    = [aws_security_group.alb_sg.id]

    tags = { Name = "level3-alb" }
}

# --- 2. ALB 타겟 그룹 (트래픽 전달 예상) ---
# ALB가 트래픽을 전달할 '대상 그룹' (우리의 ECS앱)
resource "aws_lb_target_group" "api_tg" {
    name        = "level3-api-tg"
    port        = 5000 # 앱 컨테이너가 실행 중인 포트
    protocol    = "HTTP"
    vpc_id      = aws_vpc.main.id
    target_type = "ip" # Fargate는 IP 기반으로 타겟팅

    # Health Check 설정: 로드 밸런서가 앱이 살아있는지 확인
    health_check {
        path                = "/todos" # (임시) /todos 경로로 확인
        protocol            = "HTTP"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 3
        unhealthy_threshold = 3       
    }

    tags = { Name = "level3-api-tg" }
}

# --- 3. ALB 리스너 (정문 '경비원') ---
# '정문'(ALB)의 30번 포트로 오는 HTTP 트래픽을 
# 2번에서 만든 '대상 그룹'(api-tg)으로 전달(forward)합니다.
resource "aws_lb_listener" "http_listener" {
    load_balancer_arn = aws_lb.main_alb.arn
    port              = 80
    protocol          = "HTTP"

    # 기본 동작: 80포트 -> api_tg
    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.api_tg.arn
    }
}

# --- 4. (추가) ALB의 DNS 주소(정문 주소) 출력 ---
output "alb_dns_name" {
    description = "The DNS name of the ALB"
    value       = aws_lb.main_alb.dns_name
}