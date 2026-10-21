import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The redesign's icon set — the exact stroke paths from the design's own
/// inline SVGs (24×24 viewBox, round caps/joins), rendered through
/// flutter_svg rather than approximated with Material icons. Each value is
/// just the SVG's inner markup; [KIcon] wraps it with the viewBox/stroke
/// attributes and the colour to draw in.
abstract final class KIcons {
  static const close = '<path d="M6 6l12 12M18 6L6 18"/>';
  static const minus = '<path d="M5 12h14"/>';
  static const plus = '<path d="M12 5v14M5 12h14"/>';
  static const trash = '<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>';
  static const wave = '<path d="M4 10v4M8 6v12M12 3v18M16 7v10M20 10v4"/>';
  static const bulb = '<path d="M9 18h6M10 21h4"/><path d="M12 3a6 6 0 0 0-3.5 10.9c.6.5 1 1.2 1 2V16h5v-.1c0-.8.4-1.5 1-2A6 6 0 0 0 12 3z"/>';
  static const flame = '<path d="M12 3c1 3 4.5 4.5 4.5 9a4.5 4.5 0 0 1-9 0c0-1.8.8-3.1 1.7-4.2.3 1.4 1 2.2 2 2.6C11 7.7 11 5.3 12 3z"/>';
  static const boiler =
      '<rect x="6.5" y="5.5" width="11" height="16" rx="3.5"/><path d="M9.5 5.5V3.5H6.8M14.5 5.5V3.5h2.7"/><path d="M9 14.5q1.5-1.6 3 0t3 0M9 17.8q1.5-1.6 3 0t3 0"/>';
  static const mic = '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/>';
  static const micOff = '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/><path d="M4 4l16 16"/>';
  static const chevronLeft = '<path d="M15 6l-6 6 6 6"/>';
  static const chevronRight = '<path d="M9 6l6 6-6 6"/>';
  static const flag = '<path d="M5 21V4M5 4h11l-2 4 2 4H5"/>';
  static const calendarCheck = '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4M9 15l2 2 4-4"/>';
  static const navHome =
      '<rect x="3" y="3" width="7.5" height="9" rx="2"/><rect x="13.5" y="3" width="7.5" height="5" rx="2"/><rect x="3" y="15" width="7.5" height="6" rx="2"/><rect x="13.5" y="11" width="7.5" height="10" rx="2"/>';
  static const calendar = '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/>';
  static const tasks = '<rect x="3" y="3" width="18" height="18" rx="4"/><path d="M8 12l3 3 5-6"/>';
  static const meals = '<path d="M7 3v8a2 2 0 0 0 2 2v8M11 3v8a2 2 0 0 1-2 2M9 3v6M17 21V3c-2 1.5-3 4-3 7v4h3"/>';
  static const list = '<path d="M9 6h12M9 12h12M9 18h12M4 6h.01M4 12h.01M4 18h.01"/>';
  static const house = '<path d="M3 11l9-7 9 7"/><path d="M5 10v10h14V10"/>';
  static const settings = '<path d="M4 7h10M18 7h2M4 17h4M12 17h8"/><circle cx="16" cy="7" r="2"/><circle cx="10" cy="17" r="2"/>';
  static const check = '<path d="M5 12.5l4.5 4.5L19 7.5"/>';
  // Música (design "Música" / "Colunas")
  static const music = '<path d="M9 18V5l11-2v13"/><circle cx="6.5" cy="18" r="2.5"/><circle cx="17.5" cy="16" r="2.5"/>';
  static const search = '<path d="M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14zM20 20l-4-4"/>';
  static const library = '<path d="M4 4v16M8.5 4v16M13 5l3.8 15M18 4.5l2.5 15"/>';
  static const homeOutline = '<path d="M3 11l9-7 9 7M5 10v10h14V10"/>';
  static const playFilled = '<path d="M8 5v14l11-7z"/>';
  static const pauseFilled = '<path d="M7 5h3.5v14H7zM13.5 5H17v14h-3.5z"/>';
  static const prevFilled = '<path d="M18 6L9.5 12 18 18zM6 6h2.4v12H6z"/>';
  static const nextFilled = '<path d="M6 6l8.5 6L6 18zM15.6 6H18v12h-2.4z"/>';
  static const shuffle = '<path d="M3 7h3c4 0 6 10 10 10h5M3 17h3c1.6 0 2.8-1.6 3.9-3.5M14 8.8C15 7.6 15.9 7 17 7h4M18 4l3 3-3 3M18 14l3 3-3 3"/>';
  static const repeat = '<path d="M17 2l3 3-3 3M4 11V9a4 4 0 0 1 4-4h12M7 22l-3-3 3-3M20 13v2a4 4 0 0 1-4 4H4"/>';
  static const heart =
      '<path d="M12 20s-7-4.4-9.2-8.6C1.2 8.2 3.1 4.5 6.6 4.5c2.1 0 3.6 1.2 5.4 3.1 1.8-1.9 3.3-3.1 5.4-3.1 3.5 0 5.4 3.7 3.8 6.9C19 15.6 12 20 12 20z"/>';
  static const queue = '<path d="M4 6h12M4 12h12M4 18h8M17 14v7l5-3.5z"/>';
  static const addQueue = '<path d="M4 6h12M4 12h12M4 18h7M17 15v6M14 18h6"/>';
  static const speaker =
      '<path d="M5 3h8a1 1 0 0 1 1 1v16a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1zM9 17a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5zM9 7h.01M17.5 7v10M20.5 9v6"/>';
  static const volLow = '<path d="M4 9v6h4l5 4V5L8 9z"/>';
  static const volMid = '<path d="M4 9v6h4l5 4V5L8 9zM16.5 8.5a5 5 0 0 1 0 7"/>';
  static const volHigh = '<path d="M4 9v6h4l5 4V5L8 9zM16.5 8.5a5 5 0 0 1 0 7M19 6a8.5 8.5 0 0 1 0 12"/>';
  static const radio =
      '<path d="M4.9 19.1a10 10 0 0 1 0-14.2M19.1 4.9a10 10 0 0 1 0 14.2M7.8 16.2a6 6 0 0 1 0-8.4M16.2 7.8a6 6 0 0 1 0 8.4M12 13a1 1 0 1 0 0-2 1 1 0 0 0 0 2z"/>';
  static const sort = '<path d="M7 4v16M3 16l4 4 4-4M14 6h7M14 12h5M14 18h3"/>';
  static const pinFilled = '<path d="M12 17v5M8 3h8l-1 6 3 4H6l3-4z"/>';
  static const dots = '<path d="M5 12h.01M12 12h.01M19 12h.01"/>';
  static const chevronDown = '<path d="M6 9l6 6 6-6"/>';
  static const drag = '<path d="M5 9h14M5 15h14"/>';
  static const info = '<path d="M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20zM12 11v6M12 7.5h.01"/>';
  static const floors = '<path d="M4 20h16M6 20V10l6-5 6 5v10"/>';
  static const screen = '<path d="M3 4h18v13H3zM8 21h8M12 17v4"/>';
  static const wifi = '<path d="M5 12.5a10 10 0 0 1 14 0M8.5 16a5 5 0 0 1 7 0M12 19.5h.01"/>';
  static const gear =
      '<path d="M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM12 2v3M12 19v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M2 12h3M19 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1"/>';
  static const micStand = '<path d="M9 3h6v11H9zM5 11a7 7 0 0 0 14 0M12 18v3"/>';
  static const car =
      '<path d="M4 16v-2.5l1.8-4.2A2 2 0 0 1 7.6 8h8.8a2 2 0 0 1 1.8 1.3L20 13.5V16a1 1 0 0 1-1 1h-.7M5.7 17H5a1 1 0 0 1-1-1M9.3 17h5.4M4 13.5h16"/><circle cx="7.5" cy="17" r="1.8"/><circle cx="16.5" cy="17" r="1.8"/>';
  static const fuel = '<path d="M4 21V5a2 2 0 0 1 2-2h7a2 2 0 0 1 2 2v16M3 21h13M4 10h11M15 8l3 3v7a1.5 1.5 0 0 0 3 0V9l-3-3"/>';
  static const boltFilled = '<path d="M13 2L4 14h7l-1 8 9-12h-7z"/>';
  static const clock = '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>';
  static const unplugged = '<path d="M9 2v5M15 2v5M7 7h10v4a5 5 0 0 1-10 0zM12 16v6M3 3l18 18"/>';
  static const lock = '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>';
  static const lockOpen = '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 7.5-2"/>';
  static const shield = '<path d="M12 3l7 3v5c0 4.5-3 8.5-7 10-4-1.5-7-5.5-7-10V6z"/>';
  static const sunrise = '<path d="M12 3v4M5.6 9.6l1.4 1.4M18.4 9.6L17 11M3 17h18M7 17a5 5 0 0 1 10 0M6 21h12"/>';
  static const leave = '<path d="M14 4h4a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-4M10 16l-4-4 4-4M6 12h10"/>';
  static const tv = '<rect x="3" y="5" width="18" height="12" rx="2"/><path d="M8 21h8M12 17v4"/>';
  static const moon = '<path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"/>';
  static const power = '<path d="M12 3v8M6.3 6.3a8 8 0 1 0 11.4 0"/>';
  static const snow = '<path d="M12 2v20M3.3 7l17.4 10M20.7 7L3.3 17M9 4l3 2 3-2M9 20l3-2 3 2"/>';
  static const fan =
      '<circle cx="12" cy="12" r="2"/><path d="M12 10c0-4 1-7 4-7s3 4-4 7zM14 12c4 0 7 1 7 4s-4 3-7-4zM12 14c0 4-1 7-4 7s-3-4 4-7zM10 12c-4 0-7-1-7-4s4-3 7 4z"/>';
  static const phone = '<path d="M5 4h3l2 5-2.5 1.5a11 11 0 0 0 6 6L15 14l5 2v3a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2z"/>';
  static const phoneDown =
      '<g transform="rotate(135 12 12)"><path d="M5 4h3l2 5-2.5 1.5a11 11 0 0 0 6 6L15 14l5 2v3a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2z"/></g>';
  static const bell = '<path d="M6 16v-5a6 6 0 0 1 12 0v5l1.5 2h-15z"/><path d="M10 21h4"/>';
  static const gateHouse = '<path d="M3 21V9l9-5 9 5v12"/><path d="M8 21v-7h8v7"/>';
  static const video = '<rect x="3" y="6" width="13" height="12" rx="2"/><path d="M16 10l5-3v10l-5-3"/>';
  static const door = '<path d="M6 21V4a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v17M4 21h16"/><path d="M14.5 12h.01"/>';
  static const garage = '<path d="M3 21V9l9-5 9 5v12"/><path d="M7 21v-8h10v8M7 16h10"/>';
  static const gate = '<path d="M4 20V6M20 20V6M4 9h16M4 15h16M9 9v6M15 9v6"/>';
  static const pin = '<path d="M12 21s7-6.2 7-11.5A7 7 0 0 0 5 9.5C5 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>';
  static const keyboard = '<rect x="3" y="4" width="18" height="11" rx="2"/><path d="M7 8h.01M11 8h.01M15 8h.01M8 11.5h8M9 19l3 2.5 3-2.5"/>';
  static const shift = '<path d="M12 4l8 8h-4.5v7h-7v-7H4z"/>';
  static const backspace = '<path d="M9 5h11a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H9l-6-7z"/><path d="M12 9.5l5 5M17 9.5l-5 5"/>';
  static const cart = '<path d="M3 4h2l2.4 11h11L21 8H6.2"/><circle cx="9" cy="19.5" r="1.3"/><circle cx="17" cy="19.5" r="1.3"/>';
  static const pill = '<rect x="2.5" y="8.5" width="19" height="7" rx="3.5" transform="rotate(-45 12 12)"/><path d="M9.5 9.5l5 5"/>';
  static const gift =
      '<rect x="3" y="9" width="18" height="12" rx="2"/><path d="M3 13h18M12 9v12M12 9c-2-4-6-4-6-1.5S9 9 12 9zM12 9c2-4 6-4 6-1.5S15 9 12 9z"/>';
  static const note = '<path d="M4 4h16v12l-4 4H4z"/><path d="M16 20v-4h4M8 9h8M8 13h5"/>';
  static const send = '<path d="M5 12h13M13 6l6 6-6 6"/>';
  static const refresh = '<path d="M20 11a8 8 0 1 0-2.3 5.7M20 4v7h-7"/>';

  // Weather (header): stroke drawings from the design, plus a few extra
  // conditions it didn't need to draw but a real forecast can report.
  static const wPartlyCloudy =
      '<path d="M8 2.5v1.5M3 7.5H1.5M4.2 3.7l1 1M11.8 3.7l-1 1"/><path d="M4.8 10.2a3.5 3.5 0 0 1 6.4-2.8"/><path d="M8.5 20h9a4 4 0 0 0 0-8 5 5 0 0 0-9.6 1.5A3.3 3.3 0 0 0 8.5 20z"/>';
  static const wCloudy = '<path d="M7 18h10a4 4 0 0 0 0-8 5.5 5.5 0 0 0-10.6 1.6A3.2 3.2 0 0 0 7 18z"/>';
  static const wRainy = '<path d="M7 15h10a4 4 0 0 0 0-8 5.5 5.5 0 0 0-10.6 1.6A3.2 3.2 0 0 0 7 15z"/><path d="M8 21l1-2.5M12 21l1-2.5M16 21l1-2.5"/>';
  static const wSunny =
      '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>';
  static const wNight = '<path d="M19 14.5A7 7 0 0 1 9.5 5a7 7 0 1 0 9.5 9.5z"/>';
  static const wStorm = '<path d="M7 15h10a4 4 0 0 0 0-8 5.5 5.5 0 0 0-10.6 1.6A3.2 3.2 0 0 0 7 15z"/><path d="M12.5 15l-2 3.5h3l-2 3.5"/>';
  static const wSnow = '<path d="M7 15h10a4 4 0 0 0 0-8 5.5 5.5 0 0 0-10.6 1.6A3.2 3.2 0 0 0 7 15z"/><path d="M8 19h.01M12 21h.01M16 19h.01"/>';
  static const wFog = '<path d="M7 13h10a4 4 0 0 0 0-8 5.5 5.5 0 0 0-10.6 1.6A3.2 3.2 0 0 0 7 13z"/><path d="M4 17h16M6 21h12"/>';
  static const wWind = '<path d="M3 8h11a3 3 0 1 0-3-3M3 12h15a3 3 0 1 1-3 3M3 16h8"/>';

  // Energy flow nodes.
  static const pylonFilled =
      '<path d="M8.28,5.45L6.5,4.55L7.76,2H16.23L17.5,4.55L15.72,5.44L15,4H9L8.28,5.45M18.62,8H14.09L13.3,5H10.7L9.91,8H5.38L4.1,10.55L5.89,11.44L6.62,10H17.38L18.1,11.45L19.89,10.56L18.62,8M17.77,22H15.7L15.46,21.1L12,15.9L8.53,21.1L8.3,22H6.23L9.12,11H11.19L10.83,12.35L12,14.1L13.16,12.35L12.81,11H14.88L17.77,22M11.4,15L10.5,13.65L9.32,18.13L11.4,15M14.68,18.12L13.5,13.64L12.6,15L14.68,18.12Z"/>';
  static const sun =
      '<circle cx="12" cy="12" r="5"/><path d="M12 1v3M12 20v3M1 12h3M20 12h3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1"/>';
  static const battery = '<rect x="4" y="8" width="14" height="9" rx="2"/><path d="M19 11v3"/>';
  static const home2 = '<path d="M4 11 L12 4 L20 11 V20 H4 Z"/><path d="M10 20 V14 H14 V20"/>';
  static const arrowRight = '<path d="M5 12h14M13 6l6 6-6 6"/>';
  static const arrowLeft = '<path d="M19 12H5M11 6l-6 6 6 6"/>';
  // Intercom call history
  static const history = '<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5M12 7v5l3 2"/>';
  static const bellOff = '<path d="M8.5 4.6A6 6 0 0 1 18 11v4M6 11v5l-1.5 2h11M10 21h4M3 3l18 18"/>';
  static const phoneMissed = '<path d="M5 4h3l2 5-2.5 1.5a11 11 0 0 0 6 6L15 14l5 2v3a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2zM15 3l6 6M21 3l-6 6"/>';
  static const cameraOff =
      '<path d="M3 3l18 18M10.5 6H14l1.5 2H19a2 2 0 0 1 2 2v7.5M17.5 19H5a2 2 0 0 1-2-2v-7a2 2 0 0 1 2-2h1"/><path d="M9.5 11.2A3 3 0 0 0 13 15.5"/>';
  static const arrowDown = '<path d="M12 5v14M6 13l6 6 6-6"/>';
  static const arrowUp = '<path d="M12 19V5M6 11l6-6 6 6"/>';
  static const oven =
      '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 8h18M7 5.5h.01M11 5.5h.01"/><rect x="7" y="12" width="10" height="6" rx="1"/>';
  static const fridge = '<rect x="5" y="2" width="14" height="20" rx="2"/><path d="M5 10h14"/>';
  static const tvSmall = '<rect x="3" y="4" width="18" height="12" rx="1.5"/><path d="M9 20h6M12 16v4"/>';
  static const washer = '<rect x="4" y="3" width="16" height="18" rx="2"/><circle cx="12" cy="13" r="5"/><path d="M8 6h.01"/>';
  static const plug = '<path d="M9 2v5M15 2v5M7 7h10v4a5 5 0 0 1-10 0zM12 16v6"/>';
  // Casa: room state icons, sections
  static const window = '<path d="M5 3h14v18H5zM12 3v18M5 12h14"/>';
  static const windowOpen = '<path d="M5 3h14v18H5zM5 3l7 3v18M12 6v15"/>';
  static const blinds = '<path d="M4 4h16M5 4v16M19 4v16M5 8h14M5 12h14"/>';
  static const blindsClosed = '<path d="M4 4h16M5 4v16M19 4v16M5 8h14M5 12h14M5 16h14M5 20h14"/>';
  static const acUnit = '<path d="M3 5h18v8H3zM6 9h12M7 17l-1 3M12 17v3M17 17l1 3"/>';
  static const drop = '<path d="M12 3s6 6.5 6 11a6 6 0 0 1-12 0c0-4.5 6-11 6-11z"/>';
  static const thermo = '<path d="M10 4a2 2 0 1 1 4 0v10.2a4 4 0 1 1-4 0z"/>';
  static const partlySun = '<path d="M12 3v1.5M5.6 5.6l1 1M3 12h1.5M7 18h10a4 4 0 0 0 .6-7.95A5 5 0 0 0 8.2 9 4.5 4.5 0 0 0 7 18z"/>';
  static const sunSmall =
      '<path d="M12 16a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>';
  static const homeFlat = '<path d="M4 11l8-7 8 7v9H4z"/>';
  static const selfUse = '<path d="M12 3v18M3 12h18"/>';
  static const pylon = '<path d="M8 3l-2 4h12l-2-4M5 7l-2 4h18l-2-4M12 11v10"/>';
  static const garageDoor = '<path d="M3 21V9l9-6 9 6v12M6 21v-9h12v9M6 15h12M6 18h12"/>';
}

/// Draws one of [KIcons] at [size] in [color]. [filled] switches a glyph
/// meant to be painted solid (the charging bolt, the grid pylon) from
/// stroke to fill.
class KIcon extends StatelessWidget {
  const KIcon(this.svg, {super.key, this.size = 24, this.color = const Color(0xFF17191C), this.stroke = 2, this.filled = false, this.solid = false});

  final String svg;
  final double size;
  final Color color;
  final double stroke;
  final bool filled;

  /// Filled and stroked (a lit bulb).
  final bool solid;

  static String _hex(Color c) {
    final argb = c.toARGB32();
    return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final hex = _hex(color);
    final opacity = color.a;
    final stroked = 'stroke="$hex" stroke-opacity="$opacity" stroke-width="$stroke" stroke-linecap="round" stroke-linejoin="round"';
    final paint = filled
        ? 'fill="$hex" stroke="none" fill-opacity="$opacity"'
        : (solid ? 'fill="$hex" fill-opacity="$opacity" $stroked' : 'fill="none" $stroked');
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.string('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" $paint>$svg</svg>', width: size, height: size),
    );
  }
}
