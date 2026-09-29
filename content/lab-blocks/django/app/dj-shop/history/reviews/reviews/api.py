from django.db import IntegrityError, transaction
from rest_framework import generics, serializers, status
from rest_framework.permissions import IsAdminUser, IsAuthenticated, IsAuthenticatedOrReadOnly
from rest_framework.response import Response

from reviews.models import Review
from reviews.permissions import IsAuthorOrReadOnly
from reviews.serializers import ReviewSerializer


class ReviewListCreate(generics.ListCreateAPIView):
    serializer_class = ReviewSerializer
    permission_classes = [IsAuthenticatedOrReadOnly]

    def get_queryset(self):
        qs = Review.objects.filter(is_approved=True).select_related("customer")
        product = self.request.query_params.get("product")
        return qs.filter(product_id=product) if product else qs

    def perform_create(self, serializer):
        try:
            with transaction.atomic():
                serializer.save(customer=self.request.user)
        except IntegrityError as exc:
            raise serializers.ValidationError({"detail": "You have already reviewed this product."}) from exc


class ReviewDetail(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = ReviewSerializer
    # mf:slot reviews.api.permissions
    permission_classes = [IsAuthenticatedOrReadOnly, IsAuthorOrReadOnly]
    # mf:endslot
    queryset = Review.objects.select_related("customer")


class ReviewPurge(generics.GenericAPIView):
    """Moderation: remove every review written by one customer."""

    permission_classes = [IsAuthenticated, IsAdminUser]

    def delete(self, request):
        customer = request.query_params.get("customer")
        if not customer:
            return Response({"detail": "customer is required"}, status=status.HTTP_400_BAD_REQUEST)
        deleted, _ = Review.objects.filter(customer_id=customer).delete()
        return Response({"deleted": deleted})
