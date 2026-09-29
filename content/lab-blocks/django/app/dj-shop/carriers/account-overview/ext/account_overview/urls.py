from django.urls import path

from ext.account_overview import views

urlpatterns = [path("api/me/overview/", views.overview, name="account-overview")]
