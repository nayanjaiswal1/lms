from django.urls import path

from inventory import views

urlpatterns = [
    path("products/<int:pk>/availability/", views.product_availability, name="product-availability"),
]
