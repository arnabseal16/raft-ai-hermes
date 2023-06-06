FROM python:3-alpine

# Create app directory
WORKDIR /app

# Install app dependencies
COPY requirements.txt ./

RUN pip install -r requirements.txt
RUN apk --no-cache add curl
RUN opentelemetry-bootstrap --action=install

# Bundle app source
COPY . .

EXPOSE 8000
CMD ["opentelemetry-instrument", "--service_name", "raft-ai-hermes", "--exporter_otlp_endpoint", "0.0.0.0:4318", "--metrics_exporter", "console", "--exporter_otlp_protocol", "http/protobuf", "flask", "run","--host","0.0.0.0","--port","8000"]
