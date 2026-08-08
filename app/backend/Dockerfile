# Small, fast-building base image
FROM python:3.12-slim

WORKDIR /app

# Install dependencies first so Docker can cache this layer
# and only reinstall when requirements.txt actually changes
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ .

# Non-root user for basic container hardening
RUN useradd -m appuser
USER appuser

EXPOSE 5000

ENV PORT=5000

# gunicorn is production-grade, unlike Flask's built-in dev server
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
