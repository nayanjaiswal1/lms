import csv

from django.http import HttpResponse
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated

from orders.models import Order


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def export_orders(request):
    """CSV of the signed-in customer's orders."""
    response = HttpResponse(content_type="text/csv")
    response["Content-Disposition"] = 'attachment; filename="orders.csv"'
    writer = csv.writer(response)
    writer.writerow(["id", "status", "total", "created_at"])
    for order in Order.objects.filter(customer=request.user).order_by("id"):
        writer.writerow([order.pk, order.status, order.total, order.created_at.isoformat()])
    return response
