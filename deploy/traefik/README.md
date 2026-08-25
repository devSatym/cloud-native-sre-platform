# Retired Traefik IngressRoute manifest

The GKE target uses the standard Kubernetes `Ingress` rendered by
[`../helm/templates/ingress.yaml`](../helm/templates/ingress.yaml), not a Traefik
custom resource. The previous IngressRoute was tied to a local namespace and host,
so it has been removed to prevent an accidental parallel ingress path.

For local TLS experiments, generate a certificate with
`scripts/generate-certs.sh` and supply it through the Helm `ingress.tls` values.
