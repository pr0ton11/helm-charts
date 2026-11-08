# Forgejo

This chart follows stable Forgejo releases independently of the upstream chart's LTS default.
The initial chart version is `0.1.0`, with Forgejo `17.0.1`.
It starts from upstream chart `17.3.2` and preserves its values interface and resource names.
The original MIT license is in [LICENSE](LICENSE).

The [upstream values reference](UPSTREAM.md) describes the inherited configuration.
Application configuration still uses the `gitea` key for compatibility.
The chart keeps the upstream templates, scripts, and locked `common` library dependency.
It does not deploy a database or cache server.

## Installation

```console
helm install forgejo oci://ghcr.io/pr0ton11/charts/forgejo --version 0.1.0 -f values.yaml
```

For an existing release, follow the [migration procedure](docs/migration.md).
Keep its release name, namespace, storage claim, and configuration.
Do not uninstall the existing release.

## Application updates

`Chart.yaml` contains the default application version in `appVersion`.
`image.tag` stays empty so that every application and init container uses that version.
The chart adds `-rootless` when `image.rootless` is true.
An explicit `image.tag`, `image.digest`, or `image.fullOverride` still takes precedence where applicable.
Remove obsolete image overrides when adopting a new chart default.

Renovate reads `appVersion` from the Docker registry and proposes stable releases, including new major versions.
Each application update also bumps the chart version.
These PRs require review and passing CI. They do not merge automatically.
Review the [Forgejo release notes](https://forgejo.org/releases/) and [upgrade guide](https://forgejo.org/docs/latest/admin/upgrade/) before each major upgrade.
A new image can migrate the database. A Helm rollback does not restore that database.

The [upstream sync workflow](../../.github/workflows/forgejo-upstream.yaml) checks for published chart releases every Monday at 06:23 UTC.
You can also start it with `workflow_dispatch` in GitHub Actions.
It opens or updates one PR on `automation/forgejo-upstream`.
It never merges the PR or deploys the chart.

The sync uses a three-way merge against the previous upstream release.
It merges templates, scripts, values, schema, upstream documentation, and license changes.
It updates the locked dependencies and bumps our chart version.
It preserves our application version, Renovate tracking, README, migration instructions, and tests.
If upstream edits overlap local edits, the workflow fails without writing partial changes.
Resolve those conflicts manually before accepting the new baseline.

The upstream baseline version and OCI digest are recorded in `Chart.yaml`.
The sync verifies the previous artifact against its recorded digest.
Template tests run before the PR opens.
The workflow then dispatches full Charts CI on the PR branch because PRs created with `GITHUB_TOKEN` do not trigger it automatically.
In repository Actions settings, enable “Allow GitHub Actions to create and approve pull requests” so the workflow can open PRs.
The workflow does not approve PRs.

To check for a new upstream chart locally, install PyYAML and run:

```console
python3 -m pip install PyYAML
python3 -B scripts/sync_forgejo_upstream.py
```

Review the diff and rerun the migration comparison before deployment.

## Validation

```console
helm dependency build charts/forgejo
bash charts/forgejo/tests/template_test.sh
```

The tests cover the default image, all init images, explicit image overrides, rootless selection, existing storage, existing Secrets, and Gateway API routes.
They also prove that changing `appVersion` changes every application image.
CI runs these tests before publishing the chart to GHCR.
Template checks do not prove a database migration or application startup.
