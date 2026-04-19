FROM python:3.11-slim

# Create non-root user for security

RUN useradd -m -u 1000 appuser

WORKDIR /app

# Install system dependencies

RUN apt-get update && apt-get install -y wget

# Copy requirements (for caching)

COPY requirements.txt .

# Install Python dependencies

RUN pip install --no-cache-dir --timeout 300 --retries 5 "numpy>=1.24,<2.0"
RUN pip install --no-cache-dir --timeout 300 --retries 5 "pandas>=2.0,<3.0"
RUN pip install --no-cache-dir --timeout 300 --retries 5 "scikit-learn>=1.3,<2.0"

RUN pip install --no-cache-dir --timeout 300 --retries 5 \
    "numpy>=1.24,<2.0" \
    "pandas>=2.0,<3.0" \
    "scikit-learn>=1.3,<2.0" \
    flask==2.3.3 \
    werkzeug==2.3.7 \
    prometheus_client \
    joblib
# Copy all project files

COPY . .

# Download dataset inside container

RUN mkdir -p data && 
wget -O data/creditcard.csv 
https://storage.googleapis.com/download.tensorflow.org/data/creditcard.csv

# Train model during build

RUN mkdir -p models && python train_model.py

# Change ownership to non-root user

RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 5000

# Healthcheck

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 
CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" || exit 1

# Start app

CMD ["python", "app/app.py"]
