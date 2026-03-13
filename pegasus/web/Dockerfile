FROM gradle:8.11.1-jdk17 AS build
WORKDIR /workspace
COPY . .
RUN gradle :web:installDist --no-daemon

FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /workspace/web/build/install/web /app
ENV PEGASUS_WEB_HOST=0.0.0.0
ENV PEGASUS_WEB_PORT=8080
EXPOSE 8080
CMD ["/app/bin/web"]
