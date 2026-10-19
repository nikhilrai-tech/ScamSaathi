from django.shortcuts import render
from django.views.decorators.http import require_GET

# The page has no inline script or style and talks only to its own origin, so it can be locked down hard.
CSP = ("default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self' data:; "
       "base-uri 'none'; form-action 'none'; frame-ancestors 'none'")


@require_GET
def index(request):
    response = render(request, "dashboard/index.html")
    response["Content-Security-Policy"] = CSP
    response["X-Content-Type-Options"] = "nosniff"
    response["Referrer-Policy"] = "no-referrer"
    response["Cache-Control"] = "no-store"
    return response
