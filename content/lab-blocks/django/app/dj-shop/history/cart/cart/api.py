from rest_framework import serializers, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from cart import services
from inventory.services import OutOfStock


class CartItemInput(serializers.Serializer):
    product = serializers.IntegerField(min_value=1)
    quantity = serializers.IntegerField(min_value=1, max_value=99, default=1)


def _cart_payload(cart):
    items = [
        {"product": p.pk, "name": p.name, "unit_price": str(p.price), "quantity": q} for p, q in services.lines(cart)
    ]
    return {"items": items}


class CartView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(_cart_payload(services.get_cart(request.user)))

    def delete(self, request):
        services.clear(services.get_cart(request.user))
        return Response(status=status.HTTP_204_NO_CONTENT)


class CartItemsView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        data = CartItemInput(data=request.data)
        data.is_valid(raise_exception=True)
        try:
            services.add_item(request.user, data.validated_data["product"], data.validated_data["quantity"])
        except OutOfStock:
            return Response({"detail": "Not enough stock."}, status=status.HTTP_409_CONFLICT)
        return Response(_cart_payload(services.get_cart(request.user)), status=status.HTTP_201_CREATED)
