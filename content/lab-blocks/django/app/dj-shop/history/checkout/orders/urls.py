from django.urls import path

from orders import views

urlpatterns = [
    path("", views.order_list, name="order-list-page"),
    path("<int:pk>/", views.order_detail, name="order-page"),
    path("invoices/<int:pk>/", views.invoice_detail, name="invoice-page"),
]
