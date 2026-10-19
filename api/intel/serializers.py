from rest_framework import serializers

from .hashing import HEX64
from .models import Kind
from .packs import known_families, official_domain_hashes


def normalise_district(value: str) -> str:
    return " ".join(value.lower().split())


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
