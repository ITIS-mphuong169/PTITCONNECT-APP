from django.db.models import Q
from rest_framework import permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.generics import get_object_or_404
from rest_framework.response import Response

from core.demo_auth import resolve_demo_user

from .models import Document
from .serializers import DocumentSerializer


@api_view(["GET", "POST"])
@permission_classes([permissions.AllowAny])
def documents_api(request):
    if request.method == "GET":
        qs = Document.objects.all()
        subject = request.query_params.get("subject", "").strip()
        q = request.query_params.get("q", "").strip()
        if subject:
            qs = qs.filter(subject__iexact=subject)
        if q:
            qs = qs.filter(
                Q(title__icontains=q) | Q(description__icontains=q) | Q(subject__icontains=q)
            )
        serializer = DocumentSerializer(qs[:100], many=True, context={"request": request})
        return Response(serializer.data)

    actor = resolve_demo_user(request)
    title = (request.data.get("title") or "").strip()
    subject = (request.data.get("subject") or "").strip()
    description = (request.data.get("description") or "").strip()
    file_obj = request.FILES.get("file")
    if not title or not subject:
        return Response(
            {"detail": "title and subject are required"},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if not file_obj:
        return Response(
            {"detail": "file is required (multipart upload)"},
            status=status.HTTP_400_BAD_REQUEST,
        )
    doc = Document.objects.create(
        uploader=actor,
        title=title,
        subject=subject,
        description=description,
        file=file_obj,
    )
    return Response(
        DocumentSerializer(doc, context={"request": request}).data,
        status=status.HTTP_201_CREATED,
    )


@api_view(["GET"])
@permission_classes([permissions.AllowAny])
def document_detail_api(request, pk):
    doc = get_object_or_404(Document, pk=pk)
    return Response(DocumentSerializer(doc, context={"request": request}).data)
