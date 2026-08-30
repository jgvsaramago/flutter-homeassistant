"""Registers the settings-editor sidebar panel.

Serves `frontend/flutter-dashboard-panel.js` as a static asset and registers
it as a `panel_custom` panel. The panel is just another client of the
`get_settings`/`set_settings` websocket commands defined in `__init__.py` -
it needs no backend support of its own beyond being served to the browser.
"""
from __future__ import annotations

from pathlib import Path

from homeassistant.components import frontend, panel_custom
from homeassistant.components.http import StaticPathConfig
from homeassistant.core import HomeAssistant

from .const import DOMAIN

FRONTEND_SCRIPT_URL = f"/{DOMAIN}_panel/flutter-dashboard-panel.js"
_FRONTEND_DIR = Path(__file__).parent / "frontend"


async def async_register_panel(hass: HomeAssistant) -> None:
    await hass.http.async_register_static_paths(
        [StaticPathConfig(f"/{DOMAIN}_panel", str(_FRONTEND_DIR), cache_headers=False)]
    )

    await panel_custom.async_register_panel(
        hass,
        webcomponent_name="flutter-dashboard-panel",
        frontend_url_path=DOMAIN,
        module_url=FRONTEND_SCRIPT_URL,
        sidebar_title="Flutter Dashboard",
        sidebar_icon="mdi:tablet-dashboard",
        require_admin=True,
        config={},
    )


def async_remove_panel(hass: HomeAssistant) -> None:
    frontend.async_remove_panel(hass, DOMAIN)
