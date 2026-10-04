from django.contrib.auth import authenticate, login, logout
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from customers import cache, services
from customers.serializers import CustomerSerializer, LoginSerializer, SignupSerializer


class SignupView(APIView):
    permission_classes = [AllowAny]
    authentication_classes: list = []

    def post(self, request):
        data = SignupSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        try:
            customer = services.register(**data.validated_data)
        except services.EmailTaken:
            return Response({"detail": "That email is already registered."}, status=status.HTTP_409_CONFLICT)
        return Response(CustomerSerializer(customer).data, status=status.HTTP_201_CREATED)


class SessionLoginView(APIView):
    """Cookie-session login for browser clients (CSRF protected)."""

    permission_classes = [AllowAny]

    def post(self, request):
        data = LoginSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        customer = authenticate(request, username=data.validated_data["email"], password=data.validated_data["password"])
        if customer is None:
            return Response({"detail": "Invalid credentials."}, status=status.HTTP_400_BAD_REQUEST)
        # mf:slot customers.views.session_login
        login(request, customer)
        # mf:endslot
        return Response(CustomerSerializer(customer).data)


class SessionLogoutView(APIView):
    def post(self, request):
        logout(request)
        return Response(status=status.HTTP_204_NO_CONTENT)


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(CustomerSerializer(request.user).data)

    def patch(self, request):
        ser = CustomerSerializer(request.user, data=request.data, partial=True)
        ser.is_valid(raise_exception=True)
        ser.save()
        cache.invalidate_profile(request.user.pk)
        return Response(ser.data)

    def delete(self, request):
        services.close_account(request.user)
        cache.invalidate_profile(request.user.pk)
        return Response(status=status.HTTP_204_NO_CONTENT)
