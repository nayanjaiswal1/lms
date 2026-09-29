from django.db import transaction

from cart.models import Cart, CartItem
from catalog.models import Product
from core.clock import now
from inventory import services as inventory


class InvalidQuantity(Exception):
    pass


def get_cart(customer):
    cart, _ = Cart.objects.get_or_create(customer=customer)
    return cart


def add_item(customer, product_id, quantity):
    if quantity < 1:
        raise InvalidQuantity("Quantity must be at least 1")
    product = Product.objects.get(pk=product_id)
    cart = get_cart(customer)
    with transaction.atomic():
        item, created = CartItem.objects.select_for_update().get_or_create(
            cart=cart, product=product, defaults={"quantity": 0}
        )
        item.quantity += quantity
        if item.quantity > inventory.available(product.pk):
            raise inventory.OutOfStock(product.pk)
        item.save(update_fields=["quantity"])
        Cart.objects.filter(pk=cart.pk).update(updated_at=now())
    return item


def clear(cart):
    cart.items.all().delete()


def lines(cart):
    """Cart contents as (product, quantity) pairs."""
    return [(item.product, item.quantity) for item in cart.items.select_related("product").order_by("id")]
