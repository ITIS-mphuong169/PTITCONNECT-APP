from django.contrib.auth.models import User
from django.db.models import Q
from rest_framework import permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.generics import get_object_or_404
from rest_framework.response import Response

from core.demo_auth import resolve_demo_user
from notifications_app.services import create_notification

from .models import FriendRequest, Profile
from .serializers import FriendRequestSerializer, ProfileSerializer



def _accepted_friend_users(user):
    accepted = FriendRequest.objects.filter(status="accepted").filter(Q(from_user=user) | Q(to_user=user))
    friends = []
    for fr in accepted.select_related("from_user", "to_user"):
        friends.append(fr.to_user if fr.from_user_id == user.id else fr.from_user)
    return friends


def _pending_user_ids(user):
    sent = FriendRequest.objects.filter(from_user=user, status="pending").values_list("to_user_id", flat=True)
    received = FriendRequest.objects.filter(to_user=user, status="pending").values_list("from_user_id", flat=True)
    return set(sent) | set(received)


@api_view(["GET"])
@permission_classes([permissions.AllowAny])
def friend_requests_inbox_api(request):
    me = resolve_demo_user(request)
    pending = FriendRequest.objects.filter(to_user=me, status="pending").order_by("-created_at")
    return Response(FriendRequestSerializer(pending, many=True).data)


@api_view(["GET"])
@permission_classes([permissions.AllowAny])
def friend_requests_sent_api(request):
    me = resolve_demo_user(request)
    pending = FriendRequest.objects.filter(from_user=me, status="pending").order_by("-created_at")
    return Response(FriendRequestSerializer(pending, many=True).data)


@api_view(["GET"])
@permission_classes([permissions.AllowAny])
def friends_list_api(request):
    me = resolve_demo_user(request)
    profiles = []
    for user in _accepted_friend_users(me):
        profile, _ = Profile.objects.get_or_create(user=user)
        profiles.append(ProfileSerializer(profile).data)
    return Response({"friends": profiles})


@api_view(["GET"])
@permission_classes([permissions.AllowAny])
def users_search_api(request):
    me = resolve_demo_user(request)
    q = (request.query_params.get("q") or "").strip()
    qs = User.objects.exclude(id=me.id).select_related("profile")
    if q:
        qs = qs.filter(
            Q(username__icontains=q)
            | Q(email__icontains=q)
            | Q(profile__full_name__icontains=q)
            | Q(profile__student_id__icontains=q)
        )
    results = []
    for user in qs.order_by("username")[:30]:
        profile, _ = Profile.objects.get_or_create(user=user)
        results.append(ProfileSerializer(profile).data)
    return Response({"results": results})


@api_view(["GET"])
@permission_classes([permissions.AllowAny])
def friend_suggestions_api(request):
    me = resolve_demo_user(request)
    friend_ids = {u.id for u in _accepted_friend_users(me)}
    blocked_ids = friend_ids | _pending_user_ids(me) | {me.id}
    qs = User.objects.exclude(id__in=blocked_ids).select_related("profile").order_by("username")[:20]
    results = []
    for user in qs:
        profile, _ = Profile.objects.get_or_create(user=user)
        results.append(ProfileSerializer(profile).data)
    return Response({"results": results})


@api_view(["POST"])
@permission_classes([permissions.AllowAny])
def friend_request_send_api(request):
    me = resolve_demo_user(request)
    target_username = (request.data.get("to_username") or "").strip().lower()
    if not target_username or target_username == me.username:
        return Response({"detail": "invalid to_username"}, status=status.HTTP_400_BAD_REQUEST)
    target = User.objects.filter(username=target_username).first()
    if target is None:
        return Response({"detail": "user not found"}, status=status.HTTP_404_NOT_FOUND)

    existing_reverse = FriendRequest.objects.filter(from_user=target, to_user=me).first()
    if existing_reverse and existing_reverse.status == "pending":
        existing_reverse.status = "accepted"
        existing_reverse.save(update_fields=["status"])
        create_notification(
            user=target,
            title="Đã trở thành bạn bè",
            content=f"{me.username} đã chấp nhận lời mời kết bạn.",
            notification_type="friend_accept",
            target_username=me.username,
        )
        create_notification(
            user=me,
            title="Đã trở thành bạn bè",
            content=f"Bạn và {target.username} đã là bạn bè.",
            notification_type="friend_accept",
            target_username=target.username,
        )
        return Response(FriendRequestSerializer(existing_reverse).data, status=status.HTTP_201_CREATED)

    fr, created = FriendRequest.objects.get_or_create(from_user=me, to_user=target, defaults={"status": "pending"})
    if not created and fr.status != "pending":
        fr.status = "pending"
        fr.save(update_fields=["status"])
    if created:
        create_notification(
            user=target,
            title="Lời mời kết bạn mới",
            content=f"{me.username} đã gửi lời mời kết bạn cho bạn.",
            notification_type="friend_request",
            target_username=me.username,
        )
    return Response(FriendRequestSerializer(fr).data, status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([permissions.AllowAny])
def friend_request_decide_api(request, pk):
    me = resolve_demo_user(request)
    fr = get_object_or_404(FriendRequest, pk=pk, to_user=me)
    action = (request.data.get("action") or "").lower()
    if action == "accept":
        fr.status = "accepted"
        fr.save(update_fields=["status"])
        create_notification(
            user=fr.from_user,
            title="Lời mời được chấp nhận",
            content=f"{me.username} đã chấp nhận lời mời kết bạn của bạn.",
            notification_type="friend_accept",
            target_username=me.username,
        )
    elif action == "reject":
        fr.status = "rejected"
        fr.save(update_fields=["status"])
    else:
        return Response({"detail": "action must be accept or reject"}, status=status.HTTP_400_BAD_REQUEST)
    return Response(FriendRequestSerializer(fr).data)
