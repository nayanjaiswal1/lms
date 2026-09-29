from django.contrib import admin

from reviews.models import Review


@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    list_display = ("id", "product", "customer", "rating", "is_approved", "created_at")
    list_select_related = ("product", "customer")
    list_filter = ("is_approved", "rating")
    raw_id_fields = ("product", "customer")
