# NetBox Configuration Notes

## Overview

NetBox is a powerful IPAM (IP Address Management) and network documentation platform. This deployment is configured for your IPv6-enabled homelab.

## Required Setup

### 1. PostgreSQL Database

NetBox requires a PostgreSQL database. Create the database and user on your PostgreSQL LXC container (`fd89:1::252`):

```sql
-- Connect to PostgreSQL as superuser
CREATE DATABASE netbox;
CREATE USER netbox WITH PASSWORD 'your-secure-password';
GRANT ALL PRIVILEGES ON DATABASE netbox TO netbox;
ALTER USER netbox CREATEDB;
```

### 2. Create Database Secret

Create a secret with your PostgreSQL password:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: netbox-database
  namespace: netbox
type: Opaque
stringData:
  password: "your-postgresql-password-here"
```

### 3. Create Superuser Secret

Create a secret for the NetBox admin user:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: netbox-superuser
  namespace: netbox
type: Opaque
stringData:
  password: "your-admin-password-here"
```

## Access NetBox

After deployment, NetBox will be available at:
- **URL**: https://netbox.wally.dominiksiejak.pl
- **Username**: admin
- **Password**: (from netbox-superuser secret)

## Initial Configuration

### 1. Configure Your IPv6 Networks

Add your homelab IPv6 networks to NetBox:

```
Base Network: fd89::/48
├── Infrastructure: fd89:0::/56
├── Services: fd89:1::/56
├── Compute: fd89:2::/56
├── Containers: fd89:3::/56
└── Applications: fd89:4::/56
```

### 2. Add Device Types

Create device types for your infrastructure:
- **Proxmox Nodes**
- **LXC Containers**
- **Virtual Machines**
- **Network Equipment**

### 3. Add Sites and Racks

Document your physical infrastructure:
- **Site**: Home Lab
- **Racks**: Server rack, network cabinet
- **Locations**: Different rooms/areas

### 4. Add Devices

Document all your devices:
- **Proxmox hosts**
- **Network switches**
- **Router (MikroTik)**
- **NAS (Synology)**

### 5. IP Address Management

Use NetBox to track:
- **Static IP assignments**
- **DHCP ranges**
- **Reserved addresses**
- **DNS records**

## Integration with Your Infrastructure

### External-DNS Integration

NetBox can work with external-dns to automatically update DNS records:

1. **Document services in NetBox**
2. **Use NetBox API to sync with DNS**
3. **Track DNS record assignments**

### Monitoring Integration

Connect NetBox with your monitoring:
- **Export device data to Prometheus**
- **Use NetBox as source of truth for monitoring targets**
- **Track device status and metrics**

## API Usage

NetBox provides a comprehensive REST API:

```bash
# Get all devices
curl -H "Authorization: Token YOUR_API_TOKEN" \
  https://netbox.wally.dominiksiejak.pl/api/dcim/devices/

# Get IP addresses
curl -H "Authorization: Token YOUR_API_TOKEN" \
  https://netbox.wally.dominiksiejak.pl/api/ipam/ip-addresses/
```

## Backup and Maintenance

### Database Backup

Regular PostgreSQL backups are essential:

```bash
# Backup NetBox database
pg_dump -h fd89:1::252 -U netbox netbox > netbox_backup.sql

# Restore from backup
psql -h fd89:1::252 -U netbox netbox < netbox_backup.sql
```

### Media Files

NetBox stores uploaded files in persistent storage. Ensure this volume is backed up.

## Troubleshooting

### Common Issues

1. **Database connection errors**
   - Check PostgreSQL is running on `fd89:1::252:5432`
   - Verify database credentials
   - Check network connectivity

2. **Redis connection errors**
   - Verify Redis pod is running
   - Check Redis service connectivity

3. **Permission errors**
   - Verify database user has correct permissions
   - Check file system permissions for media storage

### Logs

Check NetBox logs:
```bash
kubectl logs -n netbox deployment/netbox -f
kubectl logs -n netbox deployment/netbox-worker -f
```

## Security Considerations

- **Use strong passwords** for admin and database users
- **Enable HTTPS** (configured via Traefik)
- **Regular updates** of NetBox and dependencies
- **API token management** for integrations
- **Network policies** to restrict access

## Useful Features for Homelab

1. **Cable Management**: Document network cables and connections
2. **Power Management**: Track power consumption and PDUs
3. **Custom Fields**: Add homelab-specific metadata
4. **Reports**: Generate network documentation
5. **Webhooks**: Integrate with automation tools
6. **GraphQL API**: Advanced querying capabilities

NetBox will serve as your single source of truth for network documentation and IP address management in your IPv6-enabled homelab.
