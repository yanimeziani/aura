FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

ENV CERBERUS_BASE_DIR=/data/cerberus
ENV PEGASUS_ADMIN_USERNAME=yani
ENV PEGASUS_ADMIN_PASSWORD=cerberus2026
EXPOSE 8000

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
