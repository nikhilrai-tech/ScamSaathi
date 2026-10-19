from django.contrib import admin

from .models import Donation, Indicator, Report


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


@admin.action(description="Accept (may be used to train and test)")
def accept(modeladmin, request, queryset):
    queryset.update(status=Donation.Status.ACCEPTED)


@admin.action(description="Reject (keep out of training; delete later)")
def reject(modeladmin, request, queryset):
    queryset.update(status=Donation.Status.REJECTED)


@admin.register(Donation)
class DonationAdmin(admin.ModelAdmin):
    """Read each message before accepting it: remove anything that still identifies a person, and reject anything that does."""
    list_display = ("created", "label", "app_verdict", "family", "lang", "status", "short")
    list_filter = ("status", "label", "app_verdict", "lang")
    actions = [accept, reject]
    readonly_fields = ("text_hash", "created")

    @admin.display(description="text")
    def short(self, obj):
        return obj.text[:80]
