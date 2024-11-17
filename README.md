# kustomizer

[![report](https://goreportcard.com/badge/github.com/rawmind0/kustomizer)](https://goreportcard.com/report/github.com/rawmind0/kustomizer)
[![e2e](https://github.com/rawmind0/kustomizer/workflows/e2e/badge.svg)](https://github.com/rawmind0/kustomizer/actions)
[![codecov](https://codecov.io/gh/rawmind0/kustomizer/branch/main/graph/badge.svg?token=KEU5W1LSZC)](https://codecov.io/gh/rawmind0/kustomizer)
[![license](https://img.shields.io/github/license/rawmind0/kustomizer.svg)](https://github.com/rawmind0/kustomizer/blob/main/LICENSE)
[![release](https://img.shields.io/github/release/rawmind0/kustomizer/all.svg)](https://github.com/rawmind0/kustomizer/releases)

Kustomizer is an experimental package manager for distributing Kubernetes configuration as OCI artifacts.
It offers commands to publish, fetch, diff, customize, validate, apply and prune Kubernetes resources.

Kustomizer relies on [server-side apply](https://kubernetes.io/docs/reference/using-api/server-side-apply/)
and requires a Kubernetes cluster **v1.20** or newer.

## Install

The Kustomizer CLI is available as a binary executable for all major platforms,
the binaries can be downloaded from GitHub [releases](https://github.com/rawmind0/kustomizer/releases).
The binaries checksums are signed with Cosign
and each release comes with a Software Bill of Materials (SBOM) in SPDX format.

Install the latest release on macOS or Linux with Homebrew:

```bash
brew install rawmind0/tap/kustomizer
```

For other installation methods,
see [kustomizer.dev/install](https://kustomizer.dev/install/).

## Get started

To get started with Kustomizer please visit the documentation website at [kustomizer.dev](https://kustomizer.dev/).

## Concepts

### OCI Artifacts

Kustomizer offers a way to distribute Kubernetes configuration using container registries.
It can package Kubernetes manifests in an OCI image and store them in a container registry,
right next to your applications' images.

Kustomizer comes with commands for managing OCI artifacts:

- `kustomizer push artifact oci://<image-url>:<tag> -k [-f] [-p]`
- `kustomizer tag artifact oci://<image-url>:<tag> <new-tag>`
- `kustomizer list artifacts oci://<repo-url> --semver <condition>`
- `kustomizer pull artifact oci://<image-url>:<tag>`
- `kustomizer inspect artifact oci://<image-url>:<tag>`
- `kustomizer diff artifact <oci url> <oci url>`

Kustomizer is compatible with Docker Hub, GHCR, ACR, ECR, GCR, Artifactory,
self-hosted Docker Registry and others. For auth, it uses the credentials from `~/.docker/config.json`.

#### Sign & Verify Artifacts

Kustomizer can sign and verify artifacts using [sigstore/cosign](https://github.com/sigstore/cosign) either with
static keys, Cloud KMS or keyless signatures
(when running [Kustomizer with GitHub Actions](https://kustomizer.dev/github-actions/#publish-signed-artifacts)):

- `kustomizer push artifact --sign --cosign-key <private key>`
- `kustomizer pull artifact --verify --cosign-key <public key>`
- `kustomizer inspect artifact --verify --cosign-key <public key>`

For an example on how to secure your Kubernetes supply chain with Kustomizer and Cosign
please see [this guide](https://kustomizer.dev/guides/secure-supply-chain/).

### Resource Inventories

Kustomizer offers a way for grouping Kubernetes resources.
It generates an inventory which keeps track of the set of resources applied together.
The inventory is stored inside the cluster in a `ConfigMap` object and contains metadata
such as the resources provenance and revision.

The Kustomizer garbage collector uses the inventory to keep track of the applied resources
and prunes the Kubernetes objects that were previously applied but are missing from the current revision.

You specify an inventory name and namespace at apply time, and then you can use Kustomizer to
list, diff, update, and delete inventories:

- `kustomizer apply inventory <name> [--artifact <oci url>] [-f] [-p] -k`
- `kustomizer diff inventory <name> [-a] [-f] [-p] -k`
- `kustomizer get inventories --namespace <namespace>`
- `kustomizer inspect inventory <name> --namespace <namespace>`
- `kustomizer delete inventory <name> --namespace <namespace>`

When applying resources from OCI artifacts, Kustomizer saves the artifacts URL and
the image SHA-2 digest in the inventory. For deterministic and repeatable apply operations,
you could use digests instead of tags.

### Encryption at rest

Kustomizer has builtin support for encrypting and decrypting Kubernetes configuration (packaged as OCI artifacts)
using [age](https://github.com/FiloSottile/age) asymmetric keys.

To securely distribute sensitive Kubernetes configuration to trusted users,
you can encrypt the artifacts with their age public keys:

- `kustomizer push artifact oci://<image-url>:<tag> --age-recipients <public keys>`

Users can access the artifacts by decrypting them with their age private keys:

- `kustomizer inspect artifact oci://<image-url>:<tag> --age-identities <private keys>`
- `kustomizer pull artifact oci://<image-url>:<tag> --age-identities <private keys>`
- `kustomizer apply inventory <name> [--artifact <oci url>] --age-identities <private keys>`
- `kustomizer diff inventory <name> [--artifact <oci url>] --age-identities <private keys>`

## Contributing

Kustomizer is [Apache 2.0 licensed](LICENSE) and accepts contributions via GitHub pull requests.
