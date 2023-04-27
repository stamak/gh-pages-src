---
layout: single
title:  "RDS access via kubernetes as jump host"
date:   2023-04-26 23:40:28 +0300
tags: [aws, k8s, eks, "jump host", socat]
---

Sometimes there is a need to connect to RDS in private VPC subnet having an access to EKS.
It can be achieved with help of `socket` container deployed on top of k8s and setting up the tunnel with
help of `kubectl port-forward`

## Deploy socat pod

{% highlight shell %}
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: rds-postgres-relay
  name: rds-postgres-relay
spec:
  containers:
    - name: rds-socat
      image: alpine/socat:latest
      args:
        - "TCP-LISTEN:5432,fork"
        - "TCP:private-rds.c1xfw13.eu-central-1.rds.amazonaws.com:5432"
      ports:
        - containerPort: 5432
          name: postgres
          protocol: TCP
{% endhighlight %}

## Set up tunnel:

{% highlight shell %}
kubectl port-forward pod/rds-postgres-relay 45432:5432
Forwarding from 127.0.0.1:45432 -> 5432
Forwarding from [::1]:45432 -> 5432
Handling connection for 45432
{% endhighlight %}

## Configure pgAdmin to use 127.0.0.1:45432

![pgAdmin4](/assets/pgAdmin4_connection_config.png)

