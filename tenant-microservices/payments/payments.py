from flask import Flask
from flask import request
import os

app = Flask(__name__)

environment = os.environ.get("ENVIRONMENT")
service_name = "payments"
ms_version = "1.0.0"

@app.route("/payments")
def index():        
    tenant_id = request.headers.get('tenantID')
    return { 
        "tenant_id": tenant_id, 
        "environment": environment, 
        "version": ms_version, 
        "microservice": service_name,            
    }    

@app.route("/payments/readiness-probe", methods = ['GET'])
def probe():
    return { "Status": "OK" }

if __name__ == "__main__":
    # run in 0.0.0.0 so that it can be accessed from outside the container
    app.run(host="0.0.0.0", port=80)