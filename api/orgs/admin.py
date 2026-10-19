from django.contrib import admin

from .models import Alert, Organization


@admin.register(Organization)
class OrganizationAdmin(admin.ModelAdmin):
    list_display = ("name", "kind", "district", "state", "verified", "active")
    list_filter = ("kind", "verified", "active")
    exclude = ("api_key_hash",)  # never shown; use the createorg command to issue a key
    prepopulated_fields = {"slug": ("name",)}


@admin.register(Alert)
class AlertAdmin(admin.ModelAdmin):
    list_display = ("title", "org", "district", "created", "expires_at")
