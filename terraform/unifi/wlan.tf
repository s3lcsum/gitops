# Desired WLAN layout (imported from live controller).
# Passphrases from defaults.auto.tfvars (sourced from 1Password).

resource "unifi_wlan" "hass" {
  name       = "Hass"
  passphrase = var.wlan_passphrase_hass
  security   = "wpapsk" # WPA2-PSK; provider value (not "wpa2")
  enabled    = true
  is_guest   = false
  # Hidden SSID — clients must know name (Zigbee bridge / IoT)
  hide_ssid = true

  # 2.4 GHz only — Zigbee Wi‑Fi bridge; do not enable 5g here
  wlan_band  = "2g"
  wlan_bands = ["2g"]

  # UniFi IoT profile: WPA2 only, PMF off, DTIM 1, no WPA3. Stability over features.
  enhanced_iot = true

  network_id    = data.unifi_network.lan.id
  user_group_id = local.user_group_id # Default user group (controller built-in)
  # Broadcast on every AP in "All APs" group
  ap_group_ids  = [data.unifi_ap_group.all.id]
  ap_group_mode = "all"

  # 0 = no periodic GTK rekey. Hourly rekey drops sleepy IoT stations.
  group_rekey = 0
  # "manual" = use minimum_data_rate_*; "auto" = controller picks floors.
  minrate_setting_preference = "manual"
  # Floor, not a cap. 1000 = 1 Mbps so the bridge can fall back to the most robust rate.
  minimum_data_rate_2g_kbps = 1000
  # Still required by provider even on 2g-only SSIDs (5g floor unused here).
  minimum_data_rate_5g_kbps = 6000

  lifecycle {
    ignore_changes = [
      bandsteering_mode,    # prefer_5g / equal — N/A on 2g-only
      pmf_mode,             # 802.11w management frame protection
      no2ghz_oui,           # block legacy 2.4 OUI clients
      bss_transition,       # 802.11v BSS transition
      multicast_enhance,    # convert multicast→unicast
      uapsd,                # unscheduled APSD power-save
      proxy_arp,            # AP answers ARP for clients
      fast_roaming_enabled, # 802.11r
      wpa3_support,
      wpa3_transition,
      mac_filter,    # allow/deny list block
      passphrase_wo, # provider write-only twin of passphrase
    ]
  }
}

resource "unifi_wlan" "raval" {
  name       = "Raval"
  passphrase = var.wlan_passphrase_raval
  security   = "wpapsk"
  enabled    = true
  is_guest   = false
  hide_ssid  = false # visible in scans

  # 5 GHz only — main client Wi‑Fi
  wlan_band  = "5g"
  wlan_bands = ["5g"]

  network_id    = data.unifi_network.lan.id
  user_group_id = local.user_group_id
  ap_group_ids  = [data.unifi_ap_group.all.id]
  ap_group_mode = "all"

  # 0 = no periodic GTK rekey (live value)
  group_rekey = 0
  # Keep controller auto rate floors; rates below are ignored.
  minrate_setting_preference = "auto"
  minimum_data_rate_2g_kbps  = 1000
  minimum_data_rate_5g_kbps  = 6000 # 6 Mbps typical 5g floor

  lifecycle {
    ignore_changes = [
      bandsteering_mode,
      pmf_mode,
      no2ghz_oui,
      bss_transition,
      multicast_enhance,
      uapsd,
      proxy_arp,
      fast_roaming_enabled,
      wpa3_support,
      wpa3_transition,
      mac_filter,
      passphrase_wo,
      minrate_setting_preference,
      minimum_data_rate_2g_kbps,
      minimum_data_rate_5g_kbps,
      group_rekey,
    ]
  }
}
