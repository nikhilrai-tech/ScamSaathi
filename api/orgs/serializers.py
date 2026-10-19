import re

from rest_framework import serializers

from intel.packs import known_families

LINKISH = re.compile(r"https?:|www\.|://|\b[a-z0-9-]+\.(?:com|in|org|net|xyz|top|click|icu|site|online|link|info|app|cc|me|co|shop|vip|club|buzz|apk)\b", re.I)


def no_links(value: str) -> str:
    """Alerts reach many people we cannot vet one by one, so an alert must never be a vehicle for a link."""
    if LINKISH.search(value):
        raise serializers.ValidationError("alerts cannot contain links or web addresses")
    return value


class AlertCreateSerializer(serializers.Serializer):
    title = serializers.CharField(max_length=120, validators=[no_links])
    body_en = serializers.CharField(max_length=600, validators=[no_links])
    body_hi = serializers.CharField(max_length=600, validators=[no_links])
    family = serializers.CharField(max_length=32, required=False, allow_blank=True, default="")
    days = serializers.IntegerField(min_value=1, max_value=30, default=7)

    def validate_family(self, value):
        if value and value not in known_families():
            raise serializers.ValidationError("unknown scam family")
        return value


class AlertPublicSerializer(serializers.Serializer):
    title = serializers.CharField()
    body_en = serializers.CharField()
    body_hi = serializers.CharField()
    family = serializers.CharField()
    district = serializers.CharField()
    organisation = serializers.CharField(source="org.name")
    created = serializers.DateTimeField()
    expires_at = serializers.DateTimeField()
