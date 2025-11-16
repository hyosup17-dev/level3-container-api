import os
import time
from flask import Flask, request, jsonify
import psycopg2

app = Flask(__name__)

# --- 1. 환경 변수 ---
DB_HOST = os.environ.get('DB_HOST')
DB_PORT = os.environ.get('DB_PORT', 5432)
DB_NAME = os.environ.get('DB_NAME')
DB_USER = os.environ.get('DB_USER')
DB_PASS = os.environ.get('DB_PASSWORD')

# --- 2. DB 연결 함수 ---
def get_db_connection():
    """DB에 연결합니다. (앱이 DB보다 먼저 뜰 수 있으므로, 연결 재시도 로직 포함)"""
    retry_count = 5
    for i in range (retry_count):
        try:
            conn = psycopg2.connect(
                host = DB_HOST,
                port = DB_PORT,
                dbname = DB_NAME,
                user = DB_USER,
                password = DB_PASS
            )
            print(f"--- get_db_connection SUCCESS on attempt {i+1} ---")
            return conn
        except psycopg2.OperationalError as e:
            print(f"--- get_db_connection FAILED on attempt {i+1}: {e}")
            time.sleep(3) # 3초 대기 후 재시도
            
    # 최종 실패 시 앱 종료
    raise Exception("데이터 베이스에 연결할 수 없습니다. (환경 변수 확인!)")

# --- 3. (수정 코드) DB 테이블 초기화 ---
def init_db():
    """앱 시작 시 'todos' 테이블이 없으면 생성합니다. (강화된 재시도 로직)"""
    retry_count = 10 # 재시도 횟수를 10번으로 늘립니다.
    conn = None
    cur = None
    
    for i in range(retry_count):
        try:
            # 1. DB 연결 시도 (이 함수는 이미 재시도 로직이 있습니다)
            conn = get_db_connection()
            cur = conn.cursor()
            
            # 2. 테이블 생성 시도
            cur.execute("""
                CREATE TABLE IF NOT EXISTS todos (
                    id SERIAL PRIMARY KEY,
                    task TEXT NOT NULL,
                    completed BOOLEAN DEFAULT FALSE
                );
            """)
            
            # 3. 성공 시
            conn.commit()
            cur.close()
            conn.close()
            # ★★★ 성공 메시지를 더 명확하게 변경
            print("===============================================")
            print("Database table 'todos' initialized. SUCCESS.")
            print("===============================================")
            return # ★★★ 성공했으므로 함수를 종료합니다 ★★★
            
        except psycopg2.Error as e:
            # DB가 아직 준비 중일 때 (예: 'database "postgres" is being created')
            print(f"--- init_db FAILED on attempt {i+1}: {e}")
            # 리소스 정리
            if conn:
                conn.rollback() # 오류 발생 시 롤백
            if cur:
                cur.close()
            if conn:
                conn.close()
            time.sleep(3) # 3초 대기 후 재시도
    
    # 10번 재시도 후에도 실패하면
    print("CRITICAL: init_db failed after all retries. Exiting.")
    raise Exception("Failed to initialize database table.")

# --- 4. API 엔드포인트 ---
@app.route('/todos', methods=['GET'])
def get_todos():
    """모든 To-Do 항목을 조회합니다."""
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT id, task, completed FROM todos ORDER BY id DESC;")
    todos = cur.fetchall()
    cur.close()
    conn.close()
    
    result = [dict(zip(('id', 'task', 'completed'), row)) for row in todos]
    return jsonify({"message": "CI/CD Success!"})

@app.route('/todos', methods=['POST'])
def add_todo():
    """새 To-Do 항목을 추가합니다."""
    data = request.get_json()
    if not data or 'task' not in data:
        return jsonify({'error': 'Task is required'}), 400

    task = data['task']
    
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("INSERT INTO todos (task) VALUES (%s) RETURNING id;", (task,))
    new_id = cur.fetchone()[0]
    conn.commit()
    cur.close()
    conn.close()
    
    return jsonify({'id': new_id, 'task': task, 'completed': False}), 201

# --- 5. 앱 실행 ---
if __name__ == '__main__':
    # 앱이 시작되기 전에 DB 테이블을 확인/생성합니다.
    init_db()
    # 0.0.0.0: Docker 컨테이너 내부에서 외부의 요청을 받을 수 있게 합니다.
    print("--- Starting Flask Server (app.run) ---")
    app.run(host='0.0.0.0', port=5000)