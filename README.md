# Kubernetes on Docker for Mac

> Please note, this project is work in progress.

```bash
git clone https://github.com/errordeveloper/kxd
cd kxd
./start.sh
```

Kubernetes API is now available on `localhost:8080` and doesn't require `kubeconfig`.

```console
> kubectl -s localhost:8080 cluster-info
Kubernetes master is running at localhost:8080
KubeDNS is running at localhost:8080/api/v1/proxy/namespaces/kube-system/services/kube-dns

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.

> kubectl -s localhost:8080 get nodes
NAME      STATUS         AGE
moby      Ready,master   2m
```

Next, let's make cluster DNS accessible from the Mac:
```
./proxy-service.sh --namespace kube-system kube-dns
```

Kubernetes DNS server is now directly accessible via it's service IP:
```
> dig kubernetes.default.svc.cluster.local @10.96.0.10

; <<>> DiG 9.8.3-P1 <<>> kubernetes.default.svc.cluster.local @10.96.0.10
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 25798
;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 0

;; QUESTION SECTION:
;kubernetes.default.svc.cluster.local. IN A

;; ANSWER SECTION:
kubernetes.default.svc.cluster.local. 22 IN A	10.96.0.1

;; Query time: 0 msec
;; SERVER: 10.96.0.10#53(10.96.0.10)
;; WHEN: Fri Feb 17 09:31:53 2017
;; MSG SIZE  rcvd: 70
```

To make any service IP available on the Mac, run `./proxy-service.sh [--namespace <namespace>] <name>`.

## Credits

Thanks to [@justincormack](https://github.com/justincormack) for help in understanding how to make service IPs work with Docker for Mac.
