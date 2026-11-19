# Imagem da API Refugio 360 (build em duas etapas). Opcional: o deploy oficial
# da GS e feito pela Release no Azure Web App (Java 21) com o .jar do CI.
#
# Build a partir da raiz do repositorio:
#   docker build -f dockerfiles/Dockerfile -t refugio360-api .
# Execucao local (H2):
#   docker run -p 8080:8080 refugio360-api
# Execucao com o Azure SQL (perfil cloud):
#   docker run -p 8080:8080 -e SPRING_PROFILES_ACTIVE=cloud -e DATABASE_URL=... \
#     -e DATABASE_USERNAME=... -e DATABASE_PASSWORD=... -e JWT_SECRET=... \
#     -e GESTOR_EMAIL=... -e GESTOR_PASSWORD=... refugio360-api

FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /workspace
COPY pom.xml ./
RUN mvn -B dependency:go-offline
COPY src ./src
RUN mvn -B -DskipTests package

FROM eclipse-temurin:21-jre
WORKDIR /app
# Usuario sem privilegios de root para executar a API.
RUN useradd --system --uid 10001 refugio
COPY --from=build /workspace/target/gs-final-java-0.0.1-SNAPSHOT.jar app.jar
USER refugio
EXPOSE 8080
ENTRYPOINT ["sh", "-c", "exec java -XX:MaxRAMPercentage=70.0 -Dserver.port=${PORT:-8080} -jar /app/app.jar"]
