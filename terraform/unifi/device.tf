# U7 Lite — settable fields pinned to live controller values.
# Device SSH: var.device_ssh_* (1Password "UniFi | device-ssh"); provider cannot set SSH password.

resource "unifi_device" "u7_lite" {
  # Hardware identity — required by provider (not optional inventory fluff).
  mac  = "1c:0b:8b:f2:dc:a7"
  name = "U7 Lite"

  allow_adoption = true
  # false = tofu destroy drops TF state only; AP stays adopted on controller.
  forget_on_destroy = false

  disabled = false
  # Switch-oriented; no-ops on a pure AP but pinned to live values.
  flowctrl_enabled   = false
  jumboframe_enabled = false
  locked             = false
  # Wireless uplink / mesh STA VAP — off (AP is wired).
  mesh_sta_vap_enabled = false
  # PDU/outlet features — N/A on U7 Lite.
  outlet_enabled = false
  # Switch VLAN mode — N/A on UAP.
  switch_vlan_enabled = false
  # "default" = indoor; "on" forces outdoor power/DFS profile.
  outdoor_mode_override = "default"

  # LED: "on" | "off" | "default" (follow site setting).
  led_override                  = "off"
  led_override_color            = "#0000ff"
  led_override_color_brightness = 100

  # Which UniFi LAN object this AP is attached to (Default network).
  mgmt_network_id = data.unifi_network.lan.id

  # How the AP gets its OWN management IP — NOT "UniFi DHCP server on/off".
  # type = "dhcp"  → AP is a DHCP client (RouterOS hands out 192.168.89.105).
  # type = "static" → would need ip/netmask/gateway here instead.
  # Real LAN DHCP server = RouterOS; UniFi gateway DHCP is irrelevant (no USG/UDM).
  config_network = {
    type            = "dhcp"
    bonding_enabled = false # dual-WAN bonding; N/A on single-homed AP
  }

  # Radios: wifi0 = 2.4 (ng), wifi1 = 5 (na). 2.4 is Hass-only, locked to 20 MHz.
  radio_table = [
    {
      name  = "wifi0"
      radio = "ng" # 2.4 GHz
      # "auto" or concrete channel number as string
      channel       = "auto"
      ht            = 20     # 20 MHz only — Hass/IoT. 40 MHz overlaps neighbors and is less stable.
      tx_power_mode = "high" # "auto" | "low" | "medium" | "high" | "custom"
      antenna_gain  = 4      # dBi; match hardware
      antenna_id    = -1     # -1 = combined/default antenna
      # DFS radar avoidance — mainly 5 GHz; leave false on 2.4
      dfs                      = false
      vwire_enabled            = true  # wireless uplink / mesh backhaul VAP
      min_rssi_enabled         = false # kick weak clients if true + min_rssi set
      sens_level_enabled       = false # receiver sensitivity clamp
      hard_noise_floor_enabled = false
      loadbalance_enabled      = false # steer clients across APs by load
      assisted_roaming_enabled = false # 802.11k/v assist
    },
    {
      name                     = "wifi1"
      radio                    = "na" # 5 GHz
      channel                  = "auto"
      ht                       = 160 # 80/160 on Wi‑Fi 6E/7 capable AP
      tx_power_mode            = "high"
      antenna_gain             = 5
      antenna_id               = -1
      dfs                      = false
      vwire_enabled            = true
      min_rssi_enabled         = false
      sens_level_enabled       = false
      hard_noise_floor_enabled = false
      loadbalance_enabled      = false
      assisted_roaming_enabled = false
    },
  ]

  lifecycle {
    ignore_changes = [
      # Provider-computed / N/A on UAP (switch/LCM/PoE/STP/phone)
      bandsteering_mode,
      lcm_brightness,
      lcm_brightness_override,
      lcm_idle_timeout,
      lcm_idle_timeout_override,
      lcm_night_mode_begins,
      lcm_night_mode_ends,
      poe_mode,
      stp_priority,
      stp_version,
      volume,
      x_baresip_password,
      # DHCP-learned ip/gateway/dns under config_network (client lease details)
      config_network,
    ]
  }
}
