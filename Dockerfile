FROM python:3.12-alpine AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir=/wheels -r requirements.txt

FROM python:3.12-alpine AS runtime
RUN apk upgrade --no-cache

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DATABASE=/data/requests.db

RUN addgroup -g 10001 tracker \
    && adduser -D -H -u 10001 -G tracker tracker \
    && mkdir /data \
    && chown tracker:tracker /data

WORKDIR /srv
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir --no-index --find-links=/wheels /wheels/*.whl \
    && rm -rf /wheels
COPY --chown=tracker:tracker app ./app

USER 10001:10001
EXPOSE 8000

# One worker keeps the demo's in-process metrics consistent.
CMD ["gunicorn", "--bind=0.0.0.0:8000", "--workers=1", "--threads=4", "--access-logfile=-", "--error-logfile=-", "app:create_app()"]