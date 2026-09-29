from django.urls import path

from catalog import api
from catalog import import_api

urlpatterns = [
    path("categories/", api.CategoryList.as_view(), name="category-list"),
    path("products/", api.ProductList.as_view(), name="product-list"),
    path("products/search/", api.ProductSearch.as_view(), name="product-search"),
    path("products/top/", api.TopProducts.as_view(), name="product-top"),
    path("products/import/", import_api.ProductImport.as_view(), name="product-import"),
    path("products/<int:pk>/", api.ProductDetail.as_view(), name="product-detail"),
]
