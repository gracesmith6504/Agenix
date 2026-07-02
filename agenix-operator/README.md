# agenix-operator

Kubernetes operator for the Agenix project. See the [repository README](../README.md) for architecture, design context, and demo walkthrough.

## Prerequisites

- Go 1.26+
- Docker or Podman
- `kubectl` (or `oc` on OpenShift)
- Access to a Kubernetes 1.28+ cluster

## Development

```bash
make manifests generate   # After API type changes
make test                 # Unit + integration tests
make lint-fix
make run                  # Run locally against current kubeconfig
```

## Build and Deploy
For local Kind/Podman setup, see [Quick Start in the repository README.](../README.md)
```bash
export IMG=<registry>/agenix-operator:<tag>

make docker-build docker-push IMG=$IMG
make install                 # Install CRDs
make install-cert-manager    # Required before deploy on clusters without cert-manager
make deploy IMG=$IMG         # Deploy controller + webhook + cert-manager resources
```

### Apply Samples

Weather agent:

```bash
kubectl apply -k config/samples/
kubectl wait --for=jsonpath='{.status.phase}'=Verified agentidentity/weather-agent-identity --timeout=120s
kubectl rollout status deployment/weather-agent --timeout=120s
```

Data agent (second agent for multi-agent demos):

```bash
kubectl apply -k config/samples2/
kubectl wait --for=jsonpath='{.status.phase}'=Verified agentidentity/data-agent-identity --timeout=120s
kubectl rollout status deployment/data-agent --timeout=120s
```

Both agents:

```bash
kubectl apply -k config/samples/
kubectl apply -k config/samples2/
```

### Uninstall

```bash
kubectl delete -k config/samples2/ --ignore-not-found
kubectl delete -k config/samples/
make undeploy
make uninstall
```

## E2E Tests

E2E tests require an isolated [Kind](https://kind.sigs.k8s.io/) cluster — do not run them against a shared dev or production cluster.

```bash
make setup-test-e2e
make test-e2e
```

## Operator Logs

```bash
kubectl logs -n agenix-operator-system \
  deployment/agenix-operator-controller-manager -c manager -f
```

## Make Targets

Run `make help` for the full list of build, test, and deploy targets.

## License

Copyright 2026.

Licensed under the Apache License, Version 2.0. See http://www.apache.org/licenses/LICENSE-2.0.
