---
layout: single
title:  "AWS ALB Ingress Advanced Request Routing"
date:   2023-04-28 20:40:28 +0300
tags: [aws, k8s, eks, ingress, alb]
---

AWS Application Load Balancer allows traffic to be routed based on HTTP header, HTTP request method,
query string, source IP, in addition host and path-based routing.

As it turns out, configuring a [k8s ingress][k8s-ingress-docs] can be a bit tricky, as the
[Official documentations][alb-docs] does not provide good examples.
In my example, I will show how to route requests with the host header "my-host.example.com" and
the HTTP header "X-Custom-Header: CustomHeaderValue" to the Kubernetes service "my-srv" on port 8080.

[k8s-ingress-docs]: https://kubernetes.io/docs/concepts/services-networking/ingress/
[alb-docs]: https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.5/guide/ingress/annotations/#traffic-routing


## Prepare ingress k8s manifest

{% highlight shell %}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-srv-custom-header
  annotations:
    alb.ingress.kubernetes.io/conditions.header-based: |
      [{"field":"http-header","httpHeaderConfig":{"httpHeaderName": "X-Custom-Header", "values":["CustomHeaderValue"]}}]
    alb.ingress.kubernetes.io/actions.header-based: |
      {"type":"forward","forwardConfig":{"targetGroups":[{"serviceName":"my-srv","servicePort":8080}]}}
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:eu-central-1:1111111111:certificate/528f4790-1d24-xxxx-xxxx-a8f493a3c948
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
    - host: "my-host.example.com"
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: header-based
                port:
                  name: use-annotation
{% endhighlight %}


## Verification

{% highlight shell %}
$ curl -H 'X-Custom-Header: CustomHeaderValue' https://my-host.example.com/healthcheck
OK

# no header
$ curl https://my-host.example.com/healthcheck
Backend service does not exists
{% endhighlight %}
