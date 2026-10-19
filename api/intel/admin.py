from django.contrib import admin

from .models import Indicator, Report


@admin.action(description="Revoke (never serve; use after review or an appeal)")
def revoke(modeladmin, request, queryset):
    queryset.update(revoked=True, confirmed=False)


@admin.register(Indicator)
class IndicatorAdmin(admin.ModelAdmin):
    list_display = ("kind", "value_hash", "family", "reporter_weight", "confirmed", "revoked", "last_seen")
    list_filter = ("kind", "family", "confirmed", "revoked")
    actions = [revoke]


@admin.register(Report)
class ReportAdmin(admin.ModelAdmin):
    list_display = ("indicator", "district", "created")
