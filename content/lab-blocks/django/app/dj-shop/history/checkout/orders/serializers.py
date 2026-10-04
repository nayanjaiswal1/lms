from rest_framework import serializers

from orders.models import Invoice, Order, OrderItem


class OrderItemSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(source="product.name", read_only=True)

    class Meta:
        model = OrderItem
        fields = ["product", "product_name", "quantity", "unit_price", "line_total"]


class OrderSerializer(serializers.ModelSerializer):
    customer_email = serializers.CharField(source="customer.email", read_only=True)
    items = OrderItemSerializer(many=True, read_only=True)
    items_count = serializers.SerializerMethodField()

    class Meta:
        model = Order
        fields = [
            "id", "public_id", "status", "customer_email", "subtotal", "tax", "total", "currency",
            "shipping_name", "created_at", "items_count", "items",
        ]  # fmt: skip

    def get_items_count(self, obj):
        # mf:slot orders.serializers.items_count
        return len(obj.items.all())
        # mf:endslot


class PlaceOrderLineSerializer(serializers.Serializer):
    product = serializers.IntegerField(min_value=1)
    quantity = serializers.IntegerField(min_value=1, max_value=99)


class PlaceOrderSerializer(serializers.Serializer):
    items = PlaceOrderLineSerializer(many=True, allow_empty=False)
    shipping_name = serializers.CharField(max_length=120, required=False, allow_blank=True, default="")


class InvoiceSerializer(serializers.ModelSerializer):
    order = serializers.IntegerField(source="order_id", read_only=True)

    class Meta:
        model = Invoice
        fields = ["id", "number", "order", "issued_at", "total"]
