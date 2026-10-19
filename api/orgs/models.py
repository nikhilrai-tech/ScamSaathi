from django.db import models


class Organization(models.Model):
    """A school, farmer-producer organisation, cooperative bank or NGO. Only the hash of its API key is stored."""

    class Kind(models.TextChoices):
        SCHOOL = "school"
        FPO = "fpo"
        COOP_BANK = "coop_bank"
        NGO = "ngo"
        OTHER = "other"

    name = models.CharField(max_length=120)
    slug = models.SlugField(unique=True)
    kind = models.CharField(max_length=16, choices=Kind.choices, default=Kind.OTHER)
    state = models.CharField(max_length=64, blank=True)
    district = models.CharField(max_length=64, help_text="Lowercase. Alerts and the dashboard are scoped to it.")
    verified = models.BooleanField(default=False, help_text="Checked by a maintainer. Only verified organisations can publish alerts or confirm indicators.")
    active = models.BooleanField(default=True)
    api_key_hash = models.CharField(max_length=64, unique=True)
    created = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name


class Alert(models.Model):
    org = models.ForeignKey(Organization, on_delete=models.CASCADE, related_name="alerts")
    title = models.CharField(max_length=120)
    body_en = models.TextField(max_length=600)
    body_hi = models.TextField(max_length=600)
    family = models.CharField(max_length=32, blank=True)
    district = models.CharField(max_length=64)
    created = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(db_index=True)
