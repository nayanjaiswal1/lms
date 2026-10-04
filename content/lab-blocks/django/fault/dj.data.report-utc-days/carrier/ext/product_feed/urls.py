from django.urls import path

from ext.product_feed import views

urlpatterns = [path("feeds/products.json", views.product_feed, name="product-feed")]
