FROM python:3.12-slim

WORKDIR /app

# curl is needed for the HEALTHCHECK below; not included in slim by default
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ .

RUN useradd -m appuser
USER appuser

EXPOSE 8501

# BACKEND_URL is injected at deploy time (task definition / launch template)
# so this same image works against dev, or any future environment,
# without rebuilding.
ENV BACKEND_URL=http://localhost:5000

HEALTHCHECK CMD curl --fail http://localhost:8501/_stcore/health || exit 1

CMD ["streamlit", "run", "streamlit_app.py", "--server.port=8501", "--server.address=0.0.0.0"]
