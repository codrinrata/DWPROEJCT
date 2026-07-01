FROM python:3.12-slim-bookworm

WORKDIR /app

# Java for Apache Spark / PySpark
# Symlink avoids hard-coding amd64 vs arm64 paths
RUN apt-get update -o Acquire::Retries=3 \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        openjdk-17-jre-headless \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sfn /usr/lib/jvm/java-17-openjdk-$(dpkg --print-architecture) /usr/lib/jvm/java-17

ENV JAVA_HOME=/usr/lib/jvm/java-17
ENV PATH="${JAVA_HOME}/bin:${PATH}"
ENV SPARK_MASTER=local[1]
ENV SPARK_DRIVER_MEMORY=512m

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
