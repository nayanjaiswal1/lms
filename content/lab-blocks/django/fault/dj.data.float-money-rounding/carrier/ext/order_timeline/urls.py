from django.urls import path

from ext.order_timeline import views

urlpatterns = [path("api/orders/<int:pk>/timeline/", views.timeline, name="order-timeline")]
