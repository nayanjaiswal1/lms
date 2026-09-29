from django.urls import path

from ext.order_export import views

urlpatterns = [path("api/orders/export/", views.export_orders, name="order-export")]
