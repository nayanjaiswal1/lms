from django.urls import path

from reviews import api

urlpatterns = [
    path("reviews/", api.ReviewListCreate.as_view(), name="review-list"),
    path("reviews/purge/", api.ReviewPurge.as_view(), name="review-purge"),
    path("reviews/<int:pk>/", api.ReviewDetail.as_view(), name="review-detail"),
]
