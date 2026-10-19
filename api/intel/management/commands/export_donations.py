import json

from django.core.management.base import BaseCommand

from intel.models import Donation


class Command(BaseCommand):
    help = ("Write accepted donated messages as JSON lines in the same format as packs/core/*.jsonl, for evaluating and training on "
            "YOUR machine. Never commit the output: it is real people's data, even after masking.")

    def add_arguments(self, parser):
        parser.add_argument("--out", required=True)
        parser.add_argument("--status", default="accepted", choices=["new", "accepted", "rejected"])

    def handle(self, *args, **o):
        n = 0
        with open(o["out"], "w", encoding="utf-8") as f:
            for d in Donation.objects.filter(status=o["status"]).order_by("id"):
                label = "scam" if d.label == "scam" else "benign"
                family = "none" if label == "benign" else (d.family or "unknown")
                f.write(json.dumps({"id": f"donated-{d.id}", "label": label, "family": family, "text": d.text}, ensure_ascii=False) + "\n")
                n += 1
        self.stdout.write(f"{n} messages written to {o['out']}. Keep this file private.")
