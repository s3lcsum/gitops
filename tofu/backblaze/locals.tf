locals {
  buckets = [
    {
      app      = "hass"
      instance = "atom-1"
      purpose  = "backups"
    },
    {
      app      = "hass"
      instance = "lake-1"
      purpose  = "backups"
    },
  ]

  bucket_map = {
    for bucket in local.buckets : "dominiksiejak-${bucket.app}-${bucket.instance}-${bucket.purpose}" => bucket
  }
}
