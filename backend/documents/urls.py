from django.urls import path

from .views import document_detail_api, documents_api

urlpatterns = [
    path("", documents_api, name="documents-api"),
    path("<int:pk>/", document_detail_api, name="document-detail"),
]
