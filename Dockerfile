FROM python:3-alpine

# Create app directory
WORKDIR /app

# Install app dependencies
COPY requirements.txt ./

RUN pip install -r requirements.txt
RUN apk --no-cache add curl

# Bundle app source
COPY . .

EXPOSE 8000
CMD [ "flask", "run","--host","0.0.0.0","--port","8000"]
