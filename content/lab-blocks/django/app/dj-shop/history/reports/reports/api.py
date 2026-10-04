from datetime import date, timedelta

from rest_framework.permissions import IsAdminUser
from rest_framework.response import Response
from rest_framework.views import APIView

from core.money import quantize
from reports import services


class RevenueReport(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        today = date.today()
        try:
            start = date.fromisoformat(request.query_params.get("from", str(today - timedelta(days=29))))
            end = date.fromisoformat(request.query_params.get("to", str(today)))
        except ValueError:
            return Response({"detail": "from and to must be ISO dates."}, status=400)
        days = [{"day": str(d), "total": str(quantize(t)), "orders": n} for d, t, n in services.daily_revenue(start, end)]
        products = [
            {"id": p.pk, "sku": p.sku, "units": p.units_sold, "revenue": str(quantize(p.revenue)), "reviews": p.reviews_total}
            for p in services.product_stats(limit=20)
        ]
        return Response({"daily": days, "products": products})
