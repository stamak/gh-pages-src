---
layout: single
title:  "Reverse Port Forwarding"
date:   2024-03-05 19:24:34 +0300
tags: [devops, k8s, kubernetes, port-forward, reverse, ssh, netcat, kubectl, networking]
---

# Connecting from a Kubernetes to a Service running on your local machine

## Introduction
Sometimes you need to connect from a service running in a Kubernetes cluster to a service running on your local machine. This can be useful for debugging, testing, or development purposes. In this article, we'll explore how to set up reverse port forwarding to enable this kind of connection.

## High-Level Architecture
![aReverse Port Forwarding](/assets/RvrsPortFwd.png){:height="1700px" width="700px"}
As shown in the diagram, the service running in the Kubernetes cluster needs to connect to a service running on your local machine.

The `kubectl port-forward` command is used to forward a local port `8022` to the ssh server pod port `22` running in the Kubernetes cluster.

The `ssh -R` command is used to let us forward the remote port `50080` from the ssh server pod to the local machine port `8080`.

The kubernetes service `fwd-to-local-dev` is used to expose the ssh server pod port `50080` as port `8080` to all services running on the Kubernetes cluster and the test pod as well.

For testing purposes, a simple `netcat` is used to listen on a port `8080` on the local machine, and a test pod is used to connect to this service with `netcat` client through the reverse port forwarding tunnel.

## Kubernetes Resources Congifurations
Preapare the following configurations to deploy the resources in the Kubernetes cluster.

Create a directory to store the configurations
{% highlight shell %}
mkdir k8s-manifests
cd k8s-manifests
{% endhighlight %}

___
Pod Configuration

The `Alpine Linux` is used as a base image for the ssh server pod.
{% highlight shell %}
cat <<EOF > pod.yml
apiVersion: v1
kind: Pod
metadata:
  labels:
    app.kubernetes.io/name: fwd-to-local-dev
  name: reverse-port-forward
spec:
  containers:
    - name: alpine-ssh-server
      image: alpine:3.19
      command: ["sh", "-c", "apk add openssh-server;
        ssh-keygen -A;
        echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config;
        sed -i -e 's/AllowTcpForwarding\ no/AllowTcpForwarding\ yes/g' /etc/ssh/sshd_config;
        sed -i -e 's/GatewayPorts\ no/GatewayPorts\ yes/g' /etc/ssh/sshd_config;
        echo 'root:dummy_passwd'|chpasswd;
        /usr/sbin/sshd -D -e"]
      ports:
        - containerPort: 50080
          name: rvrs-prt-fwd
          protocol: TCP
EOF
{% endhighlight %}

___
 Service Configuration
{% highlight shell %}
cat <<EOF > svc.yml
apiVersion: v1
kind: Service
metadata:
  name: fwd-to-local-dev
spec:
  selector:
    app.kubernetes.io/name: fwd-to-local-dev
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 50080
EOF
{% endhighlight %}

___
 Test pod configuration
{% highlight shell %}
cat <<EOF > test-pod.yml
apiVersion: v1
kind: Pod
metadata:
  labels:
    app.kubernetes.io/name: test-pod
  name: test-pod
spec:
  containers:
    - name: test-pod
      image: alpine:3.19
      command: ["sh", "-c", "apk add netcat-openbsd;
        while true; do sleep 1; done"]
EOF
{% endhighlight %}

___
 Deploy the resources
{% highlight shell %}
stamak@terminal1:~/k8s-manifests$ ls -la
total 12
drwxr-xr-x   5 stamak staff  160 бер  6 18:03 .
drwxr-x---+ 97 stamak staff 3104 бер  6 18:01 ..
-rw-r--r--   1 stamak staff  677 бер  6 18:02 pod.yml
-rw-r--r--   1 stamak staff  197 бер  6 18:02 svc.yml
-rw-r--r--   1 stamak staff  251 бер  6 18:03 test-pod.yml
stamak@terminal1:~/k8s-manifests$ kubectl apply -f .
pod/reverse-port-forward created
service/fwd-to-local-dev created
pod/test-pod created
{% endhighlight %}
___
## Setting up the Reverse Port Forwarding
To set up the reverse port forwarding, you need to run the following command on your local machine:

**[Terminal 1]** Forward the local port 8022 to the ssh server pod

{% highlight shell %}
kubectl port-forward pod/reverse-port-forward 8022:22
{% endhighlight %}
___

**[Terminal 2]** Start locally service listening on port or `netcat` in my case

*NOTE*: `8080` port is port where my netcat service is listening on.
Just skip this step if you already have a service running on your local machine.
Please do not forget to replace the port number in the next step with the port your service is listening on.
{% highlight shell %}
nc -l 8080
{% endhighlight %}
___

**[Terminal 3]** Open a reverse ssh tunnel to the ssh server pod

*NOTE*: `8080` port is port where your local service is listening on.
You can replace it with the port your service is listening on.

*NOTE*: Password: `dummy_passwd`
{% highlight shell %}
ssh -R 50080:localhost:8080 root@localhost -p 8022 -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null
{% endhighlight %}
___

**[Terminal 4]** Testing the Connection

To test the connection, you can run the following command in the test pod:
{% highlight shell %}
kubectl exec -it test-pod -- sh
/ # nc fwd-to-local-dev 8080
{% endhighlight %}
___

## Screen Shot
![ScreenShot](/assets/RvrsPortFwdScreen2.png){:height="1700px" width="700px"}
