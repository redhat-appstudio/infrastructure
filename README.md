# infrastructure

Miscellaneous infrastructure components for Konflux: Terraform modules for cloud networking and OIDC, maintenance scripts (etcd defrag, Rover group sync), and Tekton pipeline definitions.

## Prerequisites

- Terraform >= 1.x (for `terraform/modules/`)
- Docker or Podman (for building maintenance containers)
- shellcheck (for linting shell scripts)
- BATS (for running rover-group-sync tests)

## Usage

See [AGENTS.md](AGENTS.md) for quick commands, project layout, and development conventions.

## Components

- **terraform/modules/** — Terraform modules for networking and OIDC provider
- **maintenance/etcd/** — etcd defragmentation container
- **maintenance/rover-group-sync/** — Rover group synchronization container with BATS tests
- **.tekton/** — Konflux pipeline definitions for container builds
