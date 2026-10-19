from django.urls import path

from . import views

urlpatterns = [
    path("alerts", views.PublicAlertsView.as_view()),
    path("org/alerts", views.OrgAlertsView.as_view()),
    path("org/reports", views.OrgReportView.as_view()),
    path("org/dashboard", views.DashboardView.as_view()),
]
