locals {
  slab_brand_media = "/media/public/slab"
  slab_brand_url   = "https://${local.cfg.authentik_domain}${local.slab_brand_media}"
}
