from django.urls import path

from .views import (
    group_detail_api,
    group_join_api,
    group_join_decide_api,
    group_join_requests_api,
    groups_api,
)

urlpatterns = [
    path("", groups_api, name="groups-api"),
    path("<int:pk>/", group_detail_api, name="group-detail"),
    path("<int:pk>/join/", group_join_api, name="group-join"),
    path("<int:pk>/join-requests/", group_join_requests_api, name="group-join-requests"),
    path("<int:pk>/join-requests/<int:request_id>/decide/", group_join_decide_api, name="group-join-decide"),
]
