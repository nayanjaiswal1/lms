from core import context


class RequestContextMiddleware:
    """Expose the authenticated customer to code that has no request in hand."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        user = getattr(request, "user", None)
        customer = user if user is not None and user.is_authenticated else None
        token = context.set_current_customer(customer)
        try:
            return self.get_response(request)
        finally:
            context.reset_current_customer(token)
