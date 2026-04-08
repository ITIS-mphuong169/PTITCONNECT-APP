from django.urls import path

from .views import conversation_open_api, conversations_api, messages_api

urlpatterns = [
    path("", conversations_api, name="conversations"),
    path("open/", conversation_open_api, name="conversation-open"),
    path("<int:pk>/messages/", messages_api, name="conversation-messages"),
]
