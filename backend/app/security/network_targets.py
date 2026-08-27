import ipaddress
import socket
from urllib.parse import urlparse


class UnsafeApiBase(ValueError):
    pass


def _is_loopback_name(hostname: str) -> bool:
    return hostname.lower() in {"localhost", "localhost.localdomain"}


def validate_api_base(value: str, *, allow_loopback: bool = False) -> str:
    normalized = str(value or "").strip().rstrip("/")
    parsed = urlparse(normalized)
    if parsed.scheme not in {"https", "http"} or not parsed.hostname:
        raise UnsafeApiBase("API Base URL must use HTTP or HTTPS")
    if parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise UnsafeApiBase("API Base URL cannot contain credentials, query, or fragment")
    if parsed.scheme == "http" and not allow_loopback:
        raise UnsafeApiBase("Public API Base URL must use HTTPS")

    hostname = parsed.hostname.rstrip(".")
    if _is_loopback_name(hostname):
        if allow_loopback:
            return normalized
        raise UnsafeApiBase("Loopback API addresses are not allowed")

    try:
        literal = ipaddress.ip_address(hostname)
        addresses = [literal]
    except ValueError:
        try:
            default_port = 443 if parsed.scheme == "https" else 80
            addresses = {
                ipaddress.ip_address(item[4][0])
                for item in socket.getaddrinfo(
                    hostname,
                    parsed.port or default_port,
                    type=socket.SOCK_STREAM,
                )
            }
        except (OSError, ValueError) as exc:
            raise UnsafeApiBase("API Base hostname cannot be resolved") from exc

    for address in addresses:
        if address.is_loopback and allow_loopback:
            continue
        if (
            address.is_private
            or address.is_loopback
            or address.is_link_local
            or address.is_multicast
            or address.is_reserved
            or address.is_unspecified
        ):
            raise UnsafeApiBase("Private or reserved API addresses are not allowed")
    return normalized
