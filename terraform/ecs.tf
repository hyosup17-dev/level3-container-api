# --- 1. ECS 클러스터 ('공장 단지') ---
resource "aws_ecs_cluster" "main_cluster" {
    name = "level3-cluster"
    tags = { Name = "level3-cluster" }
}

# --- 2. ECS Task 실행용 IAM 역할 ---
# ECS Task(컨테이너)가 AWS API(ECR, CloudWatch 등)에 접근할 수 있도록
resource "aws_iam_role" "ecs_task_execution_role" {
    name = "level3-ecs-task-execution-role"

    # ECS Tasks 서비스가 이 역할을 맡을 수 있도록 허용
    assume_role_policy = jsonencode({
        Version = "2012-10-17",
        Statement = [{
            Action = "sts:AssumeRole",
            Effect = "Allow",
            Principal = {
                Service = "ecs-tasks.amazonaws.com"
            }
        }]
    })
}

# 2-1. 위 역할에 '기본 권한' 연결
# (ECR에서 이미지 당겨오기, CloudWatch에 로그 쓰기)
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
    role       = aws_iam_role.ecs_task_execution_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- 3. ECS Task Definition (컨테이너 '설계도') ---
# "어떤 이미지로, CPU/메모리는 얼마로, 어떤 환경 변수로 컨테이너를 띄워라"
resource "aws_ecs_task_definition" "api_task" {
    family                   = "level3-api-task"
    network_mode             = "awsvpc" # Fargate는 'awsvpc' 모드만 사용
    requires_compatibilities = ["FARGATE"]
    cpu                      = 256 # 0.25 vCPU
    memory                   = 512 # 0.5 GB RAM
    execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

    # 컨테이너 정의 (app.py)
    container_definitions = jsonencode([
        {
            name  = "level3-api-container"
            image = aws_ecr_repository.api_repo.repository_url # 1번 ECR 창고 주소
            portMappings = [
                {
                    containerport = 5000 # app.py가 실행중인 포트
                    hostport      = 5000
                }
            ],

            # ★★★ 핵심 ★★★
            # app.py가 읽을 환경 변수를 여기서 주입합니다.
            environment = [
                { name = "DB_HOST", value = aws_db_instance.main_db.address },
                { name = "DB_PORT", value = "5432" },
                { name = "DB_NAME", value = "postgres" },
                { name = "DB_USER", value = "postgres" },
                { name = "DB_PASSWORD", value = "mysecretpassword" }
            ],

            # CloudWatch 로그 설정
            logConfiguration = {
                logDriver = "awslogs",
                options = {
                    "awslogs-group" = "/ecs/level3-api",
                    "awslogs-region" = "ap-northeast-2",
                    "awslogs-stream-prefix" = "ecs"
                }
            }
        }
    ])

    tags = { Name = "level3-api-task" }
}

# --- 4. CloudWatch 로그 그룹 ---
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name = "/ecs/level3-api"
  tags = { Name = "level3-ecs-logs" }
}

# --- 5. ECS 서비스 ('공장 관리자') ---
# "위 3번 '설계도'를 가지고, 컨테이너 1개를 Fargate로 실행해라"
# "그리고 '정문'(ALB)과 연결해라"
resource "aws_ecs_service" "api_service" {
    name            = "level3-api-service"
    cluster         = aws_ecs_cluster.main_cluster.id
    task_definition = aws_ecs_task_definition.api_task.arn
    desired_count   = 1 # 컨테이너 1개 실행
    launch_type     = "FARGATE"

    # 네트워크 설정
    network_configuration {
        # 컨테이너는 '보안 구역'(Private Subnet)에 배치
        subnets         = [aws_subnet.private_a.id, aws_subnet.private_c.id]
        # 'ECS 앱 방화벽' 적용
        security_groups = [aws_security_group.ecs_service_sg.id]
    }

    # 로드 밸런서(정문)와 연결
    load_balancer {
        target_group_arn = aws_lb_target_group.api_tg.arn
        container_name   = "level3-api-container"
        container_port   = 5000
    }

    # Task Definition이 바뀌면 자동으로 새 버전을 배포
    force_new_deployment = true

    # ALB가 새 Task를 등록할 시간을 기다려줌
    health_check_grace_period_seconds = 60

    # ALB가 생성된 후에 이 서비스를 생성
    depends_on = [aws_lb_listener.http_listener]

    tags = { Name = "level3-api-service" }
}