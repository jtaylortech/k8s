## 0) Sanity

```bash
kubectl get nodes
kubectl get ns
kubectl get pods -A | grep -E 'ingress|nginx|web'
``` 

## 1) Is the ingress controller running?

`kubectl -n ingress-nginx get deploy,po,svc # expect a Deployment like ingress-nginx-controller and a Service named ingress-nginx-controller` 

If no controller exists, (re)install:

```bash
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx --create-namespace
``` 

## 2) Does the Ingress use the right class?

```bash
kubectl get ingressclass # note the name, usually "nginx" kubectl get ingress
kubectl describe ingress web-tls || kubectl describe ingress web-nginx || kubectl get ingress -o wide
```

If the Ingress shows `ingressClassName: nginx` but `kubectl get ingressclass` shows a different name, fix Ingress:

`kubectl patch ingress web-nginx --type='json' -p='[{"op":"replace","path":"/spec/ingressClassName","value":"nginx"}]'  # or update the values and re-run helm upgrade` 

## 3) Is the controller actually reachable from localhost?

Check Service type and ports:

`kubectl -n ingress-nginx get svc ingress-nginx-controller -o wide -o yaml | egrep 'type:|nodePort:|clusterIP:|externalIPs:|externalTrafficPolicy:'` 

### path A — port-forward (works everywhere)

`kubectl -n ingress-nginx port-forward svc/ingress-nginx-controller 8080:80 # in another terminal: curl -i -H "Host: hello.localtest.me" http://127.0.0.1:8080/` 

### path B — NodePort (works internally)

```bash
export NP=$(kubectl -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')
curl -i -H "Host: hello.localtest.me" http://127.0.0.1:$NP/
``` 

If these work, the Ingress is fine—the issue was just reachability (Desktop’s LB mode).

## 4) Is the Bitnami NGINX Service name correct?

The chart’s Service is usually `web-nginx` (if release name is `web`). Confirm:

```bash
kubectl get svc
kubectl get svc web-nginx -o yaml | egrep 'port:|targetPort:|selector:'
``` 

If your Ingress backend points to the wrong Service, fix it (values or patch):

`kubectl describe ingress # verify backend service name/port is web-nginx:80`