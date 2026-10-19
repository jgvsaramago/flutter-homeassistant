"""Constants for the Flutter Home Assistant App integration."""

DOMAIN = "flutter_homeassistant"

STORAGE_KEY = f"{DOMAIN}.settings"
STORAGE_VERSION = 1

EVENT_SETTINGS_UPDATED = f"{DOMAIN}_settings_updated"

# Settings earlier versions of the app stored and nothing reads any more;
# dropped from storage when the integration loads.
OBSOLETE_KEYS = (
    "calendar_entries",
    "energy_individual_sensors",
    "energy_page_settings",
    "house_mode",
    "mqtt",
    "music_assistant",
    "rooms_config",
)
