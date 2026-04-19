FROM python:3.11-slim

# Create non-root user for security
RUN useradd -m -u 1000 appuser

WORKDIR /app

# Install dependencies first (layer caching)
COPY requirements.txt .

RUN pip install --no-cache-dir --timeout 300 --retries 5 "numpy>=1.24,<2.0"
RUN pip install --no-cache-dir --timeout 300 --retries 5 "pandas>=2.0,<3.0"
RUN pip install --no-cache-dir --timeout 300 --retries 5 "scikit-learn>=1.3,<2.0"
RUN pip install --no-cache-dir --timeout 300 --retries 5 \
        "flask==2.3.3" \
        "werkzeug==2.3.7" \
        prometheus_client \
        joblib

# Copy all project files
COPY . .

# Create models + data dirs and train model at build time
# (mirrors Jenkins: Build -> ML container trains on startup)
RUN mkdir -p models data && python train_model.py

# Change ownership to non-root user
RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" || exit 1

CMD ["python", "app/app.py"]
