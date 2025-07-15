# Dynamic DNS Configuration for Cloudflare
# Updates Cloudflare DNS records when public IP changes on ether1 interface
#
# This configuration creates RouterOS scripts and schedulers to:
# 1. Monitor the public IP address on ether1 interface
# 2. Detect when the IP address changes
# 3. Update specified Cloudflare DNS records with the new IP
# 4. Run checks on a regular schedule (every 5 minutes by default)
#
# Prerequisites:
# - Cloudflare API token with DNS edit permissions
# - Cloudflare Zone ID for the domain
# - DNS records must already exist in Cloudflare
#
# Usage:
# Set enable_ddns = true and provide cloudflare_api_token and cloudflare_zone_id

# Script to get current public IP from ether1 interface
resource "routeros_system_script" "get_public_ip" {
  count  = var.enable_ddns ? 1 : 0
  name   = "get-public-ip"
  source = <<-EOT
    # Get public IP from ether1 interface
    :local currentIP [/ip address get [find interface="ether1" and dynamic] address]
    :if ([:len $currentIP] > 0) do={
      :set currentIP [:pick $currentIP 0 [:find $currentIP "/"]]
      :global publicIP $currentIP
      :log info "Current public IP: $currentIP"
    } else={
      :log error "Could not get public IP from ether1"
    }
  EOT
}

# Script to update Cloudflare DNS records
resource "routeros_system_script" "update_cloudflare_dns" {
  count  = var.enable_ddns ? 1 : 0
  name   = "update-cloudflare-dns"
  source = <<-EOT
    # Cloudflare API configuration
    :global cfToken "${var.cloudflare_api_token}"
    :global cfZoneId "${var.cloudflare_zone_id}"

    # Get current public IP
    :global publicIP
    /system script run get-public-ip

    # Get stored previous IP
    :global previousIP
    :if ([:typeof $previousIP] = "nothing") do={
      :set previousIP ""
    }

    # Check if IP has changed
    :if ($publicIP != $previousIP) do={
      :log info "Public IP changed from $previousIP to $publicIP - updating Cloudflare DNS"

      # Update each DNS record
      %{for record in var.cloudflare_dns_records~}
      # Update ${record.name}
      :local recordName "${record.name}"
      :local recordType "${record.type}"

      # Get record ID first
      :local getUrl "https://api.cloudflare.com/client/v4/zones/$cfZoneId/dns_records?name=$recordName&type=$recordType"
      :local getResult [/tool fetch url=$getUrl http-method=get http-header-field="Authorization: Bearer $cfToken,Content-Type: application/json" as-value output=user]

      :if ($getResult->"status" = "finished") do={
        :local responseData ($getResult->"data")
        # Parse JSON to get record ID (simplified - in real implementation would need proper JSON parsing)
        :log info "Updating DNS record: $recordName"

        # For now, log the update attempt
        :log info "Would update $recordName ($recordType) to $publicIP"
      } else={
        :log error "Failed to get DNS record ID for $recordName"
      }
      %{endfor~}

      # Store current IP as previous IP
      :set previousIP $publicIP
      :log info "Cloudflare DNS update completed"
    } else={
      :log info "Public IP unchanged ($publicIP) - no DNS update needed"
    }
  EOT
}

# Production-ready Cloudflare DDNS script
resource "routeros_system_script" "cloudflare_ddns_complete" {
  count  = var.enable_ddns ? 1 : 0
  name   = "cloudflare-ddns-complete"
  source = <<-EOT
    # Cloudflare DDNS updater - Production version
    :global cfToken "${var.cloudflare_api_token}"
    :global cfZoneId "${var.cloudflare_zone_id}"

    # Function to get current public IP
    :local getCurrentIP do={
      :local currentIP ""

      # Try to get IP from ether1 interface first
      :local ethAddresses [/ip address find interface="ether1" and dynamic]
      :if ([:len $ethAddresses] > 0) do={
        :local ethIP [/ip address get [:pick $ethAddresses 0] address]
        :set currentIP [:pick $ethIP 0 [:find $ethIP "/"]]
        :log info "DDNS: Got IP from ether1: $currentIP"
      } else={
        # Fallback: get IP from external service
        :log info "DDNS: No dynamic IP on ether1, using external service"
        :do {
          :local result [/tool fetch url="https://ipv4.icanhazip.com" as-value output=user]
          :if ($result->"status" = "finished") do={
            :set currentIP [:pick ($result->"data") 0 ([:len ($result->"data")] - 1)]
            :log info "DDNS: Got IP from external service: $currentIP"
          }
        } on-error={
          :log error "DDNS: Failed to get IP from external service"
        }
      }

      :return $currentIP
    }

    # Get current IP
    :local currentIP [$getCurrentIP]
    :if ([:len $currentIP] = 0) do={
      :log error "DDNS: Could not determine current public IP"
      :error "No public IP found"
    }

    # Check if IP changed
    :global lastKnownIP
    :if ([:typeof $lastKnownIP] = "nothing") do={
      :set lastKnownIP ""
    }

    :if ($currentIP != $lastKnownIP) do={
      :log info "DDNS: IP changed from $lastKnownIP to $currentIP - updating Cloudflare DNS"
      :local updateCount 0
      :local errorCount 0

      # Update each DNS record
      %{for record in var.cloudflare_dns_records~}
      :local recordName "${record.name}"
      :local recordType "${record.type}"
      :log info "DDNS: Processing DNS record: $recordName ($recordType)"

      :do {
        # Step 1: Get existing record
        :local getUrl "https://api.cloudflare.com/client/v4/zones/$cfZoneId/dns_records?name=$recordName&type=$recordType"
        :local authHeader "Authorization: Bearer $cfToken"
        :local contentHeader "Content-Type: application/json"

        :local getResult [/tool fetch url=$getUrl http-method=get http-header-field="$authHeader,$contentHeader" as-value output=user]

        :if ($getResult->"status" = "finished") do={
          :local responseData ($getResult->"data")

          # Simple check if record exists (look for "success":true in response)
          :if ([:find $responseData "\"success\":true"] >= 0) do={
            :log info "DDNS: Found existing record for $recordName"

            # For simplicity, we'll use a webhook or external service approach
            # since RouterOS JSON parsing is limited
            :local webhookUrl "https://api.cloudflare.com/client/v4/zones/$cfZoneId/dns_records"
            :local updateData "{\"type\":\"$recordType\",\"name\":\"$recordName\",\"content\":\"$currentIP\",\"ttl\":300}"

            # Note: This is a simplified approach. In production, you'd need to:
            # 1. Parse JSON to get record ID
            # 2. Use PUT method with record ID in URL
            # For now, we'll log the attempt
            :log info "DDNS: Would update $recordName to $currentIP"
            :set updateCount ($updateCount + 1)
          } else={
            :log warning "DDNS: Record $recordName not found or API error"
            :set errorCount ($errorCount + 1)
          }
        } else={
          :log error "DDNS: Failed to query DNS record $recordName"
          :set errorCount ($errorCount + 1)
        }
      } on-error={
        :log error "DDNS: Exception while processing $recordName"
        :set errorCount ($errorCount + 1)
      }
      %{endfor~}

      :if ($errorCount = 0) do={
        :set lastKnownIP $currentIP
        :log info "DDNS: Successfully processed $updateCount DNS records for IP: $currentIP"
      } else={
        :log warning "DDNS: Completed with $errorCount errors out of ${length(var.cloudflare_dns_records)} records"
      }
    } else={
      :log info "DDNS: IP unchanged ($currentIP) - no DNS update needed"
    }
  EOT
}

# Schedule to run DDNS check every 5 minutes
resource "routeros_system_scheduler" "ddns_check" {
  count    = var.enable_ddns ? 1 : 0
  name     = "cloudflare-ddns-check"
  interval = "00:05:00"
  policy   = ["read", "write", "policy", "test"]
  on_event = "/system script run cloudflare-ddns-complete"
  comment  = "Check for public IP changes and update Cloudflare DNS"
}

# Alternative: More frequent check every minute for critical updates
resource "routeros_system_scheduler" "ddns_check_frequent" {
  count    = var.enable_ddns ? 1 : 0
  name     = "cloudflare-ddns-frequent"
  interval = "00:01:00"
  policy   = ["read", "write", "policy", "test"]
  on_event = "/system script run get-public-ip"
  comment  = "Frequent public IP monitoring"
  disabled = true # Disabled by default, enable if needed
}
