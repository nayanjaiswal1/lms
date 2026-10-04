from django.shortcuts import get_object_or_404
from rest_framework import serializers, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from subscriptions import services
from subscriptions.models import Plan, Subscription


class SubscriptionSerializer(serializers.ModelSerializer):
    plan = serializers.CharField(source="plan.code", read_only=True)

    class Meta:
        model = Subscription
        fields = ["id", "plan", "status", "started_at", "canceled_at"]


class SubscriptionList(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = Subscription.objects.filter(customer=request.user).select_related("plan")
        return Response(SubscriptionSerializer(qs, many=True).data)

    def post(self, request):
        plan = get_object_or_404(Plan, code=request.data.get("plan", ""))
        sub, created = services.subscribe(request.user, plan)
        code = status.HTTP_201_CREATED if created else status.HTTP_200_OK
        return Response(SubscriptionSerializer(sub).data, status=code)


class SubscriptionDetail(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, pk):
        sub = get_object_or_404(Subscription, pk=pk, customer=request.user)
        services.cancel(sub)
        return Response(SubscriptionSerializer(sub).data)
