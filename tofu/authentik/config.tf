# Non-secret defaults + identity. Provider token: local.secret (ephemeral).
locals {
  cfg = {
    authentik_domain  = "auth.dominiksiejak.pl"
    grafana_cloud_url = "https://dreewniak.grafana.net"
    # jellyfin_role: "admins" | "users" | "kids" -> puts the user in
    # jellyfin-<role> (see local.jellyfin_groups in locals.tf). Omit or null for
    # no Jellyfin access; the plugin is fail-closed, so such a user is denied.
    users = {
      s3lcsum = {
        name          = "Dominik Siejak"
        email         = "dreewniak@gmail.com"
        is_admin      = true
        jellyfin_role = "admins"
        sshPublicKey = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFEYbDbTuiy3jsjMde3gcy1G4jCBwB07ORZizIgaMS+6 id_ed25519 | dreewniak@gmail.com",
        ]
      }
      jasiejek = {
        name          = "Jan Siejak"
        email         = "jasiejek@gmail.com"
        jellyfin_role = "users"
        sshPublicKey  = []
      }
      kreska_o = {
        name          = "Danuta Siejak"
        email         = "null@dominiksiejak.pl"
        jellyfin_role = "users"
      }
      oliwkasiejak = {
        name          = "Oliwia Siejak"
        email         = "oliwka.siejak@gmail.com"
        jellyfin_role = "kids"
      }
      as = {
        name          = "Andrzej Siejak"
        email         = "andrzej.siejak@post.pl"
        jellyfin_role = "users"
      }
    }
    service_accounts = {}
  }
}
