from django.urls import path

from catalog import views

urlpatterns = [
    path("", views.product_list, name="product-list-page"),
    path("categories/<slug:slug>/", views.category_detail, name="category-page"),
    path("products/<slug:slug>/", views.product_detail, name="product-page"),
]
