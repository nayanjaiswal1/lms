from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def overview(request):
    """How much the signed-in customer has done: orders, reviews, subscriptions."""
    user = request.user
    return Response(
        {
            "orders": user.orders.count(),
            "reviews": user.reviews.count(),
            "active_subscriptions": user.subscriptions.filter(status="active").count(),
        }
    )
