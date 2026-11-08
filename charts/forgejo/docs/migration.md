# Migrate an existing Forgejo release

This procedure changes the chart source and upgrades Forgejo to `17.0.1`.
It preserves the upstream values interface and resource names.
The destination chart is `oci://ghcr.io/pr0ton11/charts/forgejo`, version `0.1.0`.
Publish that chart before changing the cluster configuration.

## Prepare the upgrade

Read the [Forgejo upgrade guide](https://forgejo.org/docs/latest/admin/upgrade/) and the [release notes](https://forgejo.org/releases/).
Before the upgrade, back up the PostgreSQL database and all persistent Forgejo data together.
Preserve the existing application secrets and configuration.
Drain the application queues as described in the upgrade guide.
Plan downtime for the existing `Recreate` deployment strategy.

Do not select an application version older than the deployed version.
Do not use a Helm rollback to downgrade Forgejo after a database migration.
Recovery requires the matching database and storage backup.
The optional cleanup of migrated pull request patches in Forgejo 17 is not required for this migration.

## Change the source configuration

For K3s, edit the source manifest that creates the existing `helm.cattle.io/v1` `HelmChart`.
Keep its metadata name, namespace, target namespace, and current values.
Change only these fields within the existing resource:

```yaml
spec:
  chart: oci://ghcr.io/pr0ton11/charts/forgejo
  version: 0.1.0
```

Within the existing `spec.valuesContent`, remove the old `image.tag` override or set it to an empty string:

```yaml
image:
  rootless: true
  tag: ''
```

These snippets are partial changes. Do not replace the full resource or its `valuesContent` with them.
An old `image.fullOverride` or `image.digest` can also prevent the new default image from taking effect.
Preserve the existing image registry and repository unless their current values require a separate change.

Keep the existing release name and target namespace.
Keep the storage claim name, size, storage class, and access modes.
Keep the database, admin credentials, signing keys, OAuth configuration, and network configuration.
Use the controller's source manifest for the migration so that it does not overwrite an independent Helm upgrade.

## Compare before applying

Render the candidate with the existing release's user values in a private local environment.
Apply the image override change to those values before rendering.
Rendered Secret resources contain credentials. Keep them out of Git, logs, and shared diffs.
Compare the old and new resource inventory, Deployment selector, storage references, Services, and routes.
Make sure that every application and init image selects `17.0.1-rootless` for a rootless deployment.

A read-only comparison of the deployed upstream chart `17.1.5` against this chart passed during preparation.
It found the same nine managed resources, with no additions or removals.
The Deployment selector, storage references, security context, replica count, and strategy matched.
The PVC, Service, HTTPRoute, and TCPRoute specifications matched.
The rendered application configuration and admin credentials matched.
The application images changed from `16.0.6-rootless` to `17.0.1-rootless`.
The newer upstream configuration script generates an internal token only when the application supports it.
Repeat this comparison if the deployed configuration changes.

## Verify after an approved deployment

Apply the prepared source manifest only after the backup and comparison pass.
Wait for the Helm controller job and the Forgejo Deployment to complete.
Make sure that the running image and Forgejo API report the intended version.
Check login, OAuth login, repository reads, Git clone and push, SSH, package access, and Actions if enabled.
Review startup logs and run the Forgejo doctor checks from the upgrade guide.
The preparation checks did not apply cluster changes or test the live database migration.
