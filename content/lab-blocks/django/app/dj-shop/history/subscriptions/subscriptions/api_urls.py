from django.urls import path

from subscriptions import api

urlpatterns = [
    path("subscriptions/", api.SubscriptionList.as_view(), name="subscription-list"),
    path("subscriptions/<int:pk>/", api.SubscriptionDetail.as_view(), name="subscription-detail"),
]
