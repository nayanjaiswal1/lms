from django.shortcuts import get_object_or_404
from rest_framework import generics, status
from rest_framework.permissions import IsAdminUser, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from cart import services as cart_services
from catalog.models import Product
from inventory.services import OutOfStock
from orders import services
from orders.models import Invoice, Order
from orders.serializers import InvoiceSerializer, OrderSerializer, PlaceOrderSerializer
from payments.client import PaymentContractError, PaymentDeclined, PaymentError


def _place(customer, lines, shipping_name):
    try:
        order = services.place_order(customer, lines, shipping_name)
    except services.EmptyOrder:
        return Response({"detail": "Nothing to order."}, status=status.HTTP_400_BAD_REQUEST)
    except OutOfStock:
        return Response({"detail": "Not enough stock."}, status=status.HTTP_409_CONFLICT)
    except PaymentDeclined:
        return Response({"detail": "Payment declined."}, status=status.HTTP_402_PAYMENT_REQUIRED)
    except PaymentContractError:
        return Response({"detail": "Payments provider error."}, status=status.HTTP_502_BAD_GATEWAY)
    except PaymentError:
        return Response({"detail": "Payments are unavailable."}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
    return Response(OrderSerializer(order).data, status=status.HTTP_201_CREATED)


class OrderListCreate(generics.ListCreateAPIView):
    permission_classes = [IsAuthenticated]

    def get_serializer_class(self):
        return PlaceOrderSerializer if self.request.method == "POST" else OrderSerializer

    def get_queryset(self):
        # mf:slot orders.api.queryset
        return (
            Order.objects.filter(customer=self.request.user)
            .select_related("customer")
            .prefetch_related("items__product")
        )
        # mf:endslot

    def create(self, request, *args, **kwargs):
        data = PlaceOrderSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        wanted = {line["product"]: line["quantity"] for line in data.validated_data["items"]}
        products = {p.pk: p for p in Product.objects.filter(pk__in=wanted)}
        if len(products) != len(wanted):
            return Response({"detail": "Unknown product."}, status=status.HTTP_400_BAD_REQUEST)
        lines = [(products[pk], qty) for pk, qty in wanted.items()]
        return _place(request.user, lines, data.validated_data["shipping_name"])


class OrderDetail(generics.RetrieveAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = OrderSerializer

    def get_queryset(self):
        return Order.objects.filter(customer=self.request.user).prefetch_related("items__product")


class OrderCancel(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        order = get_object_or_404(Order, pk=pk, customer=request.user)
        try:
            services.cancel_order(order)
        except services.InvalidTransition as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_409_CONFLICT)
        return Response(OrderSerializer(order).data)


class StaffOrderList(generics.ListAPIView):
    permission_classes = [IsAdminUser]
    serializer_class = OrderSerializer

    def get_queryset(self):
        # mf:slot orders.api.staff_queryset
        qs = Order.objects.select_related("customer").prefetch_related("items")
        # mf:endslot
        state = self.request.query_params.get("status")
        if state:
            qs = qs.filter(status=state)
        return qs.order_by("-created_at", "-id")


class InvoiceDetail(generics.RetrieveAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = InvoiceSerializer

    def get_queryset(self):
        # mf:slot orders.invoices.queryset
        return Invoice.objects.filter(order__customer=self.request.user)
        # mf:endslot


class CartCheckout(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        cart = cart_services.get_cart(request.user)
        lines = cart_services.lines(cart)
        response = _place(request.user, lines, request.data.get("shipping_name", ""))
        if response.status_code == status.HTTP_201_CREATED:
            cart_services.clear(cart)
        return response
