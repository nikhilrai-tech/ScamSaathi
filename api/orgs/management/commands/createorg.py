import secrets

from django.core.management.base import BaseCommand, CommandError

from intel.hashing import sha256_hex
from orgs.models import Organization


class Command(BaseCommand):
    help = "Create an organisation and print its API key ONCE. Only a hash of the key is stored."

    def add_arguments(self, parser):
        parser.add_argument("--name", required=True)
        parser.add_argument("--slug", required=True)
        parser.add_argument("--kind", choices=[k for k, _ in Organization.Kind.choices], default="other")
        parser.add_argument("--district", required=True)
        parser.add_argument("--state", default="")
        parser.add_argument("--verified", action="store_true", help="only after you have checked the organisation yourself")

    def handle(self, *args, **o):
        if Organization.objects.filter(slug=o["slug"]).exists():
            raise CommandError("that slug already exists")
        key = "ssk_" + secrets.token_urlsafe(32)
        Organization.objects.create(name=o["name"], slug=o["slug"], kind=o["kind"], district=o["district"].lower(),
                                    state=o["state"], verified=o["verified"], api_key_hash=sha256_hex(key))
        self.stdout.write(f"API key (shown once, store it safely): {key}")
