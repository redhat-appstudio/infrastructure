# Infrastructure

Contains miscellaneous scripts used by the infra team.

## Quick Commands

Terraform:
| Action  | Command                                                 |
|---------|---------------------------------------------------------|
| Format  | `terraform fmt -recursive`                              |
| Lint    | `tflint --recursive`                                    |

etcd-defrag:
| Action  | Command                                 |
|---------|-----------------------------------------|
| Build   | `docker build maintenance/etcd`         |
| Lint    | `shellcheck maintenance/etcd/defrag.sh` |

rover-group-sync:
| Action  | Command                                                        |
|---------|----------------------------------------------------------------|
| Build   | `docker build maintenance/rover-group-sync`                    |
| Lint    | `shellcheck maintenance/rover-group-sync/sync-rover-groups.sh` |
| Test    | `bats maintenance/rover-group-sync/test/`                      |

### Single-File Verification

- Terraform format: `terraform fmt path/to/file.tf`
- Shell lint: `shellcheck path/to/script.sh`
- YAML lint: `yamllint path/to/file.yaml`
- BATS test single: `bats path/to/test_file.bats`

## Project Layout

Terraform module (located at `terraform/modules/`):
- `network` - networking components
- `oidc_provider` - OIDC components

etcd-defrag (located at `maintenance/etcd/`):
- `defrag.sh` - business logic
- `Dockerfile` - image building
- `build-deps` - pinned dependencies

rover-group-sync (located at `maintenance/rover-group-sync/`):
- `sync-rover-groups.sh` - business logic
- `Dockerfile` - image building
- `test/` - unit tests
