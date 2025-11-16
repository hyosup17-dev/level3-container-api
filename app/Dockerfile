# 1. 베이스 이미지 (Python 3.10 슬림 버전)
FROM python:3.10-slim

# 2. 컨테이너 안의 작업 폴더 설정
WORKDIR /app

# 3. 라이브러리 설치 (코드를 복사하기 전에!)
# (requirements.txt만 먼저 복사해서 설치하면, 코드만 바뀔 땐 이 단계가 캐시되어 빌드 속도가 빨라집니다)
COPY requirements.txt .
RUN pip install -r requirements.txt

# 4. 앱 코드 전체 복사
COPY . .

# 5. 컨테이너가 시작될 때 실행할 명령
# (python app.py)
CMD ["python", "app.py"]