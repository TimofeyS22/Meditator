from starlette.requests import Request
from slowapi import Limiter
from slowapi.util import get_remote_address


def _get_real_client_ip(request: Request) -> str:
    if cf_ip := request.headers.get("CF-Connecting-IP"):
        return cf_ip.strip()
    if forwarded := request.headers.get("X-Forwarded-For"):
        return forwarded.split(",")[0].strip()
    return get_remote_address(request)


limiter = Limiter(key_func=_get_real_client_ip, default_limits=["100/minute"])
