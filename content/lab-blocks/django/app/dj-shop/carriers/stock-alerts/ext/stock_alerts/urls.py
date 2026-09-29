from django.urls import path

from ext.stock_alerts import views

urlpatterns = [path("api/staff/stock-alerts/", views.stock_alerts, name="stock-alerts")]
