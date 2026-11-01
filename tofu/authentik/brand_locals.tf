locals {
  slab_brand_media = "/media/public/slab"
  slab_brand_url   = "https://${local.cfg.authentik_domain}${local.slab_brand_media}"

  # Inbox sender + subjects (SMTP address stays in OpenBao secret/authentik).
  email_from_address  = "root@mail.dominiksiejak.pl"
  email_from_display  = "HomeLab Authentik"
  email_subject_brand = "HomeLab Authentik"

  slab_flow_background = "slabi-flow-lilac.jpg"
}
