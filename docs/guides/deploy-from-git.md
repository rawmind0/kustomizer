# Deploy applications from Git with Kustomizer

This guide shows you how to deploy a sample application to a Kubernetes cluster.

You'll be using a sample app composed of two [podinfo](https://github.com/rawmind0/podinfo)
instances called `frontend` and `backend`, and a redis instance called `cache`.
The application's Kustomize overlay is located at
[examples/demo-app](https://github.com/rawmind0/kustomizer/tree/main/examples/demo-app).

## Before you begin

- Install the Kustomizer CLI by the following instructions in the [Installation guide](../install.md).
- Have a Kubernetes cluster version 1.20 or newer.

!!! info "Kubernetes authentication"

    To connect to Kubernetes API, Kustomizer uses the current context from `~/.kube/config`.
    You can set a different context with `--context=<your context>`.
    You can also specify a different kubeconfig with `--kubeconfig` or with the `KUBECONFIG` env var.

## Manual deployment

### Clone the app repository

Clone the Kustomizer Git repository locally:

```bash
git clone https://github.com/rawmind0/kustomizer
cd kustomizer
```

### Build the app config

Build the demo application to see its Kubernetes configuration:

```shell
kustomizer build inventory demo-app -k ./examples/demo-app -o yaml
```

You can validate the build command output with static analysis tools such as
[kubeval](https://github.com/instrumenta/kubeval) or [kubeconform](https://github.com/yannh/kubeconform):

```console
$ kustomizer build inventory demo-app -k ./examples/demo-app | kubeval
PASS - stdin contains a valid Namespace (kustomizer-demo-app)
PASS - stdin contains a valid ConfigMap (kustomizer-demo-app.redis-config-bd2fcfgt6k)
PASS - stdin contains a valid Service (kustomizer-demo-app.backend)
PASS - stdin contains a valid Service (kustomizer-demo-app.cache)
PASS - stdin contains a valid Service (kustomizer-demo-app.frontend)
PASS - stdin contains a valid Deployment (kustomizer-demo-app.backend)
PASS - stdin contains a valid Deployment (kustomizer-demo-app.cache)
PASS - stdin contains a valid Deployment (kustomizer-demo-app.frontend)
PASS - stdin contains a valid HorizontalPodAutoscaler (kustomizer-demo-app.backend)
PASS - stdin contains a valid HorizontalPodAutoscaler (kustomizer-demo-app.frontend)
```

### Install the app

Install the demo application by applying the local overlay on the cluster:

```console
$ kustomizer apply inventory demo-app -k ./examples/demo-app --prune --wait \
    --source="$(git ls-remote --get-url)" \
    --revision="$(git describe --always)"
building inventory...
applying 10 manifest(s)...
Namespace/kustomizer-demo-app created
ConfigMap/kustomizer-demo-app/redis-config-bd2fcfgt6k created
Service/kustomizer-demo-app/backend created
Service/kustomizer-demo-app/cache created
Service/kustomizer-demo-app/frontend created
Deployment/kustomizer-demo-app/backend created
Deployment/kustomizer-demo-app/cache created
Deployment/kustomizer-demo-app/frontend created
HorizontalPodAutoscaler/kustomizer-demo-app/backend created
HorizontalPodAutoscaler/kustomizer-demo-app/frontend created
waiting for resources to become ready...
all resources are ready
```

Kustomizer builds the overlay, validates the resulting resources against the Kubernetes API,
applies the resources with server-side apply, and finally waits for the workloads to be rolled out.

!!! info "Apply from other sources"

    Besides kustomize overlays, you can apply plain Kubernetes manifests using the `-f` flag:

    ```shell
    kustomizer apply inventory demo-app \
        -f ./path/to/dir/ \
        -f ./path/to/manifest.yaml
    ```

    An alternative to local files, is to apply Kubernetes configs from container registries
    using the `--artifact` flag:

    ```shell
    kustomizer apply inventory demo-app \
        --artifact oci://ghcr.io/rawmind0/kustomizer-demo-app:1.0.0
    ```

    For more details see `kustomizer apply inventory --help`.

### List and inspect the app config

After applying the resources, Kustomizer creates an inventory.
You can list all inventories in a specific namespace with:

```console
$ kustomizer get inventories -n default
NAME    	ENTRIES	SOURCE                                        	REVISION	LAST APPLIED
demo-app	10     	https://github.com/rawmind0/kustomizer.git	6aca8c2 	2021-12-22T09:15:22Z
```

You can view the Kubernetes objects in an inventory with:

```console
$ kustomizer inspect inventory demo-app
Inventory: default/demo-app
LastAppliedAt: 2021-12-22T09:15:22Z
Source: https://github.com/rawmind0/kustomizer.git
Revision: 6aca8c2
Resources:
- Namespace/kustomizer-demo-app
- ConfigMap/kustomizer-demo-app/redis-config-bd2fcfgt6k
- Service/kustomizer-demo-app/backend
- Service/kustomizer-demo-app/cache
- Service/kustomizer-demo-app/frontend
- Deployment/kustomizer-demo-app/backend
- Deployment/kustomizer-demo-app/cache
- Deployment/kustomizer-demo-app/frontend
- HorizontalPodAutoscaler/kustomizer-demo-app/backend
- HorizontalPodAutoscaler/kustomizer-demo-app/frontend
```

The inventory records are used to track which objects are subject to garbage collection.
The inventory is persistent on the cluster as a ConfigMap.

### Diff the app config changes

Delete the frontend workload and change the Redis version to `6.2.1` by editing
the `./examples/demo-app/kustomization.yaml` file.

If you have [yq](https://github.com/mikefarah/yq) installed, run:

```shell
yq eval 'del(.resources[0])' -i ./examples/demo-app/kustomization.yaml
yq eval '.images[1].newTag="6.2.1"' -i ./examples/demo-app/kustomization.yaml
```

Preview the changes using the diff command:

```console
$ kustomizer diff inventory demo-app -k ./examples/demo-app --prune
► Deployment/kustomizer-demo-app/cache drifted
@@ -5,7 +5,7 @@
     deployment.kubernetes.io/revision: "1"
     env: demo
   creationTimestamp: "2021-12-22T09:47:37Z"
-  generation: 1
+  generation: 2
   labels:
     app.kubernetes.io/instance: webapp
     inventory.kustomizer.dev/name: demo-app
@@ -36,7 +36,7 @@
       - command:
         - redis-server
         - /redis-master/redis.conf
-        image: public.ecr.aws/docker/library/redis:6.2.0
+        image: public.ecr.aws/docker/library/redis:6.2.1
         imagePullPolicy: IfNotPresent
         livenessProbe:
           failureThreshold: 3
► Service/kustomizer-demo-app/frontend deleted
► Deployment/kustomizer-demo-app/frontend deleted
► HorizontalPodAutoscaler/kustomizer-demo-app/frontend deleted
```

Note that when diffing Kubernetes secrets, Kustomizer diff masks the secret values in the output.

### Update the app

Rerun the apply command to update the demo application:

```console
$ kustomizer apply inventory demo-app -k ./examples/demo-app --prune --wait \
    --source="$(git ls-remote --get-url)" \
    --revision="$(git describe --dirty --always)"
building inventory...
applying 7 manifest(s)...
Namespace/kustomizer-demo-app unchanged
ConfigMap/kustomizer-demo-app/redis-config-bd2fcfgt6k unchanged
Service/kustomizer-demo-app/backend unchanged
Service/kustomizer-demo-app/cache unchanged
Deployment/kustomizer-demo-app/backend unchanged
Deployment/kustomizer-demo-app/cache configured
HorizontalPodAutoscaler/kustomizer-demo-app/backend unchanged
HorizontalPodAutoscaler/kustomizer-demo-app/frontend deleted
Deployment/kustomizer-demo-app/frontend deleted
Service/kustomizer-demo-app/frontend deleted
waiting for resources to become ready...
all resources are ready
```

After applying the resources, Kustomizer removes the Kubernetes objects that are not present in the current inventory.
Kustomizer garbage collector deletes the namespaced objects first then it removes the non-namspaced ones.

### Delete the app

Delete all the Kubernetes resources belonging to an inventory including the inventory storage:

```console
$ kustomizer delete inventory demo-app --wait
retrieving inventory...
deleting 7 manifest(s)...
HorizontalPodAutoscaler/kustomizer-demo-app/backend deleted
Deployment/kustomizer-demo-app/cache deleted
Deployment/kustomizer-demo-app/backend deleted
Service/kustomizer-demo-app/cache deleted
Service/kustomizer-demo-app/backend deleted
ConfigMap/kustomizer-demo-app/redis-config-bd2fcfgt6k deleted
Namespace/kustomizer-demo-app deleted
ConfigMap/default/demo-app deleted
waiting for resources to be terminated...
all resources have been deleted
```

## Automated deployment

You can automate the deployment process by running Kustomizer in CI.

Here is an example of a GitHub Actions workflow that deploys the app
every time there is a change to the Kubernetes configuration:

```yaml
name: deploy
on:
  push:
    branches:
      - 'main'
    paths:
      - 'examples/demo-app/**'

jobs:
  kustomizer:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v2
      - name: Setup kubeconfig
        uses: azure/k8s-set-context@v1
        with:
          kubeconfig: ${{ secrets.KUBE_CONFIG }}
      - name: Setup kustomizer
        uses: rawmind0/kustomizer/action@main
      - name: Diff
        continue-on-error: true
        run: |
          kustomizer diff inventory ${{ github.event.repository.name }} \
            -k ./examples/demo-app --prune
      - name: Deploy
        run: |
          kustomizer apply inventory ${{ github.event.repository.name }} \
            --source=${{ github.event.repository.html_url }} \
            --revision=${{ github.sha }} \
            -k ./examples/demo-app --prune --wait
```

For more details on how to use Kustomizer within GitHub workflows,
please see the [GitHub Actions documentation](../github-actions.md).
