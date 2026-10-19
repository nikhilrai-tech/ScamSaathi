from datetime import timedelta

from django.conf import settings
from django.db.models import Count
from django.utils import timezone
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from intel.models import Report
from intel.serializers import ReportSerializer, normalise_district
from intel.hashing import sha256_hex
from intel.services import record_report
from intel.views import PublicView, ReportThrottle

from .auth import ApiKeyAuthentication, IsOrg, IsVerifiedOrg
from .models import Alert
from .serializers import AlertCreateSerializer, AlertPublicSerializer


class OrgView(APIView):
    authentication_classes = [ApiKeyAuthentication]
    permission_classes = [IsOrg]
    throttle_classes = [ReportThrottle]


class OrgAlertsView(OrgView):
    def get_permissions(self):
        return [IsVerifiedOrg()] if self.request.method == "POST" else [IsOrg()]

    def get(self, request):
        alerts = Alert.objects.filter(org=request.user.org).order_by("-created")[:50]
        return Response(AlertPublicSerializer(alerts, many=True).data)

    def post(self, request):
        ser = AlertCreateSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        d, org = ser.validated_data, request.user.org
        alert = Alert.objects.create(org=org, title=d["title"], body_en=d["body_en"], body_hi=d["body_hi"],
                                     family=d["family"], district=org.district,
                                     expires_at=timezone.now() + timedelta(days=d["days"]))
        return Response(AlertPublicSerializer(alert).data, status=status.HTTP_201_CREATED)


class OrgReportView(OrgView):
    """A verified organisation's report confirms the indicator at once (it counts as the whole quorum)."""
    permission_classes = [IsVerifiedOrg]

    def post(self, request):
        data = {**request.data, "reporter_hash": sha256_hex("org:" + request.user.org.slug)}
        ser = ReportSerializer(data=data)
        ser.is_valid(raise_exception=True)
        d = ser.validated_data
        indicator, created = record_report(d["kind"], d["value_hash"], d["family"], d["reporter_hash"],
                                           request.user.org.district, weight=settings.REPORT_QUORUM)
        return Response({"accepted": True, "confirmed": indicator.confirmed},
                        status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)


class DashboardView(OrgView):
    """What confirmed scams were reported in the organisation's own district in the last 30 days, by family."""

    def get(self, request):
        org = request.user.org
        since = timezone.now() - timedelta(days=30)
        rows = (Report.objects.filter(indicator__confirmed=True, indicator__revoked=False,
                                      district=normalise_district(org.district), created__gte=since)
                .values("indicator__family").annotate(n=Count("indicator", distinct=True)))
        return Response({
            "organisation": org.name, "district": org.district, "days": 30,
            "confirmed_indicators_by_family": {r["indicator__family"]: r["n"] for r in rows},
            "active_alerts": Alert.objects.filter(org=org, expires_at__gt=timezone.now()).count(),
        })


class PublicAlertsView(PublicView):
    def get(self, request):
        district = normalise_district(request.query_params.get("district", ""))
        if not district:
            return Response({"detail": "district is required"}, status=status.HTTP_400_BAD_REQUEST)
        alerts = (Alert.objects.filter(district__iexact=district, expires_at__gt=timezone.now(), org__verified=True,
                                       org__active=True).select_related("org").order_by("-created")[:20])
        return Response(AlertPublicSerializer(alerts, many=True).data)
