# Giai đoạn 1: Build file JAR từ mã nguồn
FROM maven:3.8.4-openjdk-17 AS builder
WORKDIR /app
COPY . .
RUN ./gradlew clean bootJar --no-daemon

# Giai đoạn 2: Chạy ứng dụng
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=builder /app/build/libs/*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar", "--server.port=8089"]