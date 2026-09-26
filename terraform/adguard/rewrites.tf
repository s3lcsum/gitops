resource "adguard_rewrite" "this" {
  for_each = local.rewrites

  domain  = each.key
  answer  = each.value
  enabled = true
}
