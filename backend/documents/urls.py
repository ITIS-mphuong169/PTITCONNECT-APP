from django.urls import path
from .views import (
    documents_api,
    document_detail_api,
    document_subjects_api,
    document_view_api,  # 👈 thêm
)

urlpatterns = [
    path("", documents_api),
    path("subjects/", document_subjects_api),
    path("<int:pk>/", document_detail_api),

    path("<int:pk>/view/", document_view_api),
]
