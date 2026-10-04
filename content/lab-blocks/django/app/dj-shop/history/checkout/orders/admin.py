from django.contrib import admin

from orders import services
from orders.models import Invoice, Order, OrderItem


class OrderItemInline(admin.TabularInline):
    model = OrderItem
    extra = 0
    raw_id_fields = ("product",)


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    # mf:slot orders.admin.changelist
    list_display = ("id", "customer_email", "status_badge", "total", "created_at")
    list_select_related = ("customer",)
    list_filter = ("status",)
    list_per_page = 50
    show_full_result_count = False
    # mf:endslot
    search_fields = ("customer__email", "shipping_name")
    raw_id_fields = ("customer", "handled_by")
    inlines = [OrderItemInline]
    actions = ["mark_shipped"]

    @admin.display(description="Customer", ordering="customer__email")
    def customer_email(self, obj):
        return obj.customer.email

    @admin.display(description="Status")
    def status_badge(self, obj):
        return obj.status_label

    @admin.action(description="Mark selected paid orders as shipped")
    def mark_shipped(self, request, queryset):
        count = services.bulk_ship(list(queryset.values_list("pk", flat=True)))
        self.message_user(request, f"{count} order(s) marked as shipped.")


@admin.register(Invoice)
class InvoiceAdmin(admin.ModelAdmin):
    list_display = ("number", "order", "total", "issued_at")
    list_select_related = ("order",)
    raw_id_fields = ("order",)
