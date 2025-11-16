# --- 1. RDS가 사용할 'Private Subnet' 그룹 ---
resource "aws_db_subnet_group" "main_db_subnet_group" {
    name       = "level3-db-subnet-group"
    subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_c.id]

    tags = { Name = "level3-db-subnet-group" }
}

# --- 2. RDS 데이터베이스 인스턴스 ---
resource "aws_db_instance" "main_db" {
    allocated_storage = 10            # 10GB 스토리지
    storage_type      = "gp2"         # 범용 SSD
    engine            = "postgres" 
    engine_version    = "15.14"
    instance_class    = "db.t3.micro" # 프리티어(무료) 사양

    db_name           = "postgres"
    username          = "postgres"

    # ★★★ 중요 ★★★
    # 이 비밀번호는 코드에 직접 적지 않는 것이 좋습니다.
    # 여기서는 실습 편의상 적지만, 나중에는 변수로 빼야 합니다.
    password          = "mysecretpassword"

    db_subnet_group_name   = aws_db_subnet_group.main_db_subnet_group.name
    vpc_security_group_ids = [aws_security_group.rds_sg.id]

    skip_final_snapshot  = true # (실습용) 삭제 시 스냅샷 남기지 않음
}

# --- 3. (추가) RDS DB 엔드포인트 출력 ---
# ECS 앱(app.py)이 DB_HOST 환경 변수로 사용할 DB 주소
output "rds_endpoint" {
    description = "The endpoint of the RDS instance"
    value       = aws_db_instance.main_db.endpoint
}