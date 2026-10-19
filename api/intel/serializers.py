from rest_framework import serializers

from .hashing import HEX64
from .masking import mask
from .models import Kind
from .packs import known_families, official_domain_hashes


def normalise_district(value: str) -> str:
    return " ".join(value.lower().split())


class FeedbackSerializer(serializers.Serializer):
    """A message the app got wrong, sent by the person who received it. Masked here again whatever the client did."""
    text = serializers.CharField(min_length=5, max_length=1000, trim_whitespace=True)
    label = serializers.ChoiceField(choices=["scam", "normal"])
    app_verdict = serializers.ChoiceField(choices=["safe", "suspicious", "dangerous"])
    family = serializers.CharField(max_length=32, required=False, allow_blank=True, default="")
    lang = serializers.ChoiceField(choices=["hi", "en"], default="hi")

    def validate_family(self, value):
        if value and value not in known_families():
            raise serializers.ValidationError("unknown scam family")
        return value

    def validate_text(self, value):
        masked = mask(value).strip()
        if len(masked) > 600:
            raise serializers.ValidationError("message is too long (600 characters at most)")
        return masked


class ReportSerializer(serializers.Serializer):
    kind = serializers.ChoiceField(choices=Kind.choices)
    value_hash = serializers.RegexField(HEX64)
    family = serializers.CharField(max_length=32)
    reporter_hash = serializers.RegexField(HEX64)
    district = serializers.RegexField(r"^[A-Za-z0-9 .'-]{0,64}$", required=False, allow_blank=True, default="")

    def validate_family(self, value):
        if value not in known_families():
            raise serializers.ValidationError("unknown scam family")
        return value

    def validate_district(self, value):
        return normalise_district(value)

    def validate(self, attrs):
        if attrs["kind"] == Kind.DOMAIN and attrs["value_hash"] in official_domain_hashes():
            raise serializers.ValidationError({"value_hash": "this is an official bank or government domain"})
        return attrs
