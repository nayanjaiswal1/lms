from django.db.models import Count, Sum
from django.utils.decorators import method_decorator
from django.views.decorators.cache import cache_page  # noqa: F401
from django.views.decorators.vary import vary_on_headers
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from customers import cache


def build_summary(customer):
    stats = customer.orders.aggregate(orders=Count("id"), spent=Sum("total"))
    return {
        "name": customer.display_name,
        "email": customer.email,
        "orders": stats["orders"],
        "spent": str(stats["spent"] or "0.00"),
        "reviews": customer.reviews.count(),
    }


# mf:slot customers.views.summary_cache
@method_decorator(vary_on_headers("Authorization", "Cookie"), name="dispatch")
# mf:endslot
class AccountSummary(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        data = cache.get_cached_profile(request.user.pk, lambda: build_summary(request.user))
        return Response(data)
