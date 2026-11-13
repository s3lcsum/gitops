resource "vault_policy" "admin" {
  name = "admin"

  policy = <<-EOT
    path "*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
  EOT
}

resource "vault_policy" "eso_read" {
  name = "eso-read"

  policy = <<-EOT
    path "secret/data/*" {
      capabilities = ["read", "list"]
    }
    path "secret/metadata/*" {
      capabilities = ["read", "list"]
    }
    # CA PEMs only. ESO distributes the trust bundle; it must never mint leaves.
    path "pki_root/cert/ca" {
      capabilities = ["read"]
    }
    path "pki_int_servers/cert/ca" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_policy" "client_read" {
  name = "client-read"

  policy = <<-EOT
    path "secret/data/*" {
      capabilities = ["read", "list"]
    }
    path "secret/metadata/*" {
      capabilities = ["read", "list"]
    }
  EOT
}

resource "vault_policy" "terraform" {
  name = "terraform"

  policy = <<-EOT
    path "*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
  EOT
}

resource "vault_policy" "pki_cert_manager" {
  name = "pki-cert-manager"

  policy = <<-EOT
    path "pki_int_servers/sign/server-dns" {
      capabilities = ["create", "update"]
    }
    path "pki_int_servers/issue/server-dns" {
      capabilities = ["create", "update"]
    }
    path "pki_int_servers/sign/server-internal" {
      capabilities = ["create", "update"]
    }
    path "pki_int_servers/issue/server-internal" {
      capabilities = ["create", "update"]
    }
    path "pki_int_servers/ca" {
      capabilities = ["read"]
    }
    path "pki_int_servers/ca_chain" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_policy" "pki_operator" {
  name = "pki-operator"

  policy = <<-EOT
    path "pki_int_servers/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
    path "pki_int_clients/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
    path "pki_root/cert/*" {
      capabilities = ["read", "list"]
    }
    path "pki_root/ca" {
      capabilities = ["read"]
    }
  EOT
}
