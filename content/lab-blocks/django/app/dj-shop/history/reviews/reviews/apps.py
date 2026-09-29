from django.apps import AppConfig


class ReviewsConfig(AppConfig):
    name = "reviews"

    def ready(self):
        from reviews import signals  # noqa: F401
