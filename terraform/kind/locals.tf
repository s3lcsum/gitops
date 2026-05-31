locals {
  clusters = {
    local = {
      name = "local"
    }
    hermes = {
      name = "hermes"
    }
  }

  cluster = local.clusters[var.cluster_target]
}
