from django.contrib.auth.decorators import login_required
from django.shortcuts import render

from cart import services


@login_required
def cart_detail(request):
    return render(request, "cart/cart_detail.html", {"lines": services.lines(services.get_cart(request.user))})
