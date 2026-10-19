# ScamSaathi API. The rule pack is NOT baked in: mount the signed pack directory at /packs (see docker-compose.yml).
FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
RUN useradd --system --create-home --uid 10001 app
WORKDIR /app
COPY api/requirements.txt api/requirements.txt
RUN pip install -r api/requirements.txt
COPY api api
COPY packs/keys packs/keys
WORKDIR /app/api
RUN SCAMSAATHI_SECRET_KEY=build-only python manage.py collectstatic --noinput && mkdir /data && chown app /data
USER app
ENV SCAMSAATHI_DB=/data/db.sqlite3 SCAMSAATHI_PACKS_DIR=/packs
EXPOSE 8000
LABEL org.opencontainers.image.source="https://github.com/nikhilrai-tech/ScamSaathi" \
      org.opencontainers.image.description="ScamSaathi API: signed rule packs, hashed scam reports, organisations and alerts" \
      org.opencontainers.image.licenses="Apache-2.0"
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/healthz', timeout=3)"
CMD ["sh", "-c", "python manage.py migrate --noinput && exec gunicorn scamsaathi_api.wsgi:application --bind 0.0.0.0:8000 --workers 2 --access-logfile -"]
