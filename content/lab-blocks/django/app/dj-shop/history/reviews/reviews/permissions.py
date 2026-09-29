from rest_framework.permissions import SAFE_METHODS, BasePermission


class IsAuthorOrReadOnly(BasePermission):
    """Anyone may read reviews; only the author (or staff) may change one."""

    def has_object_permission(self, request, view, obj):
        if request.method in SAFE_METHODS:
            return True
        # mf:slot reviews.permissions.object_check
        return obj.customer_id == request.user.pk or request.user.is_staff
        # mf:endslot
