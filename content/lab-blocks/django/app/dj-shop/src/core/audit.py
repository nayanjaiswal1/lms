from core.context import get_current_customer
from core.models import AuditEntry


def record_audit(action, target, **data):
    """Append an audit entry attributed to the customer handling the request."""
    return AuditEntry.objects.create(
        actor=get_current_customer(),
        action=action,
        target_type=target._meta.label_lower,
        target_id=str(target.pk),
        data=data,
    )
