locals {
  # PKI Configuration
  pki = {
    root_ca = {
      common_name = "DominikSiejak Root CA"
      ttl         = 262800
    }
    intermediate_ca = {
      common_name = "DominikSiejak Intermediate CA"
      ttl         = 300
    }
    allowed_domains = [
      "lake.dominiksiejak.pl",
      "hello.dominiksiejak.pl",
      "atom.dominiksiejak.pl",
      "dominiksiejak.pl",
      "local"
    ]
    default_ttl = 720
    max_ttl     = 17280
  }

  databases = {
    n8n = {
      database = "n8n_db"
      username = "n8n_user"
    }
    netbox = {
      database = "netbox_db"
      username = "netbox_user"
    }
    authentik = {
      database = "authentik_db"
      username = "authentik_user"
    }
    uptime_kuma = {
      database = "uptime_kuma_db"
      username = "uptime_kuma_user"
    }
    watchyourlan = {
      database = "watchyourlan_db"
      username = "watchyourlan_user"
    }
    warracker = {
      database = "warracker_db"
      username = "warracker_user"
    }
    vaultwarden = {
      database = "vaultwarden_db"
      username = "vaultwarden_user"
    }
  }
}

