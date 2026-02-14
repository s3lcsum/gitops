resource "gitea_org" "organizations" {
  for_each = local.organizations

  name       = each.value.name
  visibility = "public"
}

resource "gitea_repository" "mirrors" {
  for_each = local.mirrors

  username = split("/", each.key)[0]
  name     = split("/", each.key)[1]

  private = false

  mirror                  = true
  migration_clone_address = each.value.clone_url
  migration_service       = "git"

  depends_on = [gitea_org.organizations]
}
