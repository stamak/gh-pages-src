---
layout: single
title:  "ALB Ingress Controller and Cost Optimization"
date:   2023-04-16 23:40:28 +0300
tags: [aws, k8s, alb]
categories: [aws, alb, k8s, ingress]
---

As we know ALB Ingress Controller creates Load Balancer per k8s ingress resource by default and it's costly,
roughly one ALB costs ~$24 + extra per GB of processed data monthly.

In order to save money there is a possibility to have use `One` ALB for all your k8s ingress resources.
To acheave it one extra annotations should be added to all your ingress resources should have common annotaion:

{% highlight shell %}
  annotations:
    alb.ingress.kubernetes.io/group.name: shared-ingress
{% endhighlight %}

Output for all ingress resources:
{% highlight shell %}
$ kubectl get ing -A
NAMESPACE     NAME          CLASS  HOSTS                             ADDRESS                                                    PORTS    AGE
default     ingress-1        alb    ingress-1.example.com      k8s-sharedingress-dbc951d-472698.eu-central-1.elb.amazonaws.com   80      5d4h
namespace2  ingress-2        alb    ingress-2.example.com      k8s-sharedingress-dbc951d-472698.eu-central-1.elb.amazonaws.com   80      5d4h
ns3         ingress-3        alb    ingress-3.example.com      k8s-sharedingress-dbc951d-472698.eu-central-1.elb.amazonaws.com   80      5d4h
{% endhighlight %}

For more details visit [official docs][alb-cont-docs].

[alb-cont-docs]: https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/guide/ingress/annotations/#group.name
