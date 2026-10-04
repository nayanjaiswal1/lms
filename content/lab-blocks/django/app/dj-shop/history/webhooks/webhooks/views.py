import json

from django.http import HttpResponse, JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST

from webhooks import signature
from webhooks.handlers import handle_event


@csrf_exempt
@require_POST
def payments_webhook(request):
    if not signature.is_valid(request):
        return HttpResponse(status=401)
    try:
        event = json.loads(request.body)
    except ValueError:
        return JsonResponse({"detail": "Body must be JSON."}, status=400)
    if not isinstance(event, dict) or "type" not in event:
        return JsonResponse({"detail": "Missing event type."}, status=400)
    handled = handle_event(event)
    return JsonResponse({"received": True, "handled": handled})
