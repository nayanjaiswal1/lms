from core.context import get_current_customer


def current_customer(request):
    customer = get_current_customer()
    return {"header_name": customer.display_name if customer else None}
