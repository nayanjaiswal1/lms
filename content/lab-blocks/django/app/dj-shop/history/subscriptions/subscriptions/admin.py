from django.contrib import admin

from subscriptions.models import Plan, Subscription


@admin.register(Plan)
class PlanAdmin(admin.ModelAdmin):
    list_display = ("code", "name", "monthly_price")


@admin.register(Subscription)
class SubscriptionAdmin(admin.ModelAdmin):
    list_display = ("id", "customer", "plan", "status", "started_at")
    list_select_related = ("customer", "plan")
    list_filter = ("status", "plan")
    raw_id_fields = ("customer",)
