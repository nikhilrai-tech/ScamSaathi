from rest_framework.authentication import BaseAuthentication, get_authorization_header
from rest_framework.exceptions import AuthenticationFailed
from rest_framework.permissions import BasePermission

from intel.hashing import sha256_hex

from .models import Organization


class OrgPrincipal:
    is_authenticated = True

    def __init__(self, org):
        self.org = org


class ApiKeyAuthentication(BaseAuthentication):
    """Authorization: Api-Key <key>. Keys are random, long and stored only as a SHA-256 hash."""
    keyword = "Api-Key"

    def authenticate(self, request):
        parts = get_authorization_header(request).decode("latin-1").split()
        if not parts or parts[0].lower() != self.keyword.lower():
            return None
        if len(parts) != 2:
            raise AuthenticationFailed("Invalid API key")
        org = Organization.objects.filter(api_key_hash=sha256_hex(parts[1]), active=True).first()
        if org is None:
            raise AuthenticationFailed("Invalid API key")
        return OrgPrincipal(org), None

    def authenticate_header(self, request):
        return self.keyword


class IsOrg(BasePermission):
    def has_permission(self, request, view):
        return isinstance(request.user, OrgPrincipal)


class IsVerifiedOrg(IsOrg):
    message = "Your organisation has not been verified yet."

    def has_permission(self, request, view):
        return super().has_permission(request, view) and request.user.org.verified
