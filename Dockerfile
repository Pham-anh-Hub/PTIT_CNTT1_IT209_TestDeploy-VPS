# ==============================================================================
# GIAI ĐOẠN 1 (BUILDER): Biên dịch mã nguồn và đóng gói file JAR
# ==============================================================================
# 1. Sử dụng image JDK 17 đầy đủ của Eclipse Temurin làm môi trường build.
#    Đặt tên giai đoạn này là "builder" (Multi-stage build).
FROM eclipse-temurin:17-jdk AS builder

# 2. Thiết lập thư mục làm việc mặc định trong container là /app.
WORKDIR /app

# 3. Sao chép toàn bộ mã nguồn, cấu hình và wrapper từ máy host vào thư mục /app của container.
COPY . .

# 4. Cấp quyền thực thi cho Gradle wrapper (tránh lỗi permission denied trên Linux),
#    sau đó chạy lệnh đóng gói ứng dụng Spring Boot ra file JAR (bootJar).
#    - "-x test": Bỏ qua chạy unit test lúc build để tránh fail do chưa có database kết nối.
#    - "--no-daemon": Tắt tiến trình ngầm của Gradle sau khi build xong nhằm tiết kiệm RAM container.
RUN chmod +x ./gradlew && ./gradlew clean bootJar -x test --no-daemon

# ==============================================================================
# GIAI ĐOẠN 2 (RUNTIME): Môi trường chạy ứng dụng thực tế
# ==============================================================================
# 5. Sử dụng base image JRE 17 Alpine siêu gọn nhẹ (chỉ chứa môi trường chạy, không có compiler)
#    giúp tối ưu dung lượng image cuối cùng và tăng tính bảo mật.
FROM eclipse-temurin:17-jre-alpine

# 6. Thiết lập thư mục làm việc cho ứng dụng khi chạy là /app.
WORKDIR /app

# 7. Chỉ sao chép duy nhất file JAR đã build xong từ giai đoạn "builder" sang giai đoạn này,
#    đổi tên thành "app.jar" và bỏ qua toàn bộ source code, thư mục rác để giảm dung lượng.
COPY --from=builder /app/build/libs/*.jar app.jar

# 8. Lệnh mặc định sẽ được thực thi khi container khởi động:
#    Khởi chạy ứng dụng Java với cổng được cấu hình cố định là 8089.
ENTRYPOINT ["java", "-jar", "app.jar", "--server.port=8089"]