# Bootstrapping a simple Flask App with K8s

This flask app is **helmified** and along with a certain set of other resources provides a good POC for implementing more complex structures with proper observability and scaling.


### Breakdown the directory structure first:

```
├── Dockerfile
├── app.py
├── helm-charts
│   ├── Chart.yaml
│   ├── templates
│   │   ├── deployment.yaml
│   │   ├── hpa.yml
│   │   ├── ingress.yaml
│   │   └── service.yaml
│   └── values.yaml
├── k8s-manifests
│   ├── deployment.yaml
│   ├── ingress.yaml
│   ├── namespace.yaml
│   └── service.yaml
├── keda.yaml
├── locust
│   └── locustfile.py
└── requirements.txt
```

1. **Dockerfile**: Contains the main docker file built out of alpine in an effort to keep it as slim as possible
2. **requirements.txt**: Contains the bare minimum necessities to make this application work
3. **keda.yml**: Keda is used to aid in Auto-Scaling of the application based on http-requests (using the http-scaler)
4. **k8s-manifests**: The basic deployment manifests of the app which was later helmified
5. **helm-charts**: The helm charts which can effortlessly deploy this anywhere on top of K8s/K3s/minikube
6. **locust**: A simple python tool to emulate network traffic and load. Useful for stress-testing network based workloads (like here)


### Cruicial Parts of the Dockerfile:

```
RUN opentelemetry-bootstrap --action=install
CMD ["opentelemetry-instrument", "--service_name", "raft-ai-hermes", "--exporter_otlp_endpoint", "0.0.0.0:4318", "--metrics_exporter", "console", "--exporter_otlp_protocol", "http/protobuf",...
```

This steps apart from the standard ones, bootsrapps the application for OpenTelemetry, a standardised and opensource set of observability framework which can be used for any APMs like Jaeger or here with Signoz (More on that later)

### Infrastructure Breakdown:

The main moving components are as follows:

1. **Metrics Server** - A Cluster Wide aggregator of resources, which siphones metrics from the kubelet of each node and provides it to the k8s Metrics API
2. **Deployment** - A Deployment which handles the pods running our bootstrapped Docker Image of the flask app
3. **Service** - A LoadBalancer Service here is used to handle the replicas of the Deployment running
4. **Ingress** -  A very basic and default nginx k8s ingress used to handle the requests to our Deployment, levaraing the service
5. **HPA** - Helps in Scaling our Pods Replicas Based on Metrics from the Metrics Server (here CPU and Memory since Im not using Prom Adapter)
6. **Keda** - A combination of Resources and CRDs which is used to scale our Deployment based on the number of pending HTTP Requests (utilising the HTTP Scaler)
7. **Signoz** - A Full Stack Opensource Observability tool and APM which uses OTEL to provide SPANs/Metrics/Logs/Traces and much more


## Stitching it all together:

### Steps for bootstrapping:

1. `helm upgrade --install --create-namespace --install metrics-server metrics-server/metrics-server -n raft-ai-hermes --set args="{--kubelet-insecure-tls}"`
   
    This adds metric server into our cluster, the args `--kubelet-insecure-tls` is important since this is just a POC and we're not using sgined tls for this exercise
   
2. `helm upgrade --install raft-ai-hermes -n raft-ai-hermes helm-charts`
    This adds our application and the core resources required for it's funtioing. 
    
3. `helm upgrade --install keda kedacore/keda --namespace raft-ai-hermes` <br />
   `helm upgrade --install http-add-on kedacore/keda-add-ons-http --namespace raft-ai-hermes` <br />
   `kubectl apply -f keda.yml --namespace raft-ai-hermes` <br /><br />
   This does a few things, mainly, it install keda-core components using the official helm chart for keda, then it installs the http addon CRD. And lasty it installs **HTTPScaledObject** which links with oiut deployment and scales based on the pending requests

4. `helm install --create-namespace --namespace platform signoz-apm signoz/signoz`
    This is the self hosted APM Solution which leverages a lot of Opensource Components like OTEL, Clickhouse to deliver a Robust APM Alternative to likes of NewRelic, Datadog
    This requires Otel Instrumentation on the App Code base, but I have skipped it for simplicity. Right now with this deployment you can see Service level metrics and logs.
    
    To see it, if you're on k3s, minikube simply use the following to port forward and login to Signoz Front End
    ```
    export POD_NAME=$(kubectl get pods --namespace platform -l "app.kubernetes.io/name=signoz,app.kubernetes.io/instance=signoz-apm,app.kubernetes.io/component=frontend" -o jsonpath="{.items[0].metadata.name}")
    kubectl --namespace platform port-forward $POD_NAME 3301:3301
    ```
    This should allow you to loginto it using your localhost and port 3301
    
    
## Tesing it out:
Opening up a local Tunnel will grant you access to the port 8000, a `curl -XGET localhost:8000` will get you the desired result

## Stess Testing it:
You can use a busybox deployment to stress test it out, or use the pre-bundled (in this repo) **locust** to stress test it. Simply run it by issuing the command `locust` (It's there in the requirements.txt), and navigate to the webui. Set the host as `localhost:8000` and let it swarm.


