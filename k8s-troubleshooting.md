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

---
# Part 2

## See Why the Pod Isn't Ready:
```bash
kubectl rollout status deploy/web-nginx
kubectl get pods -l app.kubernetes.io/instance=web -o wide
kubectl describe pod -l app.kubernetes.io/instance=web | sed -n '/Events/,$p'
kubectl logs deploy/web-nginx --all-containers --tail=200
```
What to look for in Events/Logs:
- Image pull/backoff
- Readiness probe failing
- CrashLoop due to bad values

## Check Endpoints Population:
`kubectl get endpoints web-nginx -o yaml | sed -n '1,40p'`
Look for addresses: 10.1.0.17:8080 (or similar)

## Is ingress admitted and pointing to the right svc:port?
```bash
kubectl describe ingress web-nginx | sed -n '/Rules/,$p'
# Host: hello.localtest.me
# Backend: service "web-nginx" port 80
# Events should show no errors
```

## Test through the controller (it’s the LoadBalancer on localhost:80):
```bash
curl -i -H "Host: hello.localtest.me" http://127.0.0.1/
# expect 200 and the NGINX page
```

## In the browser, check for `http://hello.localtest.me` - note, it's not `https` this time
```bash
# access logs from the controller while you load the page
kubectl -n ingress-nginx logs deploy/ingress-nginx-controller -f --since=5m | egrep -i 'hello.localtest.me|error'

# confirm the backend serves directly
kubectl port-forward svc/web-nginx 9090:80
open http://127.0.0.1:9090
```
Now the port-forward to `http://127.0.0.1:9090` from the browser does work

---
# Looks like Client Side (DNS/proxy) issue

## Does the machine resolve to host 127.0.0.1?
```bash
dig +short hello.localtest.me
# expect: 127.0.0.1
curl -v http://hello.localtest.me    # should show 200 and Host: hello.localtest.me
ping -c1 hello.localtest.me
```

## If not, map the host locally (macOS)
```bash
# add an explicit hosts entry
echo "127.0.0.1 hello.localtest.me" | sudo tee -a /etc/hosts

# flush DNS cache (macOS)
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```
**Verify:**
```bash
dig +short hello.localtest.me
curl -v http://hello.localtest.me
```

## Output should show that DNS was blocking
1. Now hit `http://hello.localtest.me` in browser!
2. Confirm controller sees the request: `kubectl -n ingress-nginx logs deploy/ingress-nginx-controller -f --since=5m`


