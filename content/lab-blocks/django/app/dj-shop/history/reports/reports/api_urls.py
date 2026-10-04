from django.urls import path

from reports import api

urlpatterns = [path("reports/revenue/", api.RevenueReport.as_view(), name="revenue-report")]
