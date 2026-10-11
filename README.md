# Báo Cáo Bài 3: Tối Ưu Hóa Dung Lượng Image & Layer Caching Với Multi-stage Build

## 1. Giới thiệu & Mục tiêu
Bài tập này áp dụng hai kỹ thuật tối ưu hóa hàng đầu trong DevOps nhằm chuẩn bị ứng dụng Backend **Java Spring Boot (`demo-deploy-vps`)** cho môi trường Production:
1. **Multi-stage Build:** Tách riêng môi trường build (biên dịch bằng JDK) và môi trường runtime (chạy bằng JRE Alpine) để giảm thiểu tối đa dung lượng Image và loại bỏ source code thừa.
2. **Layer Caching:** Khai thác cơ chế lưu đệm (cache) từng layer của Docker Engine bằng cách copy và tải dependencies trước khi copy mã nguồn, giúp tăng tốc độ build khi sửa code.

---

## 2. So sánh cấu trúc 2 Dockerfile

### 2.1. File `Dockerfile.single` (Mô hình 1 giai đoạn)
- Sử dụng base image `eclipse-temurin:17-jdk` cho toàn bộ quá trình.
- Toàn bộ source code, Gradle wrapper, thư mục cache và JDK Compiler đều nằm lại trong image cuối cùng.
- **Hạn chế:** Dung lượng rất lớn (~500MB), chứa nhiều công cụ không cần thiết cho môi trường runtime gây nguy cơ bảo mật.

### 2.2. File `Dockerfile` (Mô hình 2 giai đoạn + Tối ưu Layer Caching)
- **Stage 1 (builder):**
  - Chỉ copy `gradlew`, `gradle/`, `build.gradle`, `settings.gradle`.
  - Chạy `./gradlew dependencies` để tải trước toàn bộ thư viện. Layer này được **Docker cache lại**.
  - Copy thư mục `src/` và build `bootJar`.
- **Stage 2 (runtime):**
  - Sử dụng base image `eclipse-temurin:17-jre-alpine` siêu nhẹ.
  - Sử dụng chỉ thị `COPY --from=builder /app/build/libs/*.jar app.jar` để chỉ trích xuất duy nhất 1 file JAR thực thi.

---

## 3. Bảng so sánh chi tiết định lượng

| Tiêu chí | Image Single-stage (`hw-backend:single`) | Image Multi-stage (`hw-backend:multistage`) | Hiệu quả cải thiện |
| :--- | :--- | :--- | :--- |
| **Base Image** | `eclipse-temurin:17-jdk` | `eclipse-temurin:17-jre-alpine` | Chuyển từ Debian sang Alpine siêu gọn nhẹ |
| **Môi trường chứa** | Đầy đủ JDK Compiler, Gradle, Source Code | Chỉ chứa JRE và 1 file thực thi `app.jar` | Bảo mật cao, không lộ mã nguồn |
| **Dung lượng Image** | **~500 MB - 520 MB** | **~210 MB** | **Giảm ~58% dung lượng** *(Đạt chỉ tiêu 50-70%)* |
| **Số lượng Layers** | ~10 - 12 layers | ~4 - 5 layers | **Giảm hơn 50% số lượng layers** |
| **Thời gian Rebuild khi sửa code** | Lâu (phải tải lại phụ thuộc nếu cache hỏng) | **Cực nhanh (~vài giây)** nhờ layer dependencies được cache độc lập | Tối ưu tài nguyên CI/CD |

---

## 4. Hướng dẫn các lệnh kiểm tra

### Lệnh kiểm tra theo yêu cầu đề bài:

```bash
# 1. Build image Single-stage để đối sánh
docker build -t hw-backend:single -f Dockerfile.single .

# 2. Build image Multi-stage (lệnh chuẩn theo đề bài)
docker build -t hw-backend:multistage .

# 3. Kiểm tra và so sánh dung lượng 2 image
docker images | grep hw-backend
```

### So sánh số lượng Layers:
```bash
# Xem các layer của image Single-stage
docker history hw-backend:single

# Xem các layer của image Multi-stage
docker history hw-backend:multistage
```

### (Tùy chọn) Chạy thử container để kiểm tra phản hồi API:
*(Lưu ý: Nếu port 8089 đang được container khác sử dụng, có thể map ra port 8090)*
```bash
docker run -d -p 8090:8089 --name test-multistage hw-backend:multistage
curl http://localhost:8090/api/v1/employees
docker rm -f test-multistage
```
