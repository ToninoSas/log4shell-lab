# ============================================================
# Stage 1: Compila marshalsec da sorgente con Maven + Java 8
# Il pre-built JAR su GitHub (v0.0.3) NON esiste come release,
# quindi il wget originale falliva silenziosamente.
# ============================================================
FROM amazoncorretto:8 AS builder

RUN yum install -y git tar wget

# Installa Maven manualmente
RUN wget -q https://archive.apache.org/dist/maven/maven-3/3.8.8/binaries/apache-maven-3.8.8-bin.tar.gz \
    && tar xzf apache-maven-3.8.8-bin.tar.gz -C /opt \
    && ln -s /opt/apache-maven-3.8.8/bin/mvn /usr/bin/mvn \
    && rm apache-maven-3.8.8-bin.tar.gz

RUN git clone https://github.com/mbechler/marshalsec.git /marshalsec

WORKDIR /marshalsec
RUN mvn package -DskipTests -q

# ============================================================
# Stage 2: Runtime — amazoncorretto:8 (openjdk:8-jre-slim è deprecata)
# ============================================================
FROM amazoncorretto:8

COPY --from=builder /marshalsec/target/marshalsec-0.0.3-SNAPSHOT-all.jar /app/marshalsec.jar

WORKDIR /app

EXPOSE 1389
