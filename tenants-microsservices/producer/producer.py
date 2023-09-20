from flask import Flask
from flask import jsonify
from flask import request
import os

app = Flask(__name__)

@app.route("/producer")
def index():
    environment = os.environ.get("TENANT_ID")
    microsservice_version = "1.0.0"
    tenant_id = request.headers.get('tenantID')

    message = {"tenant_id": tenant_id, "environment": environment, "microsservice_version": microsservice_version, "microserice": "producer"}
    return jsonify(message)


if __name__ == "__main__":
    # run in 0.0.0.0 so that it can be accessed from outside the container
    app.run(host="0.0.0.0", port=80)