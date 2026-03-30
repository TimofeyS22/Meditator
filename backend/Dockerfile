FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/code

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        adduser \
    && rm -rf /var/lib/apt/lists/* \
    && adduser --system --group --home /home/appuser appuser

WORKDIR /code

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

COPY alembic.ini .
COPY alembic/ alembic/
COPY app/ app/
COPY entrypoint.sh .

RUN mkdir -p /code/assets/audio \
    && chmod +x entrypoint.sh \
    && chown -R appuser:appuser /code

USER appuser

EXPOSE 8080

ENTRYPOINT ["./entrypoint.sh"]
