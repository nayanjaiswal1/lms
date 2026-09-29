from django.urls import path

from orders import api

urlpatterns = [
    path("orders/", api.OrderListCreate.as_view(), name="order-list"),
    path("orders/<int:pk>/", api.OrderDetail.as_view(), name="order-detail"),
    path("orders/<int:pk>/cancel/", api.OrderCancel.as_view(), name="order-cancel"),
    path("staff/orders/", api.StaffOrderList.as_view(), name="staff-order-list"),
    path("invoices/<int:pk>/", api.InvoiceDetail.as_view(), name="invoice-detail"),
    path("cart/checkout/", api.CartCheckout.as_view(), name="cart-checkout"),
]
