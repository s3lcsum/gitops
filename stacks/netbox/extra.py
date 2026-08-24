####
## This file contains extra configuration options that can't be configured
## directly through environment variables.
####

import sys
sys.path.insert(0, '/etc/netbox/config/')

## Specify one or more name and email address tuples representing NetBox administrators. These people will be notified of
## application errors (assuming correct email settings are available).
# ADMINS = [
#     # ['John Doe', 'jdoe@example.com'],
# ]


## URL schemes that are allowed within links in NetBox
# ALLOWED_URL_SCHEMES = (
#     'file', 'ftp', 'ftps', 'http', 'https', 'irc', 'mailto', 'sftp', 'ssh', 'tel', 'telnet', 'tftp', 'vnc', 'xmpp',
# )

## Enable installed plugins. Add the name of each plugin to the list.
# from netbox.configuration.configuration import PLUGINS
# PLUGINS.append('my_plugin')

## Plugins configuration settings. These settings are used by various plugins that the user may have installed.
## Each key in the dictionary is the name of an installed plugin and its value is a dictionary of settings.
# from netbox.configuration.configuration import PLUGINS_CONFIG
# PLUGINS_CONFIG['my_plugin'] = {
#   'foo': 'bar',
#   'buzz': 'bazz'
# }


## Remote authentication support
# REMOTE_AUTH_DEFAULT_PERMISSIONS = {}


## OIDC group mapping pipeline
def extract_groups_from_oidc(backend, details, response, *args, **kwargs):
    """Extract groups from OIDC token and map to NetBox groups."""
    from users.models.users import Group

    groups = response.get('groups', [])
    if not groups:
        return

    user = kwargs.get('user')
    if not user:
        return

    # Map Authentik groups to NetBox groups
    netbox_groups = []
    for group_name in groups:
        group, created = Group.objects.get_or_create(name=group_name)
        netbox_groups.append(group)

    # Set user groups
    user.groups.set(netbox_groups)

    # Check if user should be superuser
    if 'admins' in groups:
        user.is_superuser = True
        user.is_staff = True
        user.save()


def set_oidc_username(strategy, details, response, user=None, *args, **kwargs):
    """Use preferred_username from OIDC claims as the NetBox username."""
    preferred = response.get('preferred_username') or response.get('email', '').split('@')[0]
    if preferred:
        details['username'] = preferred

    # Map name claims
    details['first_name'] = response.get('given_name', '')
    details['last_name'] = response.get('family_name', '')


SOCIAL_AUTH_PIPELINE = (
    'social_core.pipeline.social_auth.social_details',
    'social_core.pipeline.social_auth.social_uid',
    'social_core.pipeline.social_auth.auth_allowed',
    'social_core.pipeline.social_auth.social_user',
    'extra.set_oidc_username',  # Set username from preferred_username claim
    'social_core.pipeline.user.get_username',
    'social_core.pipeline.user.create_user',
    'social_core.pipeline.social_auth.associate_user',
    'social_core.pipeline.social_auth.load_extra_data',
    'social_core.pipeline.user.user_details',
    'extra.extract_groups_from_oidc',  # Custom group mapping
)


## By default uploaded media is stored on the local filesystem. Using Django-storages is also supported. Provide the
## class path of the storage driver and any configuration options in STORAGES. For example:
# STORAGES = {
#     'default': {
#         'BACKEND': 'storages.backends.s3boto3.S3Boto3Storage',
#         'OPTIONS': {
#             'access_key': 'Key ID',
#             'secret_key': 'Secret',
#             'bucket_name': 'netbox',
#             'region_name': 'us-west-2',
#         }
#     },
#     'staticfiles': {
#         'BACKEND': 'django.contrib.staticfiles.storage.StaticFilesStorage',
#     }
# }


## This file can contain arbitrary Python code, e.g.:
# from datetime import datetime
# now = datetime.now().strftime("%d/%m/%Y %H:%M:%S")
# BANNER_TOP = f'<marquee width="200px">This instance started on {now}.</marquee>'
