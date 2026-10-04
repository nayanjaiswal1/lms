from django.contrib.auth.decorators import login_required
from django.core.paginator import Paginator
from django.shortcuts import get_object_or_404, render

from orders.models import Invoice, Order


@login_required
def order_list(request):
    # mf:slot orders.views.list_queryset
    orders = Order.objects.filter(customer=request.user).select_related("customer").prefetch_related("items__product")
    # mf:endslot
    page = Paginator(orders, 20).get_page(request.GET.get("page"))
    return render(request, "orders/order_list.html", {"page": page})


@login_required
def order_detail(request, pk):
    order = get_object_or_404(Order.objects.prefetch_related("items__product"), pk=pk, customer=request.user)
    return render(request, "orders/order_detail.html", {"order": order})


@login_required
def invoice_detail(request, pk):
    # mf:slot orders.views.invoice_lookup
    invoice = get_object_or_404(Invoice.objects.select_related("order__customer"), pk=pk, order__customer=request.user)
    # mf:endslot
    return render(request, "orders/invoice_detail.html", {"invoice": invoice})
