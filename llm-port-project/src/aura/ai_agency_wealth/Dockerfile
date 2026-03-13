FROM python:3.11-slim
WORKDIR /app

RUN apt-get update && apt-get install -y build-essential curl

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt fpdf qrcode reportlab pillow duckduckgo-search python-dotenv crewai==0.22.5

COPY . .
CMD ["bash", "automation_master_docker.sh"]