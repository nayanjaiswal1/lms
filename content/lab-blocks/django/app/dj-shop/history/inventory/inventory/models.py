from django.db import models


class Warehouse(models.Model):
    code = models.CharField(max_length=16, unique=True)
    name = models.CharField(max_length=80)

    def __str__(self):
        return self.code


class StockLevel(models.Model):
    product = models.ForeignKey("catalog.Product", on_delete=models.CASCADE, related_name="stock_levels")
    warehouse = models.ForeignKey(Warehouse, on_delete=models.PROTECT, related_name="stock_levels")
    on_hand = models.IntegerField(default=0)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["product", "warehouse"], name="uniq_stock_product_warehouse")]

    def __str__(self):
        return f"{self.product_id}@{self.warehouse_id}: {self.on_hand}"
