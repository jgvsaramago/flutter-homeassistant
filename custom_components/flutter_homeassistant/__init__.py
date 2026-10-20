"""Flutter Home Assistant App integration.

Centralizes the kiosk app's settings in Home Assistant's own storage, so
every screen running the app reads and writes the same ones instead of each
keeping its own local copy. Two kinds live here: the entity mappings edited
in the "Flutter Dashboard" sidebar panel (family, calendars, weather, rooms,
the Casa page, energy, EV cars), and the household data the screens edit
themselves (`meal_plan`, `chores`, `todo_list_icons`).

Settings are stored as opaque JSON keyed by a domain-chosen string (e.g.
"rooms"). This integration doesn't know or care about the shape of any
individual setting - it's just a shared key/value store with two websocket
commands, `flutter_homeassistant/get_settings` and
`flutter_homeassistant/set_settings`.

Screens announce themselves (`flutter_homeassistant/register_screen`) for as
long as their websocket stays open, so the sidebar panel can say whether a
screen is connected (`flutter_homeassistant/list_screens`); they also
subscribe to saved changes (`flutter_homeassistant/subscribe_settings`) and
apply them live.

Also proxies calendar event lookups (`flutter_homeassistant/get_calendar_events`)
over this same authenticated websocket connection, so the app's web build
never has to hit HA's REST `/api/calendars/<entity_id>` endpoint directly —
that endpoint is subject to browser CORS restrictions the websocket isn't.
"""
from __future__ import annotations

import voluptuous as vol

from homeassistant.components import websocket_api
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import Event, HomeAssistant, callback
from homeassistant.exceptions import HomeAssistantError
from homeassistant.helpers import config_validation as cv
from homeassistant.helpers.storage import Store
from homeassistant.helpers.typing import ConfigType
from homeassistant.util import dt as dt_util

from .const import DOMAIN, EVENT_SETTINGS_UPDATED, OBSOLETE_KEYS, STORAGE_KEY, STORAGE_VERSION
from .panel import async_register_panel, async_remove_panel

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
    websocket_api.async_register_command(hass, websocket_get_calendar_events)
    websocket_api.async_register_command(hass, websocket_register_screen)
    websocket_api.async_register_command(hass, websocket_list_screens)
    websocket_api.async_register_command(hass, websocket_subscribe_settings)
    return True


async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    store = Store(hass, STORAGE_VERSION, STORAGE_KEY)
    hass.data[DOMAIN]["store"] = store
    data = await store.async_load() or {}
    if any(key in data for key in OBSOLETE_KEYS):
        for key in OBSOLETE_KEYS:
            data.pop(key, None)
        await store.async_save(data)
    hass.data[DOMAIN]["data"] = data

    await async_register_panel(hass)

    return True


async def async_unload_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    async_remove_panel(hass)

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


@websocket_api.websocket_command(
    {
        vol.Required("type"): "flutter_homeassistant/register_screen",
        vol.Required("name"): cv.string,
    }
)
@callback
def websocket_register_screen(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict
) -> None:
    """Track a screen for as long as this connection stays open.

    Registered like a subscription, so HA calls the cleanup itself when the
    connection closes — a screen that loses power or network drops off the
    list without having to say goodbye.
    """
    screens: dict[int, dict] = hass.data[DOMAIN].setdefault("screens", {})
    key = id(connection)
    screens[key] = {"name": msg["name"], "since": dt_util.utcnow().isoformat()}

    @callback
    def _gone() -> None:
        screens.pop(key, None)

    connection.subscriptions[msg["id"]] = _gone
    connection.send_result(msg["id"])


@websocket_api.websocket_command({vol.Required("type"): "flutter_homeassistant/subscribe_settings"})
@callback
def websocket_subscribe_settings(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict
) -> None:
    """Send `{"key": ...}` on this subscription whenever a setting is saved.

    Its own command rather than `subscribe_events`, which only lets admin
    users subscribe to a custom event type — a screen's token needn't be one.
    """

    @callback
    def _forward(event: Event) -> None:
        connection.send_message(websocket_api.event_message(msg["id"], {"key": event.data.get("key")}))

    connection.subscriptions[msg["id"]] = hass.bus.async_listen(EVENT_SETTINGS_UPDATED, _forward)
    connection.send_result(msg["id"])


@websocket_api.websocket_command({vol.Required("type"): "flutter_homeassistant/list_screens"})
@callback
def websocket_list_screens(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict
) -> None:
    """The screens connected right now."""
    screens = hass.data.get(DOMAIN, {}).get("screens", {})
    connection.send_result(msg["id"], {"screens": list(screens.values())})


def _wrap_event_datetime(value: str) -> dict[str, str]:
    """Match the REST `/api/calendars/<entity_id>` endpoint's nested
    `{"date": ...}` / `{"dateTime": ...}` shape (see `_api_event_dict_factory`
    in Home Assistant core's `calendar` component) from the flat ISO string
    the `calendar.get_events` service returns, so the Dart side's
    `HaCalendarEvent.fromJson` only ever has to understand one shape. An
    all-day event's value has no time component, so it round-trips as a
    bare date string (e.g. "2026-08-15") with no "T"; a timed event's always
    has one.
    """
    return {"date": value} if "T" not in value else {"dateTime": value}


@websocket_api.websocket_command(
    {
        vol.Required("type"): "flutter_homeassistant/get_calendar_events",
        vol.Required("entity_id"): cv.entity_id,
        vol.Required("start"): cv.string,
        vol.Required("end"): cv.string,
    }
)
@websocket_api.async_response
async def websocket_get_calendar_events(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict
) -> None:
    """Return one calendar's events between `start` and `end`.

    Sourced via the `calendar.get_events` service — the same one behind the
    "Calendar: Get events" action — over this integration's own
    authenticated websocket connection, rather than the REST
    `/api/calendars/<entity_id>` endpoint. The web build can't reach that
    REST endpoint cross-origin unless the household has explicitly opened
    up HA's CORS settings for it, which broke every calendar's events as
    soon as one was configured; the websocket connection this command rides
    on is already established and authenticated by the time the app can
    even ask for a calendar's events, so it isn't subject to that at all.
    """
    start_date = dt_util.parse_datetime(msg["start"])
    end_date = dt_util.parse_datetime(msg["end"])
    if start_date is None or end_date is None:
        connection.send_error(msg["id"], "invalid_format", "start/end must be ISO 8601 datetimes")
        return

    try:
        response = await hass.services.async_call(
            "calendar",
            "get_events",
            {
                "entity_id": msg["entity_id"],
                "start_date_time": dt_util.as_local(start_date),
                "end_date_time": dt_util.as_local(end_date),
            },
            blocking=True,
            return_response=True,
        )
    except HomeAssistantError as err:
        connection.send_error(msg["id"], "read_failed", str(err))
        return

    raw_events = (response or {}).get(msg["entity_id"], {}).get("events", [])
    connection.send_result(
        msg["id"],
        {
            "events": [
                {
                    "start": _wrap_event_datetime(event["start"]),
                    "end": _wrap_event_datetime(event["end"]),
                    "summary": event.get("summary", ""),
                }
                for event in raw_events
            ]
        },
    )
