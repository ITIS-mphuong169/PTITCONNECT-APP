from django.urls import path

from .views import (
    AutoFeedView,
    post_comment_api,
    post_detail_api,
    post_react_api,
    post_save_api,
    posts_api,
)

urlpatterns = [
    path("auto-feed/", AutoFeedView.as_view(), name="auto-feed"),
    path("posts/", posts_api, name="posts-api"),
    path("posts/<int:post_id>/", post_detail_api, name="post-detail-api"),
    path("posts/<int:post_id>/comments/", post_comment_api, name="post-comment-api"),
    path("posts/<int:post_id>/react/", post_react_api, name="post-react-api"),
    path("posts/<int:post_id>/save/", post_save_api, name="post-save-api"),
]
