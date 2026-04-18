from utils.notify import notify_user

def call_invite(request, conversation_id):
    # ... create call log

    for user in participants:
        if user.username != request.user.username:
            notify_user(user.username, {
                "type": "incoming_call",
                "conversation_id": conversation_id,
                "call_type": "video",
                "caller_username": request.user.username,
                "caller_name": request.user.username,
            })

    return Response({"ok": True})