# --- 1. ECR (Elastic Container Registry) 리포지토리
# Phase 1의 Docker 이미지를 저장할 '창고'입니다.
resource "aws_ecr_repository" "api_repo" {
    name = "level3-todo-api" # ECR에 표시될 창고 이름

    tags = { Name = "level3-api-repo" }
}

# --- 2. (추가) ECR 리포지토리 URL 출력 ---
output "ecr_repository_url" {
    description = "The URL of the ECR repository"
    value       = aws_ecr_repository.api_repo.repository_url
}