from flask import Flask
import time

app = Flask(__name__)

@app.route("/")
def home():
    ts = time.time()
    return str(ts)

if __name__ == "__main__":
    app.run(debug=True)
