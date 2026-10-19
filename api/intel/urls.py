from django.urls import path

from . import views

urlpatterns = [
    path("packs/core/manifest", views.PackManifestView.as_view()),
    path("packs/core/pack.json", views.PackFileView.as_view()),
    path("reports", views.ReportView.as_view()),
    path("feed", views.FeedView.as_view()),
]
