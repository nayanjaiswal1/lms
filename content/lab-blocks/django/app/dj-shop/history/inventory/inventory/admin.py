from django.contrib import admin

from inventory.models import StockLevel, Warehouse


@admin.register(Warehouse)
class WarehouseAdmin(admin.ModelAdmin):
    list_display = ("code", "name")


@admin.register(StockLevel)
class StockLevelAdmin(admin.ModelAdmin):
    list_display = ("product", "warehouse", "on_hand")
    list_select_related = ("product", "warehouse")
    list_filter = ("warehouse",)
    raw_id_fields = ("product",)
