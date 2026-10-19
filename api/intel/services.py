from django.conf import settings
from django.db import transaction
from django.utils import timezone

from .models import Indicator, Report


@transaction.atomic
def record_report(kind, value_hash, family, reporter_hash, district="", weight=1):
    """Count one report. The same reporter counts once. An indicator is confirmed when the summed weight reaches the quorum.
    The first report decides the family; later reports with another family do not change it."""
    indicator, _ = Indicator.objects.get_or_create(kind=kind, value_hash=value_hash, defaults={"family": family})
    _, created = Report.objects.get_or_create(indicator=indicator, reporter_hash=reporter_hash,
                                              defaults={"district": district})
    if created:
        indicator.reporter_weight += weight
    if not indicator.confirmed and not indicator.revoked and indicator.reporter_weight >= settings.REPORT_QUORUM:
        indicator.confirmed = True
        indicator.confirmed_at = timezone.now()
    indicator.save()
    return indicator, created
