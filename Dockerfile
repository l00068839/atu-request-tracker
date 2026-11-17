# Refresh the base image and dependencies regularly, then rescan.
FROM python:3.12-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir=/wheels -r requirements.txt

FROM python:3.12-slim AS runtime
RUN apt-get update \
    && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 DATABASE=/data/requests.db
RUN groupadd --gid 10001 tracker && useradd --uid 10001 --gid tracker --no-create-home tracker \
    && mkdir /data && chown tracker:tracker /data

WORKDIR /srv
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir --no-index --find-links=/wheels /wheels/*.whl && rm -rf /wheels
COPY --chown=tracker:tracker app ./app

USER 10001:10001
EXPOSE 8000

# One worker keeps in-process Prometheus metrics coherent for this single-replica demo.
CMD ["gunicorn", "--bind=0.0.0.0:8000", "--workers=1", "--threads=4", "--access-logfile=-", "--error-logfile=-", "app:create_app()"]