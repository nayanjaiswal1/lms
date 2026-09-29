from django.core.cache import cache

PROFILE_TTL = 15 * 60


def profile_key(customer_id):
    return f"customer-profile:{customer_id}"


def get_cached_profile(customer_id, build):
    """Return the cached profile payload, computing it with ``build`` on a miss."""
    key = profile_key(customer_id)
    data = cache.get(key)
    if data is None:
        data = build()
        cache.set(key, data, PROFILE_TTL)
    return data


def invalidate_profile(customer_id):
    # mf:slot customers.cache.invalidate
    cache.delete(profile_key(customer_id))
    # mf:endslot
