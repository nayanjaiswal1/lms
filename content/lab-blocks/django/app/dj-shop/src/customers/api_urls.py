from django.urls import path

from customers import api

urlpatterns = [
    path("signup/", api.SignupView.as_view(), name="signup"),
    path("session/login/", api.SessionLoginView.as_view(), name="session-login"),
    path("session/logout/", api.SessionLogoutView.as_view(), name="session-logout"),
    path("me/", api.MeView.as_view(), name="me"),
]
