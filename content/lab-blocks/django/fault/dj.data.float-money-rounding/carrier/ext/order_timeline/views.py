from django.shortcuts import get_object_or_404
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from core.models import AuditEntry
from orders.models import Order


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def timeline(request, pk):
    """Chronological events of one of my orders: audit entries and payments."""
    order = get_object_or_404(Order, pk=pk, customer=request.user)
    events = [
        {"at": e.created_at, "event": e.action}
        for e in AuditEntry.objects.filter(target_type="orders.order", target_id=str(order.pk))
    ]
    events += [{"at": p.created_at, "event": f"payment.{p.status}"} for p in order.payments.all()]
    events.sort(key=lambda e: e["at"])
    return Response({"order": order.pk, "events": events})
