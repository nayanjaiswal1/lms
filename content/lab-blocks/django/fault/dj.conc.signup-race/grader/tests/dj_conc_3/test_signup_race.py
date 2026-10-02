from core.testing import *  # noqa: F401,F403

pytestmark = pytest.mark.django_db


def test_a_lost_signup_race_is_reported_as_email_taken(monkeypatch):
    from customers import services
    from customers.models import Customer

    real_create = Customer.objects.create_user

    def racing_create(email, password=None, **extra):
        # the competing request inserts the same email between our check and our insert
        Customer.objects.create(email=email.lower(), password="!")
        return real_create(email, password, **extra)

    monkeypatch.setattr(Customer.objects, "create_user", racing_create)
    with pytest.raises(services.EmailTaken):
        services.register("Racer@Shop.Test", "pw-12345678")
