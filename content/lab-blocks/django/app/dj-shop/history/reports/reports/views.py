from django.contrib.admin.views.decorators import staff_member_required
from django.shortcuts import render

from reports import services


@staff_member_required
def dashboard(request):
    return render(request, "reports/dashboard.html", services.dashboard_context())
