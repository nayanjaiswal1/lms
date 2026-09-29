from rest_framework import serializers

from reviews.models import Review


class ReviewSerializer(serializers.ModelSerializer):
    author = serializers.CharField(source="customer.display_name", read_only=True)

    class Meta:
        model = Review
        fields = ["id", "product", "author", "rating", "title", "body", "created_at"]
        read_only_fields = ["id", "author", "created_at"]
