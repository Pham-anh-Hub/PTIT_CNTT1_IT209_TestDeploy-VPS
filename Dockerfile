# Giai đoạn 1: Build file JAR từ mã nguồn
FROM eclipse-temurin:17-jdk AS builder
WORKDIR /app
COPY . .
RUN chmod +x ./gradlew && ./gradlew clean bootJar -x test --no-daemon

# Giai đoạn 2: Chạy ứng dụng
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=builder /app/build/libs/*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar", "--server.port=8089"]