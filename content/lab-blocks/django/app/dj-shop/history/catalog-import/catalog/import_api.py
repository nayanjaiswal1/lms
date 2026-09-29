import io

from rest_framework import status
from rest_framework.parsers import MultiPartParser
from rest_framework.permissions import IsAdminUser
from rest_framework.response import Response
from rest_framework.views import APIView

from catalog.importer import import_products, read_csv


class ProductImport(APIView):
    permission_classes = [IsAdminUser]
    parser_classes = [MultiPartParser]

    def post(self, request):
        upload = request.FILES.get("file")
        if upload is None:
            return Response({"detail": "Upload a CSV as 'file'."}, status=status.HTTP_400_BAD_REQUEST)
        rows = read_csv(io.StringIO(upload.read().decode("utf-8-sig")))
        result = import_products(rows)
        code = status.HTTP_200_OK if result.ok else status.HTTP_207_MULTI_STATUS
        return Response({"created": result.created, "updated": result.updated, "errors": result.errors}, status=code)
