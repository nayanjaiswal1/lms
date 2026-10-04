from rest_framework import generics
from rest_framework.response import Response
from rest_framework.views import APIView

from catalog import search
from catalog.models import Category, Product
from catalog.serializers import CategorySerializer, ProductSerializer


class CategoryList(generics.ListAPIView):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
    pagination_class = None


class ProductList(generics.ListAPIView):
    serializer_class = ProductSerializer

    def get_queryset(self):
        # mf:slot catalog.api.queryset
        qs = Product.objects.select_related("category")
        # mf:endslot
        category = self.request.query_params.get("category")
        if category:
            qs = qs.filter(category__slug=category)
        return qs.order_by("name", "id")


class ProductDetail(generics.RetrieveAPIView):
    queryset = Product.objects.select_related("category")
    serializer_class = ProductSerializer


class ProductSearch(APIView):
    def get(self, request):
        term = request.query_params.get("q", "").strip()
        if not term:
            return Response({"results": []})
        products = search.search_products(term)
        return Response({"results": ProductSerializer(products, many=True).data})


class TopProducts(APIView):
    def get(self, request):
        from catalog.services import get_top_products

        return Response({"results": get_top_products()})
