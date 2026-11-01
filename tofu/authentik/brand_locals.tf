locals {
  slab_brand_media = "/media/public/slab"
  # Relative to media/public/ — required for brand logo/favicon/flow bg (2025.12+ file picker).
  slab_brand_prefix = "slab"
  # Public URL for email HTML only (Authentik no longer serves /media/public/* without tokens).
  slab_brand_email_url = "https://raw.githubusercontent.com/s3lcsum/gitops/main/kubernetes/platform/authentik/resources/brand-assets"

  # Inbox sender + subjects (SMTP address stays in OpenBao secret/authentik).
  email_from_address  = "root@mail.dominiksiejak.pl"
  email_from_display  = "HomeLab Authentik"
  email_subject_brand = "HomeLab Authentik"
}
