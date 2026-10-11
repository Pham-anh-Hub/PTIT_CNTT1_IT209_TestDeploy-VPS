# Báo Cáo Bài 4: Thiết Lập Custom Network & Named Volume Bằng Docker CLI

## 1. Mục tiêu bài thực hành
Bài thực hành nhằm chứng minh và làm chủ hai cơ chế cốt lõi trong DevOps khi triển khai container bằng dòng lệnh thủ công:
1. **Custom Bridge Network (`app-net`):** Cơ chế mạng ảo tích hợp DNS nội bộ của Docker, cho phép các container tự động nhận diện và giao tiếp với nhau bằng tên (`db-server`) thay vì địa chỉ IP động.
2. **Named Volume (`db-data`) & Data Persistence:** Cơ chế tách biệt dữ liệu khỏi vòng đời của container, đảm bảo dữ liệu của cơ sở dữ liệu PostgreSQL không bị mất khi container bị xóa cứng hoặc khởi tạo lại.

---

## 2. Hướng dẫn thực hiện từng bước (Tường minh & Ngôn ngữ tự nhiên)

Bạn có thể chạy toàn bộ kịch bản tự động bằng script `commands.sh`:
```bash
cd homework/session_10/ex4
chmod +x commands.sh
./commands.sh
```

Hoặc thực hiện thủ công từng bước như sau:

### Bước 1: Tạo mạng ảo nội bộ (`Custom Bridge Network`)
```bash
docker network create app-net
```
- **Ý nghĩa:** Tạo ra một "cục Switch ảo" tên `app-net`. Các container cùng cắm vào mạng này sẽ nằm chung một vùng mạng kín và có thể tự gọi nhau bằng tên.

### Bước 2: Tạo phân vùng lưu trữ bền vững (`Named Volume`)
```bash
docker volume create db-data
```
- **Ý nghĩa:** Tạo một vùng lưu trữ độc lập trên ổ cứng máy chủ VPS tên `db-data`. Dữ liệu ghi vào đây sẽ tồn tại vĩnh viễn, không phụ thuộc vào vòng đời của bất kỳ container nào.

### Bước 3: Khởi chạy Database Container (`db-server`)
```bash
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=testdb \
  postgres:15-alpine
```
- **Ý nghĩa các tham số:**
  - `--name db-server`: Đặt tên container để Backend có thể gọi tới bằng tên này.
  - `--network app-net`: Cho container gia nhập mạng ảo nội bộ.
  - `-v db-data:/var/lib/postgresql/data`: Mount toàn bộ thư mục dữ liệu của PostgreSQL ra volume trên host.
  - Không dùng cờ `-p`: Cổng 5432 hoàn toàn được giấu kín khỏi Internet, chỉ mở trong nội bộ mạng `app-net`.

### Bước 4: Khởi chạy Backend Container (`app-container`)
```bash
docker run -d \
  --name app-container \
  --network app-net \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_NAME=testdb \
  -e DB_USER=postgres \
  -e DB_PASSWORD=postgres \
  alpine sh -c "while true; do sleep 3600; done"
```
- **Ý nghĩa:** Khởi chạy Backend container trong cùng mạng `app-net`, truyền hostname cơ sở dữ liệu là `db-server`.

---

## 3. Thực nghiệm Data Persistence (Kiểm chứng dữ liệu không bị mất)

### Bước 5.1: Ghi dữ liệu mẫu vào PostgreSQL
```bash
docker exec -i db-server psql -U postgres -d testdb -c "
CREATE TABLE users (id SERIAL PRIMARY KEY, name VARCHAR(50), email VARCHAR(50));
INSERT INTO users (name, email) VALUES ('Nguyen Van A', 'a@example.com'), ('Tran Van B', 'b@example.com');
"
```
Kiểm tra dữ liệu trước khi xóa:
```bash
docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"
```

### Bước 5.2: Xóa cứng Container Database
```bash
docker rm -f db-server
```
*(Lúc này container `db-server` đã bị xóa sổ hoàn toàn khỏi hệ thống).*

### Bước 5.3: Khởi chạy lại container DB mới và gắn lại Volume cũ
```bash
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=testdb \
  postgres:15-alpine
```

### Bước 5.4: Xác minh dữ liệu
```bash
sleep 5
docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"
```
👉 **Kết quả:** Bảng `users` cùng hai bản ghi (`Nguyen Van A`, `Tran Van B`) hiển thị đầy đủ nguyên vẹn 100%. Chứng minh cơ chế **Data Persistence** hoạt động thành công!

---

## 4. Barem các lệnh kiểm tra và nghiệm thu

### 1. Kiểm tra Network đã tạo
```bash
docker network ls | grep app-net
```
*Kết quả:* Thấy xuất hiện mạng `app-net` với driver `bridge`.

### 2. Kiểm tra Volume đã tạo
```bash
docker volume ls | grep db-data
```
*Kết quả:* Thấy xuất hiện volume `db-data` với driver `local`.

### 3. Kiểm tra các container tham gia mạng `app-net`
```bash
docker network inspect app-net
```
*Kết quả:* Trong mục `Containers` xuất hiện cả 2 thành viên `db-server` và `app-container` với địa chỉ IP nội bộ tương ứng.

### 4. Kiểm tra phân giải tên miền nội bộ (DNS Resolution)
```bash
docker exec -it app-container ping -c 2 db-server
```
*Kết quả:*
```text
PING db-server (172.18.0.2): 56 data bytes
64 bytes from 172.18.0.2: seq=0 ttl=64 time=0.082 ms
64 bytes from 172.18.0.2: seq=1 ttl=64 time=0.065 ms

--- db-server ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
```
👉 Lệnh ping từ `app-container` tự động phân giải `db-server` thành địa chỉ IP nội bộ `172.18.0.2` với `0% packet loss`.
