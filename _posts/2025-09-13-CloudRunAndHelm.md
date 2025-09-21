---
layout: single
title:  "Scaling Up: Why Your Cloud Run Deployments Need Helm"
excerpt: This article explores the limitations of using gcloud CLI for deploying multi-service applications on Google Cloud Run and advocates for using Helm to manage complex deployments effectively.
date:   2025-09-21 12:00:35 +0300
tags: [GCP, Google Cloud Platform, Cloud Run, Helm]
---

The `gcloud` CLI is the Swiss Army knife of Google Cloud. For a single service, a quick `gcloud run deploy` is a developer's best friend—fast, simple, and effective. But what happens when your project evolves from a single service into a complex ecosystem of microservices? What if you have different configurations for development, staging, and production environments?

This is where the limitations of the `gcloud` CLI begin to surface. While powerful, it's not designed for the kind of consistent, repeatable, and templated deployments that modern applications require.

## The Problem with Manual gcloud Deployments
Using `gcloud run deploy` for a multi-service application often leads to a few common problems:

- **Manual Configuration Management**: Each service deployment requires its own set of arguments for environment variables, secrets, and other settings. This often results in scattered shell scripts or, even worse, manual copy-pasting of commands for each environment. It's a fragile process prone to human error and configuration drift.

- **Lack of Resource Control**: The `gcloud` CLI provides limited control over key deployment parameters like memory limits, CPU allocation, and maximum instances. For advanced use cases where fine-tuning performance and cost is critical, this lack of configurability is a major drawback.

- **Lack of a Single Source of Truth**: Your application's state (its services, their configurations, and their relationships) is not stored in a single, version-controlled file. This makes it difficult to audit deployments, roll back to a known-good state, and onboard new team members.

- **Complex CI/CD Pipelines**: Integrating `gcloud` commands into a CI/CD pipeline for a multi-service app can be clunky. You often have to chain multiple, non-declarative commands, which can be hard to manage and debug.

## The Declarative Alternative: Deploying with YAML
A significant step up from the command line is to use a declarative YAML manifest for your Cloud Run service. You can define your entire service configuration, including environment variables and resource limits, in a single file and deploy it using the `gcloud run services replace` command.

This approach gives you a version-controlled, single source of truth for your service. For example, you can explicitly set CPU, memory, and scaling parameters in your YAML file:

```yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: my-app-service
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: "0"
        autoscaling.knative.dev/maxScale: "10"
    spec:
      containerConcurrency: 80
      timeoutSeconds: 300
      containers:
        - image: gcr.io/my-project/my-image:latest
          resources:
            limits:
              cpu: "1000m"
              memory: "512Mi"
```


While this method is a significant improvement, it is still limited. You would need to create a new, hard-coded YAML file for every service and every environment (e.g., `prod-service-a.yaml`, `dev-service-b.yaml`), which quickly becomes unmanageable for a microservices architecture.

## The Helm Solution
Enter Helm. While it's most famous as the package manager for Kubernetes, its templating and packaging capabilities are a perfect fit for solving Cloud Run's advanced deployment challenges. Helm treats your entire application as a single, versioned package—a "chart."

By using Helm, you get the following key benefits:

- Declarative and Version-Controlled Deployments: Your entire application manifest is defined in a Helm chart's YAML files. This means your infrastructure is now treated as code. Every change is tracked in Git, providing an immutable history of your deployments.

- Templating for Different Environments: Helm's `values.yaml` file allows you to define configurable variables. You can have a single Helm chart and override values for different environments (e.g., `values-production.yaml` and `values-staging.yaml`), ensuring consistency while maintaining flexibility.

- Atomic Deployments: With a single `helm install` or `helm upgrade` command, you can deploy your entire application stack. Helm handles the dependencies and ensures all components are deployed correctly, or rolls back if something fails. This replaces a dozen error-prone `gcloud` arguments with a single, reliable two-step process in our case.

- Simplified CI/CD: Helm integrates seamlessly into CI/CD pipelines. You can define a single pipeline step to update your Helm values (e.g., set a new image tag) and then deploy the entire application with a single command.

## How to Do it: Helm for Cloud Run
The most direct way to leverage Helm with Cloud Run is by using its templating and packaging capabilities to generate a custom YAML manifest that you can then deploy directly to Cloud Run.

Here’s a simplified breakdown of the process:

- Create Your Helm Chart: Use the `helm create` command to generate a new chart directory. This gives you a standard structure with `Chart.yaml`, values.yaml, and a templates/ folder.

- Define Your Cloud Run Service: In the templates/ directory, you'll create a file (e.g., service.yaml) that defines your Cloud Run service using a Knative Service manifest. This manifest will use placeholders that reference your values.yaml file.
For example, your `templates/service.yaml` might look something like this:
{% raw %}
```yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: {{ .Values.appName | quote }}
  annotations:
    run.googleapis.com/ingress: internal-and-cloud-load-balancing
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/maxScale:  {{ .Values.maxScale | default 10 | quote }}
        run.googleapis.com/network-interfaces: '[{"network":"default","subnetwork":"yn-default-dev-us-east4-priv-0"}]'
        run.googleapis.com/vpc-access-egress: all-traffic
        run.googleapis.com/cpu-throttling: {{ .Values.concurrency | default 'true' | quote }}
      labels:
        cloud.googleapis.com/location:  {{ .Values.region | quote }}
    spec:
      serviceAccountName: {{ .Values.serviceAccountName | quote }}
      containers:
        - image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          ports:
            - containerPort:  {{ .Values.service.port | default 8000 }}
          resources:
          {{- if .Values.resources }}
            {{- toYaml .Values.resources | nindent 12 }}
          {{- else }}
          {{- end }}
          env:
            # Literal environment variables from .Values.env
          {{- range $key, $value := .Values.env }}
            - name: {{ $key | quote }}
              value: {{ $value | quote }}
          {{- end }}

            # Secrets from .Values.secrets
          {{- range $envVarName, $secretRef := .Values.secrets }}
            - name: {{ $envVarName | quote }}
              valueFrom:
                secretKeyRef:
                  name: {{ $secretRef.name | quote }}
                  key: {{ $secretRef.key | default "latest" | quote }} # Default to 'latest' if not specified
          {{- end }}

      containerConcurrency: {{ .Values.concurrency }}
      timeoutSeconds: {{ .Values.timeoutSeconds }}
```
{% endraw %}

- Configure Your `values.yaml`: This file holds all the customizable values for your application. You can have a different `values.yaml` for each environment.
```yaml
appName: my-app-service
# Cloud Run region
region: us-central1
# Image configuration
image:
  repository: "gcr.io/my-project/my-image"
  tag: "latest"
# Service configuration
service:
  port: 8000
# Resource limits
resources:
  limits:
    cpu: "1000m"
    memory: "512Mi"
# Scaling settings
maxScale: 10
# Concurrency and timeouts
concurrency: 80
timeoutSeconds: 300
# Service account for the application
serviceAccountName: my-service-account
# Environment variables for the container
env:
  DB_HOST: "my-db-dev"
  API_KEY: "dev-key"
# Secrets to be injected as environment variables
secrets:
  GCS_BUCKET:
    name: "my-gcs-bucket-secret"
    key: "bucket-name"
```

- Deploy with Helm and gcloud: With your chart ready, you can deploy your application with a two-step process that can be easily automated in a CI/CD pipeline.
```sh
# Generate the final Cloud Run YAML manifest
helm template my-app-release ./my-chart > my-app-service.yaml
# Deploy the generated YAML to Cloud Run
gcloud run services replace my-app-service.yaml --region=us-central1
```

## Conclusion
While the gcloud CLI is an excellent tool for quick and simple deployments, it can quickly become unwieldy for complex, multi-service applications. By adopting a declarative YAML approach, you gain some control, but for true enterprise-scale needs, Helm provides the ultimate solution. By adopting Helm, you can transform your Cloud Run deployments into a declarative, version-controlled, and repeatable process. This not only streamlines your CI/CD pipeline but also ensures consistency across all your environments, saving you time and headaches in the long run.

