from django.urls import path

from cart import api

urlpatterns = [
    path("cart/", api.CartView.as_view(), name="cart"),
    path("cart/items/", api.CartItemsView.as_view(), name="cart-items"),
]
