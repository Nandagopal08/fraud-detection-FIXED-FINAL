FROM python:3.11-slim

RUN useradd -m -u 1000 appuser

WORKDIR /app

RUN apt-get update && apt-get install -y wget

COPY requirements.txt .

RUN pip install --no-cache-dir --timeout 300 --retries 5 \
    "numpy>=1.24,<2.0" \
    "pandas>=2.0,<3.0" \
    "scikit-learn>=1.3,<2.0" \
    "flask==2.3.3" \
    "werkzeug==2.3.7" \
    prometheus_client \
    joblib

COPY . .

RUN mkdir -p data && \
    wget -O data/creditcard.csv https://storage.googleapis.com/download.tensorflow.org/data/creditcard.csv

RUN mkdir -p models && python train_model.py

RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
 CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" || exit 1

CMD ["python", "app/app.py"]