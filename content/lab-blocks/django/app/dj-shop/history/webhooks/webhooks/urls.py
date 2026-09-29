from django.urls import path

from webhooks import views

urlpatterns = [path("payments/", views.payments_webhook, name="payments-webhook")]
