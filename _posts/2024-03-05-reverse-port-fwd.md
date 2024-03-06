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

![Reverse Port Forwarding](/assets/RvrsPortFwd.png){:height="1700px" width="700px"}

## Kubernetes Resources Congifurations
Prepare the following configurations to deploy the resources in the Kubernetes cluster.

 Create a directory to store the configurations
{% highlight shell %}
mkdir k8s-manifests
cd k8s-manifests
{% endhighlight %}

 Pod Configuration
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
      image: alpine:latest
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
      image: alpine:latest
      command: ["sh", "-c", "apk add netcat-openbsd; while true; do sleep 1; done"]
EOF
{% endhighlight %}

 Deploy the resources
{% highlight shell %}
stamak@local-dev:~/k8s-manifests$ ls -la
total 12
drwxr-xr-x   5 smakar staff  160 бер  6 18:03 .
drwxr-x---+ 97 smakar staff 3104 бер  6 18:01 ..
-rw-r--r--   1 smakar staff  677 бер  6 18:02 pod.yml
-rw-r--r--   1 smakar staff  197 бер  6 18:02 svc.yml
-rw-r--r--   1 smakar staff  251 бер  6 18:03 test-pod.yml
stamak@local-dev:~/k8s-manifests$ kubectl apply -f .
pod/reverse-port-forward created
service/fwd-to-local-dev created
pod/test-pod created
{% endhighlight %}

## Setting up the Reverse Port Forwarding
To set up the reverse port forwarding, you need to run the following command on your local machine:

 [Terminal 1] Forward the local port 8022 to the ssh server pod
{% highlight shell %}
kubectl port-forward pod/reverse-port-forward 8022:22
{% endhighlight %}

 [Terminal 2] Start locally service listening on port 8080 or netcat in my case
{% highlight shell %}
nc -l 8080
{% endhighlight %}

 [Terminal 3] Open a reverse ssh tunnel to the ssh server pod
password: dummy_passwd
{% highlight shell %}
ssh -R 50080:localhost:8080 root@localhost -p 8022 -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null
{% endhighlight %}

## [Terminal 4] Testing the Connection
To test the connection, you can run the following command in the test pod:

{% highlight shell %}
kubectl exec -it test-pod -- sh
/ # nc fwd-to-local-dev 8080
{% endhighlight %}

## Screen Shot
![ScreenShot](/assets/RvrsPortFwdScreen.png){:height="1700px" width="700px"}
