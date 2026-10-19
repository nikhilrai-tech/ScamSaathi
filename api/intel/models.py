from django.db import models


class Kind(models.TextChoices):
    DOMAIN = "domain"
    UPI = "upi"
    APK = "apk_sha256"


class Indicator(models.Model):
    """One scam indicator, known only by its hash. Confirmed by a quorum of reporters or by a verified organisation."""
    kind = models.CharField(max_length=16, choices=Kind.choices)
    value_hash = models.CharField(max_length=64)
    family = models.CharField(max_length=32)
    reporter_weight = models.PositiveIntegerField(default=0)
    confirmed = models.BooleanField(default=False)
    revoked = models.BooleanField(default=False, help_text="Set by an admin after review or an appeal. Never served.")
    first_seen = models.DateTimeField(auto_now_add=True)
    last_seen = models.DateTimeField(auto_now=True)
    confirmed_at = models.DateTimeField(null=True, blank=True, db_index=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["kind", "value_hash"], name="uniq_indicator")]

    def __str__(self):
        return f"{self.kind}:{self.value_hash[:10]}… ({self.family})"


class Report(models.Model):
    """Who reported (as a hash of a random install id, never a phone number) and in which district. No message text."""
    indicator = models.ForeignKey(Indicator, on_delete=models.CASCADE, related_name="reports")
    reporter_hash = models.CharField(max_length=64)
    district = models.CharField(max_length=64, blank=True)
    created = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["indicator", "reporter_hash"], name="uniq_report")]


class Donation(models.Model):
    """A message a person chose to send because the app got it wrong. Personal details are masked before it is stored. It carries no
    account, device, IP address or reporter id: the person cannot be traced from it, and so cannot later ask for it to be deleted."""

    class Label(models.TextChoices):
        SCAM = "scam", "It is a scam"
        NORMAL = "normal", "It is a normal message"

    class Status(models.TextChoices):
        NEW = "new"
        ACCEPTED = "accepted"
        REJECTED = "rejected"

    text = models.TextField(max_length=600)
    text_hash = models.CharField(max_length=64, unique=True, help_text="SHA-256 of the masked text, to drop duplicates")
    label = models.CharField(max_length=8, choices=Label.choices)
    app_verdict = models.CharField(max_length=12, help_text="What the app said: safe, suspicious or dangerous")
    family = models.CharField(max_length=32, blank=True)
    lang = models.CharField(max_length=2, default="hi")
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.NEW)
    created = models.DateTimeField(auto_now_add=True)
