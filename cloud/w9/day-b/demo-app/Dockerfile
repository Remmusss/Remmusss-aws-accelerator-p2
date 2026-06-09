FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

ENV APP_NAME=demo-web
ENV APP_VERSION=v1

EXPOSE 8000

CMD ["python", "app.py"]
