from django.contrib import admin

from payments.models import Payment


@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    list_display = ("id", "order", "status", "amount", "provider_ref", "created_at")
    list_select_related = ("order",)
    list_filter = ("status",)
    raw_id_fields = ("order",)
