from datetime import timedelta

from django.core.management.base import BaseCommand
from django.utils import timezone

from intel.models import Donation


class Command(BaseCommand):
    help = ("Delete donated messages that should not be kept: rejected ones, and ones nobody reviewed within --unreviewed-days. "
            "Accepted messages are never touched. Run it regularly (see docs/DEPLOY.md): this is the data retention rule.")

    def add_arguments(self, parser):
        parser.add_argument("--unreviewed-days", type=int, default=30)
        parser.add_argument("--dry-run", action="store_true")

    def handle(self, *args, **o):
        cutoff = timezone.now() - timedelta(days=o["unreviewed_days"])
        rejected = Donation.objects.filter(status=Donation.Status.REJECTED)
        stale = Donation.objects.filter(status=Donation.Status.NEW, created__lt=cutoff)
        n_rejected, n_stale = rejected.count(), stale.count()
        if not o["dry_run"]:
            rejected.delete()
            stale.delete()
        verb = "would delete" if o["dry_run"] else "deleted"
        self.stdout.write(f"{verb} {n_rejected} rejected and {n_stale} unreviewed (older than {o['unreviewed_days']} days) messages. Accepted ones are kept.")
