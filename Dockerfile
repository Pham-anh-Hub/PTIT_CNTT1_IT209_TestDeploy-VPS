# --- GIAI ĐOẠN 1: Build file JAR ---
FROM maven:3.8.4-openjdk-17 AS builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
# Build ra file jar
RUN mvn clean package -DskipTests

# --- GIAI ĐOẠN 2: Chạy ứng dụng ---
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
# Sao chép file jar đã build từ giai đoạn 1 sang
COPY --from=builder /app/target/*.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]