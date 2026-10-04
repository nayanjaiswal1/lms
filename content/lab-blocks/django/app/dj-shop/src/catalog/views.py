from django.core.paginator import Paginator
from django.shortcuts import get_object_or_404, render

from catalog.models import Category, Product


def product_list(request):
    slug = request.GET.get("category")
    products = Product.objects.select_related("category")
    if slug:
        products = products.filter(category__slug=slug)
    page = Paginator(products.order_by("name", "id"), 24).get_page(request.GET.get("page"))
    return render(request, "catalog/product_list.html", {"page": page, "categories": Category.objects.all()})


def category_detail(request, slug):
    category = get_object_or_404(Category, slug=slug)
    return render(request, "catalog/category_detail.html", {"category": category, "products": category.products.all()})


def product_detail(request, slug):
    product = get_object_or_404(Product.objects.select_related("category"), slug=slug)
    return render(request, "catalog/product_detail.html", {"product": product})
