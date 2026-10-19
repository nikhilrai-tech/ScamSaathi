from django.conf import settings
from django.http import HttpResponse
from django.utils.dateparse import parse_datetime
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.throttling import SimpleRateThrottle
from rest_framework.views import APIView

from .hashing import sha256_hex
from .models import Donation, Indicator
from .packs import PackIntegrityError, load_signed_pack
from .serializers import FeedbackSerializer, ReportSerializer
from .services import record_report


class ReportThrottle(SimpleRateThrottle):
    scope = "reports"
    rate = "60/hour"

    def get_cache_key(self, request, view):
        return self.cache_format % {"scope": self.scope, "ident": self.get_ident(request)}


class PublicThrottle(ReportThrottle):
    scope = "public"
    rate = "600/hour"


class PublicView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [PublicThrottle]


def _pack_or_503():
    try:
        return load_signed_pack(), None
    except PackIntegrityError:
        # fail closed, and say nothing about why: a tampered or unsigned pack must never reach a phone
        return None, Response({"detail": "rule pack unavailable"}, status=status.HTTP_503_SERVICE_UNAVAILABLE)


class PackManifestView(PublicView):
    def get(self, request):
        signed, error = _pack_or_503()
        if error:
            return error
        return Response({"name": signed.pack["name"], "version": signed.sig["version"], "sha256": signed.sig["sha256"],
                         "alg": signed.sig["alg"], "key_id": signed.sig["key_id"], "signature": signed.sig["signature"],
                         "url": "/v1/packs/core/pack.json"})


class PackFileView(PublicView):
    def get(self, request):
        signed, error = _pack_or_503()
        if error:
            return error
        resp = HttpResponse(signed.data, content_type="application/json")
        resp["ETag"] = f'"{signed.sig["sha256"]}"'
        resp["Cache-Control"] = "public, max-age=3600"
        return resp


class ReportView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [ReportThrottle]

    def post(self, request):
        ser = ReportSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        d = ser.validated_data
        indicator, created = record_report(d["kind"], d["value_hash"], d["family"], d["reporter_hash"], d["district"])
        return Response({"accepted": True, "new_report": created, "confirmed": indicator.confirmed},
                        status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)


class FeedbackThrottle(ReportThrottle):
    scope = "feedback"
    rate = "20/hour"


class FeedbackView(APIView):
    """Receives a message the app got wrong, only when the person chose to send it. Stores the masked text and a label: nothing else."""
    permission_classes = [AllowAny]
    throttle_classes = [FeedbackThrottle]

    def post(self, request):
        ser = FeedbackSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        d = ser.validated_data
        Donation.objects.get_or_create(text_hash=sha256_hex(d["text"].lower()), defaults={
            "text": d["text"], "label": d["label"], "app_verdict": d["app_verdict"], "family": d["family"], "lang": d["lang"]})
        # always the same answer, so a sender cannot tell whether someone else sent the same message
        return Response({"accepted": True}, status=status.HTTP_201_CREATED)


class FeedView(PublicView):
    """Confirmed indicators as hashes. A phone checks the hashes of what it extracted against this list, offline."""

    def get(self, request):
        qs = Indicator.objects.filter(confirmed=True, revoked=False)
        since = parse_datetime(request.query_params.get("since", "") or "")
        if since is not None:
            qs = qs.filter(confirmed_at__gt=since)
        rows = list(qs.order_by("confirmed_at", "id")[:settings.FEED_PAGE_SIZE + 1])
        more = len(rows) > settings.FEED_PAGE_SIZE
        rows = rows[:settings.FEED_PAGE_SIZE]
        return Response({
            "indicators": [{"kind": r.kind, "hash": r.value_hash, "family": r.family} for r in rows],
            "next_since": rows[-1].confirmed_at.isoformat() if more else None,
        })
