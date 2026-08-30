"""Flutter Home Assistant App integration.

Centralizes the app's dashboard settings (rooms, entity mappings, EV cars,
energy page config, ...) in Home Assistant's own storage, so every device
running the app reads and writes the same settings instead of each keeping
its own local copy.

Settings are stored as opaque JSON keyed by a domain-chosen string (e.g.
"rooms"). This integration doesn't know or care about the shape of any
individual setting - it's just a shared key/value store with two websocket
commands, `flutter_homeassistant/get_settings` and
`flutter_homeassistant/set_settings`.
"""
from __future__ import annotations

import voluptuous as vol

from homeassistant.components import websocket_api
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.helpers import config_validation as cv
from homeassistant.helpers.storage import Store
from homeassistant.helpers.typing import ConfigType

from .const import DOMAIN, EVENT_SETTINGS_UPDATED, STORAGE_KEY, STORAGE_VERSION

CONFIG_SCHEMA = cv.empty_config_schema(DOMAIN)

# Any JSON-serializable value: the individual settings stores on the Dart
# side each choose their own shape (list, dict, scalar) and this integration
# just stores whatever it's given.
_SETTINGS_VALUE = vol.Any(dict, list, str, int, float, bool, None)


async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    """Register the websocket commands once, regardless of config entries."""
    hass.data.setdefault(DOMAIN, {})
    websocket_api.async_register_command(hass, websocket_get_settings)
    websocket_api.async_register_command(hass, websocket_set_settings)
    return True


async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    store = Store(hass, STORAGE_VERSION, STORAGE_KEY)
    hass.data[DOMAIN]["store"] = store
    hass.data[DOMAIN]["data"] = await store.async_load() or {}
    return True


async def async_unload_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    hass.data[DOMAIN].pop("store", None)
    hass.data[DOMAIN].pop("data", None)
    return True


@websocket_api.websocket_command(
    {
        vol.Required("type"): "flutter_homeassistant/get_settings",
        vol.Optional("key"): cv.string,
    }
)
@websocket_api.async_response
async def websocket_get_settings(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict
) -> None:
    """Return the stored settings, or a single key if `key` is given."""
    data = hass.data.get(DOMAIN, {}).get("data")
    if data is None:
        connection.send_error(msg["id"], "not_setup", "Integration is not set up")
        return

    key = msg.get("key")
    connection.send_result(msg["id"], {"value": data.get(key) if key is not None else data})


@websocket_api.websocket_command(
    {
        vol.Required("type"): "flutter_homeassistant/set_settings",
        vol.Required("key"): cv.string,
        vol.Required("value"): _SETTINGS_VALUE,
    }
)
@websocket_api.async_response
async def websocket_set_settings(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict
) -> None:
    """Persist one settings key and notify listeners it changed."""
    domain_data = hass.data.get(DOMAIN, {})
    store: Store | None = domain_data.get("store")
    if store is None:
        connection.send_error(msg["id"], "not_setup", "Integration is not set up")
        return

    domain_data["data"][msg["key"]] = msg["value"]
    await store.async_save(domain_data["data"])

    hass.bus.async_fire(EVENT_SETTINGS_UPDATED, {"key": msg["key"]})

    connection.send_result(msg["id"])
