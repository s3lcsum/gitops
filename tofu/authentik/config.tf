# Non-secret defaults + identity. Provider token: local.secret (ephemeral).
locals {
  cfg = {
    authentik_domain  = "auth.dominiksiejak.pl"
    grafana_cloud_url = "https://dreewniak.grafana.net"
    # is_admin = true -> groups admins + users. Jellyfin OIDC maps those group names (see jellyfin oauth2 comment).
    # welcome_email = false skips the welcome / recovery mail on tofu create (see welcome.tf).
    users = {
      s3lcsum = {
        name     = "Dominik Siejak"
        email    = "dreewniak@gmail.com"
        is_admin = true
        sshPublicKey = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFEYbDbTuiy3jsjMde3gcy1G4jCBwB07ORZizIgaMS+6 id_ed25519 | dreewniak@gmail.com",
        ]
      }
      jasiejek = {
        name         = "Jan Siejak"
        email        = "jasiejek@gmail.com"
        sshPublicKey = []
      }
      kreska_o = {
        name  = "Danuta Siejak"
        email = "null@dominiksiejak.pl"
      }
      oliwkasiejak = {
        name  = "Oliwia Siejak"
        email = "oliwka.siejak@gmail.com"
      }
      as = {
        name  = "Andrzej Siejak"
        email = "andrzej.siejak@post.pl"
      }
      wkrzywonos = {
        name          = "Wiktoria Krzywonos"
        email         = "wiktoriakrzywonos6@gmail.com"
        welcome_email = false
      }
    }
    service_accounts = {}
  }
}
