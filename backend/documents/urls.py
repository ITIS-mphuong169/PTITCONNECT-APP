from django.urls import path

from .views import (
    document_detail_api,
    document_like_api,
    document_record_view_api,
    documents_api,
    document_subjects_api,
)

urlpatterns = [
    path("", documents_api, name="documents-api"),
    path("subjects/", document_subjects_api, name="document-subjects"),
    path("<int:pk>/like/", document_like_api, name="document-like"),
    path("<int:pk>/view/", document_record_view_api, name="document-record-view"),
    path("<int:pk>/", document_detail_api, name="document-detail"),
]
