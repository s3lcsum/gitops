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
      username = "n8n_user"
      database = "n8n_db"
    }
    watchyourlan = {
      username = "watchyourlan_user"
      database = "watchyourlan_db"
    }
    vaultwarden = {
      username = "vaultwarden_user"
      database = "vaultwarden_db"
    }
    gitea = {
      username = "gitea_user"
      database = "gitea_db"
    }
    authentik = {
      username = "authentik_user"
      database = "authentik_db"
    }
    netbox = {
      username = "netbox_user"
      database = "netbox_db"
    }
    warracker = {
      username = "warracker_user"
      database = "warracker_db"
    }
    backstage = {
      username = "backstage_user"
      database = "backstage_db"
    }
    firefly = {
      username = "firefly_user"
      database = "firefly_db"
    }
    gatus = {
      username = "gatus_user"
      database = "gatus_db"
    }
  }
}
