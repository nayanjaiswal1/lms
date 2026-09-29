from django.contrib import admin

from catalog.models import Category, Product


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ("name", "slug")
    prepopulated_fields = {"slug": ("name",)}


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ("sku", "name", "category", "price", "is_deleted")
    list_filter = ("category", "is_deleted")
    list_select_related = ("category",)
    search_fields = ("sku", "name")

    def get_queryset(self, request):
        return Product.all_objects.select_related("category")
