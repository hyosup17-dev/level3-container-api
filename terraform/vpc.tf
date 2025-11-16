# --- 1. VPC (우리만의 가상 네트워크) ---
resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16" # VPC가 사용할 전체 IP 대역

    tags = {
        Name = "level3-vpc"
    }
}

# --- 2. Public Subnet 2개 (가용 구역 a, c) ---
# 인터넷 게이트웨이(IGW)와 연결되어 외부 인터넷과 통신이 가능합니다.
resource "aws_subnet" "public_a" {
    vpc_id                  = aws_vpc.main.id
    cidr_block              = "10.0.1.0/24"
    availability_zone       = "ap-northeast-2a" # 서울 a존
    map_public_ip_on_launch = true # 이 서브넷에 자원을 만들면 공용 IP 자동 할당

    tags = { Name = "level3-public-a" }
}

resource "aws_subnet" "public_c" {
    vpc_id                  = aws_vpc.main.id
    cidr_block              = "10.0.2.0/24"
    availability_zone       = "ap-northeast-2c" # 서울 c존
    map_public_ip_on_launch = true # 이 서브넷에 자원을 만들면 공용 IP 자동 할당

    tags = { Name = "level3-public-c" }
}

# --- 3. Private Subnet 2개 (가용 구역 a, c) ---
# 인터넷과 직접 연결되지 않아 DB와 앱을 보호합니다.
resource "aws_subnet" "private_a" {
    vpc_id            = aws_vpc.main.id
    cidr_block        = "10.0.10.0/24"
    availability_zone = "ap-northeast-2a"

    tags = { Name = "level3-private-a" }
}

resource "aws_subnet" "private_c" {
    vpc_id            = aws_vpc.main.id
    cidr_block        = "10.0.11.0/24"
    availability_zone = "ap-northeast-2c"

    tags = { Name = "level3-private-c" }
}

# --- 4. 인터넷 게이트웨이 (VPC의 '대문') ---
resource "aws_internet_gateway" "main_igw" {
    vpc_id = aws_vpc.main.id
    tags = { Name = "level3-igw" }
}

# --- 5. EIP (NAT 게이트웨이용 고정 IP) ---
# NAT 게이트웨이는 고정된 공인 IP가 필요합니다.
resource "aws_eip" "nat_eip" {
    domain = "vpc"
    tags = { Name = "level3-nat-eip" }
}

# --- 6. NAT 게이트웨이 (Private Subnet의 '출구 전용' 문) ---
# Private Subnet이 외부(예: 업데이트)로 나갈 때 사용합니다. (외부에서 들어오진 못함)
# NAT 게이트웨이 자체는 반드시 Public Subnet에 위치해야 합니다.
resource "aws_nat_gateway" "main_nat" {
    allocation_id = aws_eip.nat_eip.id
    subnet_id     = aws_subnet.public_a.id # Public Subnet 'a'에 배치

    tags       = { Name = "level3-nat" }
    depends_on = [aws_internet_gateway.main_igw]
}

# --- 7. 라우팅 테이블 (교통 규칙) ---
# Public 라우팅: 인터넷(0.0.0.0/0)으로 가는 트래픽은 '대문'(IGW)으로 보냄
resource "aws_route_table" "public_rt" {
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.main_igw.id
    }
    tags = { Name = "level3-public-rt" }
}

# Private 라우팅: 인터넷(0.0.0.0/0)으로 가는 트래픽은 'NAT'(출구)로 보냄
resource "aws_route_table" "private_rt" {
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.main_nat.id
    }
    tags = { Name = "level3-private-rt" }
}

# --- 8. 라우팅 테이블 '연결' ---
# Public 서브넷 2개를 'Public 규칙'과 연결
resource "aws_route_table_association" "public_a_assoc" {
    subnet_id      = aws_subnet.public_a.id
    route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_c_assoc" {
    subnet_id      = aws_subnet.public_c.id
    route_table_id = aws_route_table.public_rt.id
}

# Private 서브넷 2개를 'Private 규칙'과 연결
resource "aws_route_table_association" "private_a_assoc" {
    subnet_id      = aws_subnet.private_a.id
    route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_c_assoc" {
    subnet_id      = aws_subnet.private_c.id
    route_table_id = aws_route_table.private_rt.id
}