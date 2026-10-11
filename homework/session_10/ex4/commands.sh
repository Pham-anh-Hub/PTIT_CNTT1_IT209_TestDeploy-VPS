#!/bin/bash
# ==============================================================================
# BÀI 4: THIẾT LẬP CUSTOM NETWORK & NAMED VOLUME BẰNG DOCKER CLI
# ==============================================================================

set -e

echo "=== BƯỚC 1: DỌN DẸP CONTAINER CŨ (NẾU CÓ) ==="
docker rm -f db-server app-container 2>/dev/null || true
docker network rm app-net 2>/dev/null || true
docker volume rm db-data 2>/dev/null || true

echo "=== BƯỚC 2: TẠO CUSTOM BRIDGE NETWORK (app-net) ==="
# Mạng ảo riêng biệt có sẵn DNS nội bộ để container tìm nhau qua tên
docker network create app-net

echo "=== BƯỚC 3: TẠO NAMED VOLUME (db-data) ==="
# Volume độc lập trên máy chủ host giúp lưu trữ dữ liệu bền vững
docker volume create db-data

echo "=== BƯỚC 4: KHỞI CHẠY DATABASE CONTAINER (db-server) ==="
# Khởi chạy PostgreSQL gắn vào mạng app-net và mount volume db-data
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=testdb \
  postgres:15-alpine

echo "Đợi 5 giây để PostgreSQL hoàn tất khởi động..."
sleep 5

echo "=== BƯỚC 5: KHỞI CHẠY BACKEND CONTAINER (app-container) ==="
# Khởi chạy Backend container tham gia app-net, truyền biến kết nối trỏ tới db-server
docker run -d \
  --name app-container \
  --network app-net \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_NAME=testdb \
  -e DB_USER=postgres \
  -e DB_PASSWORD=postgres \
  alpine sh -c "while true; do sleep 3600; done"

echo "=== BƯỚC 6: KIỂM TRA DATA PERSISTENCE (BẢO TOÀN DỮ LIỆU) ==="
echo "1. Thêm dữ liệu mẫu vào bảng users trong PostgreSQL:"
docker exec -i db-server psql -U postgres -d testdb -c "
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50),
    email VARCHAR(50)
);
INSERT INTO users (name, email) VALUES 
('Nguyen Van A', 'a@example.com'),
('Tran Van B', 'b@example.com');
"

echo "Dữ liệu hiện tại trong database:"
docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"

echo "---------------------------------------------------------"
echo "2. XÓA CỨNG CONTAINER DB (docker rm -f db-server)..."
docker rm -f db-server

echo "---------------------------------------------------------"
echo "3. KHỞI CHẠY CONTAINER DB MỚI VÀ GẮN LẠI VOLUME db-data..."
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=testdb \
  postgres:15-alpine

echo "Đợi 5 giây để PostgreSQL khởi động lại..."
sleep 5

echo "---------------------------------------------------------"
echo "4. XÁC MINH DỮ LIỆU SAU KHI TÁI TẠO CONTAINER DB:"
docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"

echo "=== BƯỚC 7: THỰC HIỆN CÁC LỆNH KIỂM TRA THEO ĐỀ BÀI ==="
echo "[Lệnh 1] Kiểm tra Network app-net:"
docker network ls | grep app-net

echo "[Lệnh 2] Kiểm tra Volume db-data:"
docker volume ls | grep db-data

echo "[Lệnh 3] Kiểm tra thông tin Network app-net:"
docker network inspect app-net

echo "[Lệnh 4] Test DNS Resolution từ app-container ping sang db-server:"
docker exec -it app-container ping -c 2 db-server

echo "=== HOÀN TẤT BÀI 4 THÀNH CÔNG ==="
