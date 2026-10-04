from catalog.models import Product


def search_products(term, limit=20):
    """Case-insensitive search over name, sku and description of live products."""
    pattern = f"%{term}%"
    # mf:slot catalog.search.query
    return list(
        Product.objects.raw(
            "SELECT * FROM catalog_product "
            "WHERE is_deleted = false AND (name ILIKE %s OR sku ILIKE %s OR description ILIKE %s) "
            "ORDER BY review_count DESC, name LIMIT %s",
            [pattern, pattern, pattern, limit],
        )
    )
    # mf:endslot
