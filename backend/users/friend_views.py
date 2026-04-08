from django.contrib.auth.models import User
from django.db.models import Q
from rest_framework import permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.generics import get_object_or_404
from rest_framework.response import Response

from core.demo_auth import resolve_demo_user

from .models import FriendRequest
from .serializers import FriendRequestSerializer


def _friends_of(user):
    accepted = FriendRequest.objects.filter(
        status="accepted"
    ).filter(Q(from_user=user) | Q(to_user=user))
    friends = set()
    for fr in accepted:
        if fr.from_user_id == user.id:
            friends.add(fr.to_user.username)
        else:
            friends.add(fr.from_user.username)
    return sorted(friends)


@api_view(["GET"])
@permission_classes([permissions.AllowAny])
def friend_requests_inbox_api(request):
    me = resolve_demo_user(request)
    pending = FriendRequest.objects.filter(to_user=me, status="pending").order_by("-created_at")
    return Response(FriendRequestSerializer(pending, many=True).data)


@api_view(["GET"])
@permission_classes([permissions.AllowAny])
def friends_list_api(request):
    me = resolve_demo_user(request)
    return Response({"friends": _friends_of(me)})


@api_view(["GET"])
@permission_classes([permissions.AllowAny])
def users_search_api(request):
    me = resolve_demo_user(request)
    q = (request.query_params.get("q") or "").strip()
    qs = User.objects.exclude(id=me.id)
    if q:
        qs = qs.filter(username__icontains=q)
    usernames = list(qs.order_by("username").values_list("username", flat=True)[:30])
    return Response({"results": usernames})


@api_view(["POST"])
@permission_classes([permissions.AllowAny])
def friend_request_send_api(request):
    me = resolve_demo_user(request)
    target_username = (request.data.get("to_username") or "").strip()
    if not target_username or target_username == me.username:
        return Response({"detail": "invalid to_username"}, status=status.HTTP_400_BAD_REQUEST)
    target, _ = User.objects.get_or_create(
        username=target_username,
        defaults={"email": f"{target_username}@stu.ptit.edu.vn"},
    )
    fr, created = FriendRequest.objects.get_or_create(
        from_user=me,
        to_user=target,
        defaults={"status": "pending"},
    )
    if not created and fr.status != "pending":
        fr.status = "pending"
        fr.save()
    return Response(FriendRequestSerializer(fr).data, status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([permissions.AllowAny])
def friend_request_decide_api(request, pk):
    me = resolve_demo_user(request)
    fr = get_object_or_404(FriendRequest, pk=pk, to_user=me)
    action = (request.data.get("action") or "").lower()
    if action == "accept":
        fr.status = "accepted"
    elif action == "reject":
        fr.status = "rejected"
    else:
        return Response({"detail": "action must be accept or reject"}, status=status.HTTP_400_BAD_REQUEST)
    fr.save()
    return Response(FriendRequestSerializer(fr).data)
