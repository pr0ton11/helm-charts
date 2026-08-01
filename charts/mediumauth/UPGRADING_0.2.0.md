# Upgrade Mediumauth to v0.2.0

Mediumauth v0.2.0 moves administrator-managed configuration into an encrypted database document.
This upgrade requires a stable configuration encryption key.

CAUTION: Do not generate a new key during a normal Helm upgrade.
A new key cannot decrypt the stored configuration document.

## Upgrade procedure

1. Back up the Mediumauth database.
2. Generate the encryption key:

   ```console
   openssl rand -base64 32
   ```

3. Store the exact output in a Kubernetes Secret:

   ```console
   kubectl create secret generic mediumauth-config \
     --from-literal='TINYAUTH_CONFIG_ENCRYPTION_KEY=REPLACE_WITH_OPENSSL_OUTPUT'
   ```

4. Configure the chart to use this Secret:

   ```yaml
   configEncryptionKey:
     existingSecret: mediumauth-config
     existingSecretKey: TINYAUTH_CONFIG_ENCRYPTION_KEY
   ```

5. Keep the existing managed environment or YAML values in the deployment.
6. Upgrade Mediumauth to v0.2.0 once.
7. Make sure that the pod becomes ready through `/api/readyz`.
8. Open `/admin` and make sure that the imported configuration is correct.

When the database has no managed configuration, Mediumauth imports the legacy values.
After a successful import, the database document is authoritative.

You can remove the legacy managed values during a later deployment change.
Removing these values does not delete the database-managed configuration.

## Rotate the key

Do not implement key rotation as a Helm upgrade.
Use the offline rotation command.

1. Stop all Mediumauth replicas.
2. Generate a new key with `openssl rand -base64 32`.
3. Run this command against the configured database:

   ```console
   TINYAUTH_CONFIG_ENCRYPTION_KEY="$OLD_KEY" \
   TINYAUTH_CONFIG_NEW_ENCRYPTION_KEY="$NEW_KEY" \
   tinyauth configuration rotate-key
   ```

4. Update the Kubernetes Secret before you restart Mediumauth.
5. Restart all Mediumauth replicas with the new key.
