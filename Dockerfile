FROM python:3.11-slim

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Create non-root user
RUN useradd -m -u 1000 appuser

WORKDIR /app

# Install system deps
RUN apt-get update && apt-get install -y wget && rm -rf /var/lib/apt/lists/*

# -------------------------
# 1. INSTALL DEPENDENCIES (CACHED)
# -------------------------
COPY requirements.txt .

RUN pip install --no-cache-dir --timeout 300 --retries 5 -r requirements.txt

# -------------------------
# 2. COPY CREDITCARD DATA (FROM LOCAL)
# -------------------------
# ✅ FIXED: Copy from local file instead of downloading
COPY creditcard.csv /app/data/creditcard.csv

# -------------------------
# 3. COPY CODE (ONLY THIS CHANGES)
# -------------------------
COPY . .

# -------------------------
# 4. TRAIN MODEL (ONLY RUNS IF CODE CHANGES)
# -------------------------
RUN mkdir -p models && python train_model.py

# Permissions
RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 5000

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" || exit 1

# Start app
CMD ["python", "app/app.py"]