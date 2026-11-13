# Google OAuth source is disabled: goauthentik/authentik 2026.8.2 has no
# write-only attributes, so consumer_key/consumer_secret cannot take
# local.secret (ephemeral) values. Re-enable once the provider supports them
# (and secret/authentik holds google_client_id + google_client_secret), or
# manage the source outside OpenTofu.
