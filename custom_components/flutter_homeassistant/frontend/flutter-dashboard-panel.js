// "Flutter Dashboard" sidebar panel: maps the kiosk screen onto this
// house's entities. Design: the "Painel HA" board of the kiosk redesign.
//
// Talks to the integration's websocket commands (see
// custom_components/flutter_homeassistant/__init__.py): `get_settings` /
// `set_settings` for the data, `list_screens` for the "screen connected"
// card. Saved changes reach connected screens live. No build step, no
// dependencies; colours come from HA's own theme variables, so it follows
// the user's light/dark theme.
//
// Only what maps the kiosk onto entities lives here; the screen's own
// settings (brightness, restart) are on the screen, and meals, tasks and
// list icons are edited from the screen.

(() => {
  "use strict";

  const DOMAIN = "flutter_homeassistant";

  // ---------- Icons (24×24 stroke paths) ----------
  const I = {
    cal: "M4 6h16v14H4zM4 10h16M8 3v4M16 3v4",
    people: "M9 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM2.5 20c.5-3.5 3.2-5.5 6.5-5.5s6 2 6.5 5.5M16 4.5a3.5 3.5 0 0 1 0 6.5M18.5 14.8c1.7.8 2.8 2.6 3 5.2",
    weather: "M7 18h10a4 4 0 0 0 .6-7.95A6 6 0 0 0 6.2 9.1 4.5 4.5 0 0 0 7 18z",
    thermo: "M10 4a2 2 0 1 1 4 0v10.2a4 4 0 1 1-4 0zM12 9v7",
    rooms: "M3 3h18v18H3zM3 12h8v9M11 3v5M15 12h6",
    home: "M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-6h-6v6H4a1 1 0 0 1-1-1z",
    flash: "M13 2L4 14h7l-1 8 9-12h-7z",
    car: "M5 17v-6l2.2-5h9.6l2.2 5v6M3 11h18v6H3zM7 14h.01M17 14h.01M6 17v2M18 17v2",
    light: "M9 18h6M10 21h4M12 3a6 6 0 0 0-3.5 10.9c.6.5 1 1.2 1 2.1h5c0-.9.4-1.6 1-2.1A6 6 0 0 0 12 3z",
    climate: "M12 2v20M4.9 7l14.2 10M4.9 17L19.1 7M9 4l3 2 3-2M9 20l3-2 3 2",
    window: "M5 3h14v18H5zM12 3v18M5 12h14",
    cover: "M4 4h16M5 4v16M19 4v16M5 8h14M5 12h14M5 16h14",
    lock: "M6 11h12v10H6zM8.5 11V7.5a3.5 3.5 0 0 1 7 0V11",
    alarm: "M12 3l8 3v6c0 4.5-3.4 8.3-8 9-4.6-.7-8-4.5-8-9V6z",
    scene: "M12 3l1.8 4.7 4.7 1.8-4.7 1.8L12 16l-1.8-4.7-4.7-1.8 4.7-1.8zM19 15l.8 2.2 2.2.8-2.2.8L19 21l-.8-2.2-2.2-.8 2.2-.8z",
    camera: "M3 7h11v10H3zM14 10.5l7-3.5v10l-7-3.5",
    battery: "M7 5h10v16H7zM10 2h4v3M10 12h4",
    gauge: "M4 18a8 8 0 1 1 16 0M12 18l4-6",
    plug: "M9 2v5M15 2v5M6 7h12v4a6 6 0 0 1-12 0zM12 17v5",
    toggle: "M8 7h8a5 5 0 0 1 0 10H8A5 5 0 0 1 8 7zM8 9.5a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5",
    script: "M8 4h11v13a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3v-1h11v1M8 4a2 2 0 0 0-2 2v10M11 8h5M11 12h5",
    fridge: "M6 2h12v20H6zM6 9h12M9 5v2M9 12v3",
    tv: "M3 6h18v12H3zM8 21h8",
    washer: "M4 2h16v20H4zM4 7h16M12 18a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM7 4.5h.01M10 4.5h.01",
    oven: "M3 3h18v18H3zM3 8h18M7 5.5h.01M11 5.5h.01M7 12h10v6H7z",
    heatpump: "M3 4h18v12H3zM12 7a3 3 0 1 0 0 6 3 3 0 0 0 0-6M12 10V7M7 19v2M17 19v2",
    socket: "M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20zM9 9v3M15 9v3M9 16h6",
    check: "M5 12.5l4.5 4.5L19 7.5",
    alert: "M12 3l10 18H2zM12 10v5M12 18h.01",
    info: "M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20zM12 11v6M12 7.5h.01",
    dot: "M12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6z",
    plus: "M12 5v14M5 12h14",
    block: "M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20zM5 5l14 14",
    screen: "M5 2h14v20H5zM11 18h2",
    menu: "M4 6h16M4 12h16M4 18h16",
    back: "M19 12H5M11 6l-6 6 6 6",
    chevronDown: "M6 9l6 6 6-6",
    chevronRight: "M9 6l6 6-6 6",
    up: "M12 19V5M6 11l6-6 6 6",
    down: "M12 5v14M18 13l-6 6-6-6",
    trash: "M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3",
    close: "M6 6l12 12M18 6L6 18",
    search: "M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14zM20 20l-4-4",
    floor: "M3 10l9-6 9 6M5 9v11h14V9",
  };

  // The kiosk's person palette (KPersonColor), by the key stored in HA.
  // An older saved "red" is drawn pink on the screen, so it shows as pink.
  const COLORS = [
    { key: "blue", hex: "#1864AB", name: "Azul" },
    { key: "amber", hex: "#C2410C", name: "Laranja" },
    { key: "green", hex: "#2B8A3E", name: "Verde" },
    { key: "accent", hex: "#5F3DC4", name: "Roxo" },
    { key: "pink", hex: "#C2255C", name: "Rosa" },
  ];
  const HOLIDAY_RED = "#B42318";
  const colorIndex = (key, fallback) => {
    if (key === "red") return 4;
    const i = COLORS.findIndex((c) => c.key === key);
    return i >= 0 ? i : fallback;
  };
  // Same test the screen uses to draw a calendar as holidays.
  const isHoliday = (text) => /feriado|holiday/i.test(text || "");

  // IndividualSensorIconKey on the screen side.
  const APPLIANCES = [
    { key: "boiler", name: "Bomba de calor", icon: I.heatpump },
    { key: "fridge", name: "Frigorífico", icon: I.fridge },
    { key: "tv", name: "Televisão", icon: I.tv },
    { key: "washer", name: "Máquina de lavar", icon: I.washer },
    { key: "oven", name: "Forno", icon: I.oven },
    { key: "plug", name: "Tomada", icon: I.socket },
  ];

  const DOMAIN_PT = {
    calendar: "calendário", sensor: "sensor", weather: "meteorologia", light: "luz", switch: "interruptor", climate: "clima",
    binary_sensor: "sensor binário", cover: "estore/portão", lock: "fechadura", alarm_control_panel: "alarme",
    water_heater: "aquecedor de água", scene: "cena", script: "script", camera: "câmara", number: "número",
  };

  // ---------- What each sub-section edits, and where it's stored ----------
  const SUBS = {
    pessoas: {
      type: "list", store: "family_members", title: "Pessoas", req: "name", reqLabel: "nome", noun: ["pessoa", "pessoas"], add: "Adicionar pessoa",
      blank: () => ({ name: "", color: null, calendarEntityId: "" }),
      empty: 'Sem pessoas configuradas: o ecrã usa as pessoas do Home Assistant e uma "Família" partilhada.',
      fields: [
        { k: "name", t: "text", label: "Nome", req: true, ph: "Ex.: João" },
        { k: "calendarEntityId", t: "entity", dom: ["calendar"], label: "Calendário pessoal", opt: true, help: 'Os eventos novos "para" esta pessoa são criados neste calendário.' },
        { k: "color", t: "color", label: "Cor", full: true, help: "Aparece nas tarefas e nos eventos desta pessoa." },
      ],
    },
    outros: {
      type: "list", store: "calendar_entities", title: "Calendários", req: "entityId", reqLabel: "calendário", noun: ["calendário", "calendários"], add: "Adicionar calendário",
      blank: () => ({ entityId: "", color: "green" }),
      hint: "Calendários que não são de ninguém, como feriados ou um calendário da casa.",
      empty: "Nenhum calendário extra. O ecrã mostra só os calendários das pessoas.",
      fields: [
        { k: "entityId", t: "entity", dom: ["calendar"], label: "Calendário", req: true },
        { k: "color", t: "color", label: "Cor" },
      ],
    },
    meteo: {
      type: "form", store: "temperature_entities", title: "Meteorologia",
      fields: [
        { k: "exteriorTempEntityId", t: "entity", dom: ["sensor"], label: "Temperatura exterior", req: true, help: "O número grande no cabeçalho do ecrã." },
        { k: "weatherStateEntityId", t: "entity", dom: ["weather"], label: "Entidade de meteorologia", req: true, help: "Dá o estado do tempo, as máximas e mínimas e a previsão." },
      ],
    },
    areas: {
      type: "areas", store: "rooms", title: "Áreas do Home Assistant",
      hint: "As áreas, os pisos, a temperatura e a humidade vêm do Home Assistant. Áreas sem nada configurado não são guardadas.",
      fields: [
        { k: "lightEntityId", t: "entity", dom: ["light", "switch"], label: "Luz", help: 'O botão de luz no cartão e o "Apagar todas as luzes".' },
        { k: "climateEntityId", t: "entity", dom: ["climate"], label: "Ar condicionado", help: "Os controlos de Clima." },
        { k: "windowEntityId", t: "entity", dom: ["binary_sensor"], label: "Janela", help: 'Mostra "Janela aberta".' },
        { k: "coverEntityId", t: "entity", dom: ["cover"], label: "Estores", help: "A posição dos estores." },
        { k: "secondaryEntityId", t: "entity", dom: null, label: "Linha extra", opt: true, full: true, help: "Um estado a mais. Uma fechadura aparece como trancada/aberta." },
      ],
    },
    alarme: {
      type: "form", store: "house_screen", title: "Alarme e água quente",
      fields: [
        { k: "alarmEntityId", t: "entity", dom: ["alarm_control_panel"], label: "Alarme", full: true },
        { k: "waterHeaterEntityId", t: "entity", dom: ["water_heater", "climate"], label: "Água quente (bomba de calor)", full: true },
        { k: "waterHeaterTempEntityId", t: "entity", dom: ["sensor"], label: "Temperatura da água", opt: true },
        { k: "waterHeaterPowerEntityId", t: "entity", dom: ["sensor"], label: "Potência", opt: true },
      ],
    },
    cenarios: {
      type: "list", store: "house_scenes", title: "Cenários", req: "entityId", reqLabel: "cena ou script", noun: ["cenário", "cenários"], add: "Adicionar cenário",
      blank: () => ({ name: "", entityId: "" }), empty: "Sem cenários configurados: o ecrã mostra todas as cenas.", itemIcon: I.scene,
      fields: [
        { k: "name", t: "text", label: "Nome", ph: "Ex.: Bom dia" },
        { k: "entityId", t: "entity", dom: ["scene", "script"], label: "Cena ou script", req: true },
      ],
    },
    fechaduras: {
      type: "list", store: "house_locks", title: "Fechaduras e portões", req: "entityId", reqLabel: "fechadura ou portão", noun: ["fechadura ou portão", "fechaduras e portões"], add: "Adicionar fechadura ou portão",
      blank: () => ({ name: "", entityId: "" }), empty: "Sem fechaduras configuradas: o ecrã mostra todas as fechaduras e portões.", itemIcon: I.lock,
      fields: [
        { k: "name", t: "text", label: "Nome", ph: "Ex.: Portão" },
        { k: "entityId", t: "entity", dom: ["lock", "cover"], label: "Fechadura ou portão", req: true },
      ],
    },
    camaras: {
      type: "list", store: "house_cameras", title: "Câmaras", req: "entityId", reqLabel: "câmara", noun: ["câmara", "câmaras"], add: "Adicionar câmara",
      blank: () => ({ name: "", entityId: "" }), empty: "Sem câmaras configuradas.", itemIcon: I.camera,
      fields: [
        { k: "name", t: "text", label: "Nome", ph: "Ex.: Portão" },
        { k: "entityId", t: "entity", dom: ["camera"], label: "Câmara", req: true },
      ],
    },
    fluxo: {
      type: "form", store: "energy_entities", title: "Fluxo de energia",
      fields: [
        { k: "solarPowerEntityId", t: "entity", dom: ["sensor"], label: "Potência solar", help: "Sempre positiva." },
        { k: "gridPowerEntityId", t: "entity", dom: ["sensor"], label: "Potência da rede", help: "Positivo = a importar, negativo = a exportar." },
        { k: "batteryPowerEntityId", t: "entity", dom: ["sensor"], label: "Potência da bateria", help: "Positivo = a descarregar, negativo = a carregar." },
        { k: "batterySocEntityId", t: "entity", dom: ["sensor"], label: "Carga da bateria", help: "Em %." },
        { k: "homePowerEntityId", t: "entity", dom: ["sensor"], label: "Consumo da casa", full: true, help: "Sempre positivo. Repartido pelas fontes no centro do cartão." },
      ],
      adv: [
        { k: "solarZeroThresholdW", t: "number", label: "Solar: ignorar abaixo de", suffix: "W" },
        { k: "gridZeroThresholdW", t: "number", label: "Rede: ignorar abaixo de", suffix: "W" },
        { k: "batteryZeroThresholdW", t: "number", label: "Bateria: ignorar abaixo de", suffix: "W" },
        { k: "homeZeroThresholdW", t: "number", label: "Casa: ignorar abaixo de", suffix: "W" },
      ],
    },
    consumos: {
      type: "list", store: "individual_sensors", title: "Consumos", req: "powerEntityId", reqLabel: "sensor de potência", noun: ["consumo", "consumos"], add: "Adicionar consumo", max: 4,
      blank: () => ({ name: "", icon: "plug", powerEntityId: "", temperatureEntityId: "" }),
      hint: "Até 4 aparelhos à volta da casa no cartão Energia.", empty: "Sem consumos: o cartão mostra só as fontes e a casa.",
      fields: [
        { k: "name", t: "text", label: "Nome", ph: "Ex.: Frigorífico" },
        { k: "powerEntityId", t: "entity", dom: ["sensor"], label: "Potência", req: true },
        { k: "icon", t: "icon", label: "Ícone" },
        { k: "temperatureEntityId", t: "entity", dom: ["sensor"], label: "Temperatura", opt: true },
      ],
    },
    carros: {
      type: "cards", store: "ev_cars", title: "Carros", slots: ["left", "right"], titles: ["Primeiro carro", "Segundo carro"],
      fields: [
        { k: "name", t: "text", label: "Nome", ph: "Ex.: Megane" },
        { k: "batterySocEntityId", t: "entity", dom: ["sensor"], label: "Bateria", help: "Em %." },
        { k: "rangeEntityId", t: "entity", dom: ["sensor"], label: "Autonomia" },
        { k: "chargingEntityId", t: "entity", dom: ["binary_sensor", "sensor"], label: "A carregar" },
        { k: "plugConnectedEntityId", t: "entity", dom: ["binary_sensor", "sensor"], label: "Ficha ligada", help: 'Para o estado "à espera de carga".' },
        { k: "chargeLimitEntityId", t: "entity", dom: ["number", "sensor"], label: "Limite de carga", help: "A marca na barra de bateria." },
        { k: "chargePowerEntityId", t: "entity", dom: ["sensor"], label: "Potência de carga" },
      ],
    },
  };

  const SECTIONS = [
    { id: "familia", icon: I.people, title: "Família", desc: "Pessoas da casa, cores e calendários pessoais.", intro: "Quem vive na casa. A cor aparece nas tarefas e nos eventos.", subs: ["pessoas"] },
    { id: "calendarios", icon: I.cal, title: "Outros calendários", desc: "Feriados e calendários que não são de ninguém.", intro: "Um calendário de feriados é reconhecido pelo nome e fica sempre a vermelho.", subs: ["outros"] },
    { id: "meteo", icon: I.weather, title: "Meteorologia", desc: "Temperatura exterior e previsão do cabeçalho.", intro: "O que aparece no cabeçalho do ecrã, ao lado do relógio.", subs: ["meteo"] },
    { id: "divisoes", icon: I.rooms, title: "Divisões", desc: "Luz, clima, janela e estores de cada área.", intro: "Um cartão por área do Home Assistant, ordenado por piso.", subs: ["areas"] },
    { id: "casa", icon: I.home, title: "Casa", desc: "Alarme, água quente, cenários, fechaduras e câmaras.", intro: "Segurança, água quente e atalhos da página Casa.", subs: ["alarme", "cenarios", "fechaduras", "camaras"] },
    { id: "energia", icon: I.flash, title: "Energia", desc: "Fluxo solar, rede, bateria e consumos.", intro: "Os sensores do cartão Energia.", subs: ["fluxo", "consumos"] },
    { id: "carros", icon: I.car, title: "Carros elétricos", desc: "Bateria, autonomia e carregamento.", intro: "Dois cartões fixos, pela ordem em que aparecem no ecrã.", subs: ["carros"] },
  ];

  // ---------- Small helpers ----------
  const clone = (o) => (o === undefined ? undefined : JSON.parse(JSON.stringify(o)));
  const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
  const str = (v) => (v === null || v === undefined ? "" : String(v));
  const joinPt = (a) => (a.length <= 1 ? a.join("") : a.slice(0, -1).join(", ") + " e " + a[a.length - 1]);

  function svg(path, size = 24, attrs = {}) {
    const NS = "http://www.w3.org/2000/svg";
    const el = document.createElementNS(NS, "svg");
    el.setAttribute("width", size);
    el.setAttribute("height", size);
    el.setAttribute("viewBox", "0 0 24 24");
    el.setAttribute("fill", "none");
    el.setAttribute("stroke", attrs.stroke || "currentColor");
    el.setAttribute("stroke-width", attrs.sw || 1.8);
    el.setAttribute("stroke-linecap", "round");
    el.setAttribute("stroke-linejoin", "round");
    el.setAttribute("aria-hidden", "true");
    if (attrs.style) el.setAttribute("style", attrs.style);
    const p = document.createElementNS(NS, "path");
    p.setAttribute("d", path);
    el.appendChild(p);
    return el;
  }

  // h("div.cls", {attrs, onEvent}, ...children)
  function h(tag, props, ...children) {
    const [name, ...classes] = tag.split(".");
    const el = document.createElement(name);
    if (classes.length) el.className = classes.join(" ");
    for (const [k, v] of Object.entries(props || {})) {
      if (v === undefined || v === null || v === false) continue;
      if (k.startsWith("on")) el.addEventListener(k.slice(2).toLowerCase(), v);
      else if (k === "style") el.setAttribute("style", v);
      else if (k === "text") el.textContent = v;
      else if (k === "value" || k === "placeholder" || k === "inputMode" || k === "title") el[k] = v;
      else el.setAttribute(k, v === true ? "" : v);
    }
    for (const c of children.flat()) {
      if (c === null || c === undefined || c === false) continue;
      el.appendChild(typeof c === "string" ? document.createTextNode(c) : c);
    }
    return el;
  }

  // ---------- Stored value <-> draft ----------
  function toDraft(subId, raw, ctx) {
    const def = SUBS[subId];
    if (def.type === "list") {
      return (Array.isArray(raw) ? raw : []).map((it, i) => {
        const d = def.blank();
        for (const f of def.fields) {
          if (f.t === "color") d[f.k] = it[f.k] ?? (subId === "outros" ? "accent" : COLORS[i % COLORS.length].key);
          else d[f.k] = str(it[f.k]) || (f.t === "icon" ? d[f.k] : "");
        }
        return d;
      });
    }
    if (def.type === "form") {
      const src = raw && typeof raw === "object" ? raw : {};
      const d = {};
      for (const f of [...def.fields, ...(def.adv || [])]) d[f.k] = str(src[f.k]);
      return d;
    }
    if (def.type === "cards") {
      const src = raw && typeof raw === "object" ? raw : {};
      return def.slots.map((slot) => {
        const s = src[slot] || {};
        const d = {};
        for (const f of def.fields) d[f.k] = str(s[f.k]);
        return d;
      });
    }
    if (def.type === "areas") {
      // A save from before rooms pointed at real areas (a free-typed `name`,
      // no `areaId`) is matched by name — same migration as RoomsStore.read.
      const byId = {};
      const byName = {};
      (Array.isArray(raw) ? raw : []).forEach((it) => {
        if (it.areaId) byId[it.areaId] = it;
        else if (it.name) byName[String(it.name).trim().toLowerCase()] = it;
      });
      const d = {};
      for (const a of ctx.areas) {
        const it = byId[a.area_id] || byName[(a.name || "").trim().toLowerCase()] || {};
        d[a.area_id] = {};
        for (const f of def.fields) d[a.area_id][f.k] = str(it[f.k]);
      }
      return d;
    }
    return raw;
  }

  function fromDraft(subId, draft, ctx) {
    const def = SUBS[subId];
    const val = (v) => (str(v).trim() === "" ? null : str(v).trim());
    if (def.type === "list") {
      const kept = draft.filter((it) => str(it[def.req]).trim());
      return {
        dropped: draft.length - kept.length,
        value: kept.map((it) => {
          const out = {};
          for (const f of def.fields) out[f.k] = f.t === "color" ? it[f.k] : val(it[f.k]);
          // A consumption with no name is labelled after its sensor.
          if (subId === "consumos" && !out.name) out.name = ctx.entityName(out.powerEntityId);
          return out;
        }),
      };
    }
    if (def.type === "form") {
      const out = {};
      for (const f of def.fields) out[f.k] = val(draft[f.k]);
      for (const f of def.adv || []) out[f.k] = str(draft[f.k]).trim() === "" ? null : Number(draft[f.k]);
      return { dropped: 0, value: out };
    }
    if (def.type === "cards") {
      const out = {};
      def.slots.forEach((slot, i) => {
        out[slot] = {};
        for (const f of def.fields) out[slot][f.k] = val(draft[i][f.k]);
      });
      return { dropped: 0, value: out };
    }
    if (def.type === "areas") {
      // Areas with nothing configured aren't saved as rooms at all.
      const out = [];
      for (const a of ctx.areas) {
        const it = draft[a.area_id] || {};
        if (!def.fields.some((f) => str(it[f.k]).trim())) continue;
        const row = { areaId: a.area_id };
        for (const f of def.fields) row[f.k] = val(it[f.k]);
        out.push(row);
      }
      return { dropped: 0, value: out };
    }
    return { dropped: 0, value: draft };
  }

  const STYLE = `
    :host { display:block; height:100%; }
    .ha {
      --fd-bg: var(--primary-background-color, #FAFAFA);
      --fd-card: var(--card-background-color, #FFFFFF);
      --fd-text: var(--primary-text-color, #212121);
      --fd-sec: var(--secondary-text-color, #727272);
      --fd-border: var(--divider-color, #E0E0E0);
      --fd-primary: var(--primary-color, #03A9F4);
      --fd-error: var(--error-color, #DB4437);
      --fd-warn: var(--warning-color, #FFA600);
      --fd-ok: var(--success-color, #43A047);
      --fd-faint: color-mix(in srgb, var(--fd-sec) 45%, transparent);
      --fd-input: color-mix(in srgb, var(--fd-text) 4%, var(--fd-card));
      --fd-menu: color-mix(in srgb, var(--fd-text) 3%, var(--fd-card));
      --fd-primary-text: color-mix(in srgb, var(--fd-primary) 72%, var(--fd-text));
      --fd-primary-tint: color-mix(in srgb, var(--fd-primary) 13%, transparent);
      --fd-row-sel: color-mix(in srgb, var(--fd-primary) 11%, transparent);
      --fd-warn-text: color-mix(in srgb, var(--fd-warn) 62%, var(--fd-text));
      --fd-warn-tint: color-mix(in srgb, var(--fd-warn) 14%, transparent);
      --fd-ok-text: color-mix(in srgb, var(--fd-ok) 75%, var(--fd-text));
      --fd-ok-tint: color-mix(in srgb, var(--fd-ok) 14%, transparent);
      --fd-info-tint: color-mix(in srgb, var(--fd-primary) 9%, transparent);
      --fd-neutral-tint: color-mix(in srgb, var(--fd-text) 6%, transparent);
      --fd-disabled-bg: color-mix(in srgb, var(--fd-text) 10%, transparent);
      --fd-disabled-fg: color-mix(in srgb, var(--fd-text) 40%, transparent);
      position:relative; height:100%; display:flex; flex-direction:column; background:var(--fd-bg); color:var(--fd-text);
      font-family: var(--ha-font-family-body, Roboto, system-ui, sans-serif); font-size:14px; -webkit-font-smoothing:antialiased;
    }
    button { font-family:inherit; cursor:pointer; transition: background-color .15s ease, color .15s ease, border-color .15s ease, box-shadow .15s ease, transform .12s ease; }
    button:active { transform: scale(.97); }
    input { font-family:inherit; }
    input::placeholder { color:inherit; opacity:.55; }
    @keyframes fdViewIn { from { opacity:0; transform:translateY(16px) } to { opacity:1; transform:none } }
    @keyframes fdFade { from { opacity:0 } to { opacity:1 } }
    @keyframes fdDrop { from { opacity:0; transform:translateY(-6px) } to { opacity:1; transform:none } }
    @keyframes fdSlideUp { from { opacity:0; transform:translateY(24px) } to { opacity:1; transform:none } }
    @keyframes fdModalIn { from { opacity:0; transform:translateY(24px) scale(.97) } to { opacity:1; transform:none } }
    @keyframes fdSpin { to { transform: rotate(360deg) } }
    @media (prefers-reduced-motion: reduce) { * { animation-duration:1ms !important; transition-duration:1ms !important } }

    .toolbar { height:56px; flex-shrink:0; box-sizing:border-box; display:flex; align-items:center; gap:12px; padding:0 var(--gutter); background:var(--fd-card); border-bottom:1px solid var(--fd-border); }
    .toolbar .title { font-size:20px; font-weight:400; }
    .icon-btn { width:40px; height:40px; border-radius:50%; border:0; background:transparent; color:var(--fd-sec); display:flex; align-items:center; justify-content:center; padding:0; flex-shrink:0; }
    .icon-btn:hover { background:var(--fd-neutral-tint); }
    .icon-btn[aria-disabled="true"] { color:var(--fd-faint); cursor:default; }
    .icon-btn[aria-disabled="true"]:hover { background:transparent; }
    .scroll { flex:1; min-height:0; overflow-y:auto; position:relative; }
    .page { max-width:920px; margin:0 auto; box-sizing:border-box; display:flex; flex-direction:column; }
    .page.enter { animation: fdViewIn .32s cubic-bezier(.2,.8,.2,1) both; }
    h1 { margin:0; font-size:var(--h1); font-weight:400; }
    .lead { margin:0; color:var(--fd-sec); font-size:14px; line-height:1.5; }

    .status { display:flex; align-items:center; gap:14px; padding:14px 16px; border-radius:12px; background:var(--fd-card); border:1px solid var(--fd-border); }
    .status .badge { width:40px; height:40px; border-radius:50%; display:flex; align-items:center; justify-content:center; flex-shrink:0; }
    .status .t { font-size:15px; font-weight:500; }
    .status .s { color:var(--fd-sec); font-size:13px; }
    .status .led { width:10px; height:10px; border-radius:50%; flex-shrink:0; }

    .tiles { display:grid; gap:16px; grid-template-columns:repeat(3, minmax(0,1fr)); }
    .tile { text-align:left; border:1px solid var(--fd-border); background:var(--fd-card); color:var(--fd-text); border-radius:12px; padding:20px; display:flex; flex-direction:column; align-items:flex-start; gap:14px; min-height:200px; box-sizing:border-box; }
    .tile:hover { box-shadow:0 2px 10px rgba(0,0,0,.08); }
    .tile .ic { width:48px; height:48px; border-radius:50%; background:var(--fd-primary-tint); color:var(--fd-primary-text); display:flex; align-items:center; justify-content:center; flex-shrink:0; }
    .tile .body { flex:1; align-self:stretch; min-width:0; display:flex; flex-direction:column; gap:4px; }
    .tile .tt { font-size:17px; font-weight:500; }
    .tile .dd { color:var(--fd-sec); font-size:13.5px; line-height:1.4; }
    .tile .foot { margin-top:auto; padding-top:10px; display:flex; }
    .chip { display:inline-flex; align-items:center; gap:6px; height:28px; padding:0 12px 0 8px; border-radius:14px; font-size:13px; font-weight:500; max-width:100%; box-sizing:border-box; }
    .chip span { white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .chip.ok { background:var(--fd-ok-tint); color:var(--fd-ok-text); }
    .chip.warn { background:var(--fd-warn-tint); color:var(--fd-warn-text); }
    .chip.info { background:var(--fd-neutral-tint); color:var(--fd-sec); }
    .mobile .tiles { grid-template-columns:1fr; gap:10px; }
    .mobile .tile { flex-direction:row; padding:14px; min-height:0; }

    .back { align-self:flex-start; height:36px; padding:0 12px 0 6px; margin-left:-6px; border:0; border-radius:18px; background:transparent; color:var(--fd-primary-text); display:flex; align-items:center; gap:6px; font-size:14px; font-weight:500; }
    .back:hover { background:var(--fd-primary-tint); }
    .sec-title { display:flex; align-items:center; gap:14px; }
    .sec-title .ic { width:44px; height:44px; border-radius:50%; background:var(--fd-primary-tint); color:var(--fd-primary-text); display:flex; align-items:center; justify-content:center; flex-shrink:0; }
    .sub { display:flex; flex-direction:column; gap:10px; padding-top:16px; }
    .sub-head { display:flex; align-items:center; gap:10px; min-height:24px; }
    .sub-head h2 { margin:0; font-size:12px; font-weight:500; letter-spacing:1.2px; text-transform:uppercase; color:var(--fd-sec); }
    .dirty { display:inline-flex; align-items:center; gap:6px; font-size:12px; font-weight:500; color:var(--fd-warn-text); animation: fdFade .2s ease both; }
    .dirty i { width:7px; height:7px; border-radius:50%; background:var(--fd-warn); }
    .count { font-size:12px; color:var(--fd-sec); margin-left:auto; }
    .hint { margin:-4px 0 2px; font-size:13px; color:var(--fd-sec); line-height:1.45; }
    .stack { display:flex; flex-direction:column; gap:12px; }
    .floor-group { display:flex; flex-direction:column; gap:8px; }
    .floor-group + .floor-group { margin-top:12px; }
    .floor { font-size:13px; font-weight:500; display:flex; align-items:center; gap:8px; padding:4px 4px 0; }

    .card { background:var(--fd-card); border:1px solid var(--fd-border); border-radius:12px; position:relative; }
    .card.raised { z-index:30; }
    .card-head { display:flex; align-items:center; gap:12px; min-height:40px; padding:12px 12px 12px 20px; }
    .card-head + .grid { border-top:1px solid var(--fd-border); }
    .mobile .card-head { padding:10px 8px 10px 16px; }
    .card-head .dot { width:14px; height:14px; border-radius:50%; flex-shrink:0; }
    .card-head .hic { width:36px; height:36px; border-radius:50%; display:flex; align-items:center; justify-content:center; flex-shrink:0; }
    .card-head .txt { flex:1; min-width:0; display:flex; flex-direction:column; gap:2px; }
    .card-head .tt { font-size:16px; font-weight:500; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .card-head .ss { font-size:13px; color:var(--fd-sec); display:flex; align-items:center; gap:6px; }
    .card-head .ss.warn { color:var(--fd-warn-text); }
    .card-head .moves { display:flex; gap:2px; }
    .grid { display:grid; grid-template-columns:repeat(2, minmax(0,1fr)); gap:16px 20px; padding:18px 20px; }
    .mobile .grid { grid-template-columns:minmax(0,1fr); padding:16px; }
    .grid .full { grid-column:1 / -1; }
    .empty { display:flex; align-items:center; gap:12px; color:var(--fd-sec); font-size:14px; line-height:1.45; padding:18px 20px; }
    .note { display:flex; align-items:flex-start; gap:10px; padding:10px 12px; border-radius:8px; background:var(--fd-info-tint); font-size:13px; line-height:1.45; }
    .adv { width:100%; height:44px; border:0; background:transparent; color:var(--fd-text); display:flex; align-items:center; gap:10px; padding:0; font-size:14px; font-weight:500; text-align:left; }
    .adv:active { transform:none; }
    .adv .lbl { flex:1; }
    .adv .val { font-weight:400; color:var(--fd-sec); font-size:13px; }

    .field { display:flex; flex-direction:column; gap:6px; min-width:0; }
    .field label { font-size:13px; font-weight:500; }
    .field label .req { color:var(--fd-error); }
    .field label .optional { font-weight:400; color:var(--fd-sec); }
    .help { font-size:12.5px; color:var(--fd-sec); line-height:1.4; }
    .help.warn { color:var(--fd-warn-text); }
    .textbox { height:48px; display:flex; align-items:center; gap:8px; padding:0 14px; border-radius:8px; background:var(--fd-input); border:1px solid var(--fd-border); box-sizing:border-box; }
    .textbox:focus-within { border-color:var(--fd-primary); box-shadow:0 0 0 1px var(--fd-primary); }
    .textbox input { flex:1; min-width:0; height:44px; border:0; outline:none; background:transparent; color:var(--fd-text); font-size:15px; }
    .textbox .suffix { color:var(--fd-sec); font-size:14px; }

    .picker { position:relative; }
    .pick-btn { width:100%; min-height:56px; display:flex; align-items:center; gap:12px; padding:6px 8px 6px 14px; border-radius:8px; background:var(--fd-input); border:1px solid var(--fd-border); box-sizing:border-box; color:var(--fd-text); text-align:left; }
    .pick-btn:active { transform:none; }
    .pick-btn.open { border-color:var(--fd-primary); box-shadow:0 0 0 1px var(--fd-primary); }
    .pick-btn.missing { border-color:var(--fd-warn); }
    .pick-btn .txt { flex:1; min-width:0; display:flex; flex-direction:column; gap:1px; }
    .pick-btn .nm { font-size:15px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .pick-btn .nm.empty { color:var(--fd-sec); }
    .pick-btn .meta { font-size:12.5px; color:var(--fd-sec); white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .pick-btn .clear { width:36px; height:36px; border-radius:50%; color:var(--fd-sec); display:flex; align-items:center; justify-content:center; flex-shrink:0; }
    .pick-btn .clear:hover { background:var(--fd-neutral-tint); }
    .menu { position:absolute; left:0; right:0; top:calc(100% + 4px); z-index:40; background:var(--fd-menu); border-radius:12px; box-shadow:0 8px 28px rgba(0,0,0,.22), 0 0 0 1px var(--fd-border); overflow:hidden; animation: fdDrop .16s ease-out both; }
    .menu .search { display:flex; align-items:center; gap:10px; padding:0 14px; height:52px; border-bottom:1px solid var(--fd-border); }
    .menu .search input { flex:1; min-width:0; height:48px; border:0; outline:none; background:transparent; color:var(--fd-text); font-size:15px; }
    .menu .opts { max-height:300px; overflow-y:auto; padding:4px 0; }
    .opt { width:100%; min-height:56px; border:0; background:transparent; color:var(--fd-text); display:flex; align-items:center; gap:14px; padding:6px 14px; text-align:left; }
    .opt:active { transform:none; }
    .opt:hover { background:var(--fd-neutral-tint); }
    .opt.on { background:var(--fd-row-sel); }
    .opt .txt { flex:1; min-width:0; display:flex; flex-direction:column; gap:1px; }
    .opt .nm { font-size:15px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .opt .id, .opt .area { font-size:12.5px; color:var(--fd-sec); white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .opt .area { max-width:40%; }
    .menu .none { padding:18px 16px; color:var(--fd-sec); font-size:14px; }
    .menu .foot { padding:8px 14px; border-top:1px solid var(--fd-border); font-size:12px; color:var(--fd-sec); }

    .swatches { display:flex; align-items:center; gap:12px; min-height:48px; flex-wrap:wrap; }
    .swatch { width:36px; height:36px; border-radius:50%; border:0; padding:0; display:flex; align-items:center; justify-content:center; }
    .icons { display:flex; flex-wrap:wrap; gap:8px; }
    .icon-opt { width:48px; height:48px; border-radius:10px; border:1.5px solid var(--fd-border); background:transparent; color:var(--fd-sec); display:flex; align-items:center; justify-content:center; padding:0; }
    .icon-opt.on { border-color:var(--fd-primary); background:var(--fd-primary-tint); color:var(--fd-primary-text); }

    .add { align-self:flex-start; height:40px; padding:0 18px 0 12px; border-radius:20px; border:1px solid var(--fd-primary-text); background:transparent; color:var(--fd-primary-text); display:flex; align-items:center; gap:8px; font-size:14px; font-weight:500; }
    .add:hover { background:var(--fd-primary-tint); }
    .add[aria-disabled="true"] { border-color:var(--fd-border); color:var(--fd-disabled-fg); cursor:default; background:transparent; }

    .bar-wrap { position:absolute; left:0; right:0; bottom:0; z-index:20; padding:0 24px 20px; pointer-events:none; }
    .bar-wrap.enter { animation: fdSlideUp .3s cubic-bezier(.2,.8,.2,1) both; }
    .mobile .bar-wrap { padding:0 8px 8px; }
    .bar { max-width:872px; margin:0 auto; pointer-events:auto; display:flex; align-items:center; gap:12px; padding:12px 12px 12px 18px; border-radius:12px; background:var(--fd-card); border:1px solid var(--fd-border); box-shadow:0 6px 24px rgba(0,0,0,.14); box-sizing:border-box; }
    .mobile .bar { flex-direction:column; align-items:stretch; }
    .bar .msg { flex:1; min-width:0; display:flex; align-items:center; gap:10px; font-size:14px; line-height:1.4; }
    .bar .msg strong { font-weight:500; }
    .bar .acts { display:flex; gap:8px; flex-shrink:0; justify-content:flex-end; }
    .spin { width:18px; height:18px; border-radius:50%; border:2.5px solid var(--fd-border); border-top-color:var(--fd-primary); animation: fdSpin .8s linear infinite; flex-shrink:0; box-sizing:border-box; }
    .btn-text { height:40px; padding:0 16px; border-radius:20px; border:0; background:transparent; color:var(--fd-primary-text); font-size:14px; font-weight:500; }
    .btn-text:hover { background:var(--fd-primary-tint); }
    .btn-text.danger { color:var(--fd-error); }
    .btn-fill { height:40px; padding:0 22px; border-radius:20px; border:0; background:var(--fd-primary); color:#FFFFFF; font-size:14px; font-weight:500; }
    .btn-fill[aria-disabled="true"] { background:var(--fd-disabled-bg); color:var(--fd-disabled-fg); cursor:default; }

    .scrim { position:absolute; inset:0; z-index:50; background:rgba(0,0,0,.45); display:flex; align-items:center; justify-content:center; padding:16px; box-sizing:border-box; animation: fdFade .2s ease both; }
    .dialog { width:100%; max-width:440px; background:var(--fd-menu); border-radius:24px; padding:24px; box-sizing:border-box; display:flex; flex-direction:column; gap:14px; box-shadow:0 16px 48px rgba(0,0,0,.3); animation: fdModalIn .25s cubic-bezier(.2,.8,.2,1) both; }
    .dialog h2 { margin:0; font-size:22px; font-weight:400; }
    .dialog .acts { display:flex; justify-content:flex-end; flex-wrap:wrap; gap:8px; padding-top:6px; }
    .loading { padding:48px 0; color:var(--fd-sec); text-align:center; }
    .error-box { padding:14px 16px; border-radius:12px; background:color-mix(in srgb, var(--fd-error) 12%, transparent); color:var(--fd-error); }
  `;

  class FlutterDashboardPanel extends HTMLElement {
    constructor() {
      super();
      this.attachShadow({ mode: "open" });
      this._hass = null;
      this._narrow = false;
      this._width = 1000;
      this._settings = null; // everything stored, as last loaded/saved
      this._loadError = null;
      this._areas = [];
      this._floorById = {};
      this._screens = undefined; // undefined: not asked yet; null: integration too old
      this._section = null;
      this._draft = {};
      this._saved = {};
      this._picker = null; // { sub, idx, k }
      this._pq = "";
      this._open = {}; // area id -> expanded
      this._adv = false;
      this._leave = false;
      this._saving = false;
      this._msg = null; // { kind: saving|ok|err, text }
    }

    set hass(hass) {
      const first = !this._hass;
      this._hass = hass;
      if (first) this._init();
    }
    get hass() {
      return this._hass;
    }
    set narrow(v) {
      const changed = this._narrow !== !!v;
      this._narrow = !!v;
      if (changed && this._hass) this._render();
    }
    set panel(v) {
      this._panel = v;
    }

    connectedCallback() {
      this._ro = new ResizeObserver(() => {
        const was = this._mobile;
        this._width = this.clientWidth;
        if (this._hass && was !== this._mobile) this._render();
      });
      this._ro.observe(this);
      this._screensTimer = setInterval(() => {
        if (!this._section) this._loadScreens();
      }, 15000);
      if (!this._keys) {
        this._keys = true;
        this.shadowRoot.addEventListener("keydown", (e) => {
          if (e.key === "Escape" && this._picker) {
            this._picker = null;
            this._render();
          }
        });
      }
      if (this._hass) this._render();
    }

    disconnectedCallback() {
      if (this._ro) this._ro.disconnect();
      clearInterval(this._screensTimer);
    }

    get _mobile() {
      return this._narrow || this._width < 700;
    }

    async _init() {
      this._render(true);
      await Promise.all([this._loadSettings(), this._loadScreens(), this._loadAreas()]);
      this._render();
    }

    _ws(type, extra = {}) {
      return this._hass.connection.sendMessagePromise({ type: `${DOMAIN}/${type}`, ...extra });
    }

    async _loadSettings() {
      try {
        const res = await this._ws("get_settings");
        this._settings = res.value || {};
        this._loadError = null;
      } catch (err) {
        this._loadError = err.message || String(err);
      }
    }

    async _loadScreens() {
      let next;
      try {
        next = (await this._ws("list_screens")).screens || [];
      } catch (_) {
        next = null; // integration older than the screen registry
      }
      const changed = JSON.stringify(next) !== JSON.stringify(this._screens);
      this._screens = next;
      if (changed && !this._section && this._settings) this._render();
    }

    async _loadAreas() {
      try {
        const [areas, floors] = await Promise.all([
          this._hass.callWS({ type: "config/area_registry/list" }),
          this._hass.callWS({ type: "config/floor_registry/list" }).catch(() => []),
        ]);
        const floorById = {};
        floors.forEach((f) => (floorById[f.floor_id] = f));
        const level = (a) => {
          const f = floorById[a.floor_id];
          return f && typeof f.level === "number" ? f.level : Number.MAX_SAFE_INTEGER;
        };
        this._areas = [...areas].sort((a, b) => level(a) - level(b) || (a.name || "").localeCompare(b.name || ""));
        this._floorById = floorById;
      } catch (_) {
        this._areas = [];
        this._floorById = {};
      }
    }

    // ---------- Entities ----------
    _entityName(id) {
      if (!id) return "";
      const st = this._hass.states[id];
      return (st && st.attributes && st.attributes.friendly_name) || (id.split(".")[1] || id).replace(/_/g, " ");
    }

    _entityArea(id) {
      const hs = this._hass;
      const reg = hs.entities && hs.entities[id];
      if (!reg) return "";
      let areaId = reg.area_id;
      if (!areaId && reg.device_id && hs.devices && hs.devices[reg.device_id]) areaId = hs.devices[reg.device_id].area_id;
      return (areaId && hs.areas && hs.areas[areaId] && hs.areas[areaId].name) || "";
    }

    _entityIcon(id) {
      const d = id.split(".")[0];
      const n = (id + " " + this._entityName(id)).toLowerCase();
      const st = this._hass.states[id];
      const dc = (st && st.attributes && st.attributes.device_class) || "";
      if (d === "sensor") {
        if (dc === "temperature" || /temperatur/.test(n)) return I.thermo;
        if (dc === "power" || dc === "energy" || /pot[eê]ncia|power|consumo/.test(n)) return I.flash;
        if (dc === "battery" || /bateria|battery|soc/.test(n)) return I.battery;
        return I.gauge;
      }
      if (d === "binary_sensor") {
        if (dc === "window" || dc === "door" || dc === "opening" || /janela|window/.test(n)) return I.window;
        if (dc === "battery_charging" || /carreg|charging/.test(n)) return I.flash;
        if (dc === "plug" || /ficha|plug/.test(n)) return I.plug;
        return I.toggle;
      }
      if (d === "cover") return dc === "garage" || dc === "gate" || /garag|port[aã]o|gate/.test(n) ? I.home : I.cover;
      const byDomain = { calendar: I.cal, weather: I.weather, light: I.light, switch: I.toggle, climate: I.climate, lock: I.lock, alarm_control_panel: I.alarm, water_heater: I.heatpump, scene: I.scene, script: I.script, camera: I.camera, number: I.gauge };
      return byDomain[d] || I.dot;
    }

    _entityOptions(dom, q) {
      const query = q.trim().toLowerCase();
      return Object.keys(this._hass.states)
        .filter((id) => !dom || dom.includes(id.split(".")[0]))
        .map((id) => ({ id, name: this._entityName(id), area: this._entityArea(id) }))
        .filter((o) => !query || (o.id + " " + o.name + " " + o.area).toLowerCase().includes(query))
        .sort((a, b) => a.name.localeCompare(b.name));
    }

    // ---------- Navigation / state ----------
    _ctx() {
      return { areas: this._areas, entityName: (id) => this._entityName(id) };
    }

    _openSection(id) {
      const sec = SECTIONS.find((s) => s.id === id);
      this._section = sec;
      this._draft = {};
      this._saved = {};
      for (const sub of sec.subs) {
        const d = toDraft(sub, this._settings ? this._settings[SUBS[sub].store] : undefined, this._ctx());
        this._draft[sub] = d;
        this._saved[sub] = clone(d);
      }
      this._picker = null;
      this._msg = null;
      this._adv = false;
      this._open = {};
      this._render(true);
    }

    _goHome() {
      this._section = null;
      this._leave = false;
      this._picker = null;
      this._msg = null;
      this._render(true);
      this._loadScreens();
    }

    _dirtySubs() {
      if (!this._section) return [];
      return this._section.subs.filter((s) => !same(this._draft[s], this._saved[s]));
    }

    // Typing doesn't rebuild the page (the input would lose its caret): it
    // only refreshes the "Alterado" badges, the item titles and the bar.
    _touch(fullRender) {
      if (this._msg && this._msg.kind !== "saving") this._msg = null;
      if (fullRender) return this._render();
      const root = this.shadowRoot;
      for (const sub of this._section.subs) {
        const badge = root.querySelector(`[data-dirty="${sub}"]`);
        if (badge) badge.style.display = same(this._draft[sub], this._saved[sub]) ? "none" : "";
      }
      root.querySelectorAll("[data-title]").forEach((el) => {
        const [sub, i] = el.dataset.title.split(":");
        el.textContent = sub === "carros" ? this._carSub(Number(i)) : this._itemTitle(sub, Number(i));
      });
      const bar = root.querySelector(".bar-wrap");
      if (bar) bar.replaceWith(this._renderBar(false));
    }

    async _save(after) {
      const dirty = this._dirtySubs();
      if (!dirty.length || this._saving) return;
      this._saving = true;
      this._picker = null;
      this._msg = { kind: "saving" };
      this._render();
      const dropped = [];
      try {
        for (const sub of dirty) {
          const def = SUBS[sub];
          const { value, dropped: n } = fromDraft(sub, this._draft[sub], this._ctx());
          await this._ws("set_settings", { key: def.store, value });
          this._settings = { ...(this._settings || {}), [def.store]: value };
          if (n) dropped.push(`${n} ${n === 1 ? def.noun[0] : def.noun[1]} sem ${def.reqLabel} ${n === 1 ? "foi descartado" : "foram descartados"}`);
          const fresh = toDraft(sub, value, this._ctx());
          this._draft[sub] = fresh;
          this._saved[sub] = clone(fresh);
        }
        this._saving = false;
        this._msg = { kind: "ok", text: dropped.length ? joinPt(dropped) + "." : "" };
        this._render();
        if (after) after();
      } catch (_) {
        this._saving = false;
        this._msg = { kind: "err", text: "O Home Assistant não respondeu. As alterações continuam aqui." };
        this._render();
      }
    }

    _discard() {
      for (const sub of this._section.subs) this._draft[sub] = clone(this._saved[sub]);
      this._msg = null;
      this._picker = null;
      this._render();
    }

    // ---------- Rendering ----------
    // `entering` (a new view) restarts the scroll and plays the fade-up.
    _render(entering) {
      if (!this._hass) return;
      const root = this.shadowRoot;
      const prevScroll = root.querySelector(".scroll");
      const keepScroll = prevScroll && !entering ? prevScroll.scrollTop : 0;
      const mobile = this._mobile;
      const gutter = mobile ? 16 : 24;

      const wrap = h("div.ha" + (mobile ? ".mobile" : ""), { style: `--gutter:${gutter}px; --h1:${mobile ? 26 : 32}px` });
      const toolbar = h(
        "header.toolbar",
        {},
        this._narrow
          ? h("button.icon-btn", { "aria-label": "Menu", onClick: () => this.dispatchEvent(new Event("hass-toggle-menu", { bubbles: true, composed: true })) }, svg(I.menu, 24, { sw: 2 }))
          : null,
        h("span.title", { text: "Flutter Dashboard" })
      );
      const scroll = h("div.scroll", {
        onClick: (e) => {
          if (this._picker && !e.composedPath().some((n) => n.dataset && n.dataset.picker !== undefined)) {
            this._picker = null;
            this._render();
          }
        },
      });
      const page = this._section ? this._renderSection(gutter) : this._renderHome(gutter);
      if (entering) page.classList.add("enter");
      scroll.appendChild(page);
      wrap.append(toolbar, scroll);
      if (this._section) wrap.appendChild(this._renderBar(entering));
      if (this._leave && this._section) wrap.appendChild(this._renderLeave());

      root.innerHTML = "";
      root.appendChild(h("style", { text: STYLE }));
      root.appendChild(wrap);
      scroll.scrollTop = keepScroll;
      const search = root.querySelector("[data-search]");
      if (search) search.focus({ preventScroll: true });
    }

    _renderHome(gutter) {
      const mobile = this._mobile;
      const page = h("div.page", { style: `padding:${mobile ? 20 : 28}px ${gutter}px 48px; gap:20px` });
      page.appendChild(
        h(
          "div",
          { style: "display:flex; flex-direction:column; gap:6px" },
          h("h1", { text: "Configurar o ecrã" }),
          h("p.lead", { text: "O que o ecrã mostra e de que entidades lê os dados. As refeições, tarefas e listas editam-se no próprio ecrã." })
        )
      );
      if (this._screens !== undefined) page.appendChild(this._renderStatus());
      if (this._loadError) {
        page.appendChild(h("div.error-box", { text: `Não foi possível ler as definições: ${this._loadError}` }));
        return page;
      }
      if (!this._settings) {
        page.appendChild(h("div.loading", { text: "A carregar…" }));
        return page;
      }
      const tiles = h("div.tiles");
      for (const sec of SECTIONS) {
        const sm = this._summary(sec.id);
        tiles.appendChild(
          h(
            "button.tile",
            { "aria-label": `${sec.title}: ${sm.text}`, onClick: () => this._openSection(sec.id) },
            h("span.ic", {}, svg(sec.icon, 26)),
            h(
              "span.body",
              {},
              h("span.tt", { text: sec.title }),
              h("span.dd", { text: sec.desc }),
              h(
                "span.foot",
                {},
                h("span.chip." + sm.kind, {}, svg(sm.kind === "ok" ? I.check : sm.kind === "warn" ? I.alert : I.info, 16, { sw: 2.4, style: "flex-shrink:0" }), h("span", { text: sm.text }))
              )
            ),
            mobile ? svg(I.chevronRight, 22, { sw: 2, style: "flex-shrink:0; color:var(--fd-sec)" }) : null
          )
        );
      }
      page.appendChild(tiles);
      return page;
    }

    _renderStatus() {
      const screens = this._screens;
      let title;
      let sub;
      let on = false;
      if (screens === null) {
        title = "Estado do ecrã desconhecido";
        sub = "Reinicie o Home Assistant depois de atualizar a integração para ver aqui se o ecrã está ligado.";
      } else if (!screens.length) {
        title = "Nenhum ecrã ligado";
        sub = "O ecrã aparece aqui quando estiver ligado ao Home Assistant.";
      } else {
        on = true;
        title = screens.length === 1 ? `Ecrã ${screens[0].name} ligado` : `${screens.length} ecrãs ligados`;
        sub = `${screens.length > 1 ? screens.map((s) => s.name).join(", ") + " · " : ""}As alterações guardadas aparecem no ecrã em poucos segundos.`;
      }
      return h(
        "div.status",
        {},
        h("span.badge", { style: on ? "background:var(--fd-ok-tint); color:var(--fd-ok)" : "background:var(--fd-neutral-tint); color:var(--fd-sec)" }, svg(I.screen, 22)),
        h("div", { style: "flex:1; min-width:0; display:flex; flex-direction:column; gap:2px" }, h("span.t", { text: title }), h("span.s", { text: sub })),
        h("span.led", { style: `background:${on ? "var(--fd-ok)" : "var(--fd-faint)"}` })
      );
    }

    _summary(id) {
      const S = this._settings || {};
      const chip = (text, kind) => ({ text, kind });
      const arr = (k) => (Array.isArray(S[k]) ? S[k] : []);
      const obj = (k) => (S[k] && typeof S[k] === "object" && !Array.isArray(S[k]) ? S[k] : {});
      if (id === "familia") {
        const n = arr("family_members").length;
        return n ? chip(`${n} ${n === 1 ? "pessoa" : "pessoas"}`, "ok") : chip("A usar as pessoas do HA", "info");
      }
      if (id === "calendarios") {
        const cals = arr("calendar_entities");
        return cals.length ? chip(cals.map((c) => this._entityName(c.entityId).replace(/ em Portugal$/i, "")).join(" · "), "ok") : chip("Nenhum", "info");
      }
      if (id === "meteo") {
        const m = obj("temperature_entities");
        const n = (m.exteriorTempEntityId ? 1 : 0) + (m.weatherStateEntityId ? 1 : 0);
        return n === 2 ? chip("Configurada", "ok") : chip(`${n} de 2 configurados`, "warn");
      }
      if (id === "divisoes") {
        const ids = new Set(this._areas.map((a) => a.area_id));
        const k = arr("rooms").filter((r) => ids.has(r.areaId)).length;
        return chip(`${k} de ${this._areas.length} áreas`, k && k === this._areas.length ? "ok" : "info");
      }
      if (id === "casa") {
        const hs = obj("house_screen");
        const sc = arr("house_scenes").length;
        const cam = arr("house_cameras").length;
        return chip(`${hs.alarmEntityId ? "Alarme · " : ""}${sc} ${sc === 1 ? "cenário" : "cenários"} · ${cam} ${cam === 1 ? "câmara" : "câmaras"}`, hs.alarmEntityId ? "ok" : "warn");
      }
      if (id === "energia") {
        const e = obj("energy_entities");
        const fl = ["solarPowerEntityId", "gridPowerEntityId", "batteryPowerEntityId", "batterySocEntityId", "homePowerEntityId"].filter((k) => e[k]).length;
        const n = arr("individual_sensors").length;
        return chip(`${fl} de 5 sensores · ${n} ${n === 1 ? "consumo" : "consumos"}`, fl === 5 ? "ok" : "warn");
      }
      if (id === "carros") {
        const ev = obj("ev_cars");
        const cars = ["left", "right"].map((s) => ev[s] || {}).filter((c) => c.batterySocEntityId);
        if (!cars.length) return chip("Nenhum carro", "info");
        const missing = cars.reduce((n, c) => n + SUBS.carros.fields.filter((f) => f.k !== "name" && !c[f.k]).length, 0);
        const tail = missing ? ` · ${missing === 1 ? "falta 1 campo" : `faltam ${missing} campos`}` : "";
        return chip(`${cars.length} ${cars.length === 1 ? "carro" : "carros"}${tail}`, missing ? "warn" : "ok");
      }
      return chip("", "info");
    }

    _renderSection(gutter) {
      const sec = this._section;
      const page = h("div.page", { style: `padding:12px ${gutter}px ${this._mobile ? 150 : 120}px; gap:8px` });
      const back = () => {
        if (!this._dirtySubs().length) return this._goHome();
        this._leave = true;
        this._picker = null;
        this._render();
      };
      page.appendChild(
        h(
          "div",
          { style: "display:flex; flex-direction:column; gap:6px; padding-bottom:8px" },
          h("button.back", { onClick: back }, svg(I.back, 20, { sw: 2 }), "Voltar"),
          h("div.sec-title", {}, h("span.ic", {}, svg(sec.icon, 24)), h("h1", { text: sec.title })),
          h("p.lead", { text: sec.intro })
        )
      );
      for (const sub of sec.subs) page.appendChild(this._renderSub(sub));
      return page;
    }

    _renderSub(subId) {
      const def = SUBS[subId];
      const d = this._draft[subId];
      let count = "";
      if (def.type === "list" && d.length) count = `${d.length} ${d.length === 1 ? def.noun[0] : def.noun[1]}${def.max ? ` de ${def.max}` : ""}`;
      if (def.type === "areas") {
        const n = this._areas.filter((a) => this._areaCount(d[a.area_id]) > 0).length;
        count = `${n} de ${this._areas.length} áreas configuradas`;
      }
      const section = h(
        "section.sub",
        { "aria-label": def.title },
        h(
          "div.sub-head",
          {},
          h("h2", { text: def.title }),
          h("span.dirty", { "data-dirty": subId, style: same(d, this._saved[subId]) ? "display:none" : "" }, h("i"), "Alterado"),
          count ? h("span.count", { text: count }) : null
        ),
        def.hint ? h("p.hint", { text: def.hint }) : null
      );
      if (def.type === "form") section.appendChild(this._renderFormCard(subId));
      else if (def.type === "list") section.appendChild(this._renderList(subId));
      else if (def.type === "cards") section.appendChild(this._renderCars(subId));
      else if (def.type === "areas") section.appendChild(this._renderAreas(subId));
      return section;
    }

    // Fields two to a row; one marked full (or left alone at the end of a
    // run) spans both. One column on a phone.
    _grid(subId, idx, item, fields, opts = {}) {
      const grid = h("div.grid");
      const cols = this._mobile ? 1 : 2;
      const cells = fields.map((f) => ({ f, full: cols === 1 || !!f.full || (f.t === "color" && subId !== "outros") }));
      let pending = null;
      for (const c of cells) {
        if (c.full) {
          if (pending) pending.full = true;
          pending = null;
        } else if (pending) {
          pending = null;
        } else {
          pending = c;
        }
      }
      if (pending) pending.full = true;
      for (const c of cells) {
        const el = this._field(c.f, subId, idx, item, opts);
        if (c.full) el.classList.add("full");
        grid.appendChild(el);
      }
      return grid;
    }

    _renderFormCard(subId) {
      const def = SUBS[subId];
      const d = this._draft[subId];
      const card = h("div.card" + (this._picker && this._picker.sub === subId ? ".raised" : ""));
      const grid = this._grid(subId, -1, d, def.fields);
      card.appendChild(grid);
      if (def.adv) {
        const values = def.adv.map((f) => str(d[f.k]).trim() || "10");
        const allSame = values.every((v) => v === values[0]);
        grid.appendChild(
          h(
            "button.adv.full",
            {
              "aria-expanded": this._adv ? "true" : "false",
              onClick: () => {
                this._adv = !this._adv;
                this._render();
              },
            },
            svg(I.chevronRight, 20, { sw: 2, style: `color:var(--fd-sec); transform:rotate(${this._adv ? 90 : 0}deg); transition:transform .2s ease` }),
            h("span.lbl", { text: "Avançado" }),
            this._adv ? null : h("span.val", { text: allSame ? `Ignorar abaixo de ${values[0]} W` : "Limites por fonte" })
          )
        );
        if (this._adv) {
          for (const f of def.adv) grid.appendChild(this._field(f, subId, -1, d));
          grid.appendChild(
            h("div.note.full", {}, svg(I.info, 18, { style: "flex-shrink:0" }), h("span", { text: "O fluxo ignora valores abaixo destes limites, para não piscar com ruído dos sensores. Por defeito: 10 W." }))
          );
        }
      }
      return card;
    }

    _itemTitle(subId, i) {
      const def = SUBS[subId];
      const item = this._draft[subId][i];
      if (!item) return "";
      if (subId === "pessoas") return item.name.trim() || "Nova pessoa";
      if (subId === "outros") return item.entityId ? this._entityName(item.entityId) : "Novo calendário";
      if (str(item.name).trim()) return item.name;
      if (item[def.req]) return this._entityName(item[def.req]);
      return `Novo ${def.noun[0]}`;
    }

    _renderList(subId) {
      const def = SUBS[subId];
      const list = this._draft[subId];
      const stack = h("div.stack");
      if (!list.length) stack.appendChild(h("div.card", {}, h("div.empty", {}, svg(I.info, 22, { style: "flex-shrink:0" }), h("span", { text: def.empty }))));
      list.forEach((item, i) => {
        const missing = def.req && !str(item[def.req]).trim();
        let dot = null;
        let icon = null;
        if (subId === "pessoas") dot = COLORS[colorIndex(item.color, i % COLORS.length)].hex;
        else if (subId === "outros") dot = isHoliday(item.entityId + " " + this._entityName(item.entityId)) ? HOLIDAY_RED : COLORS[colorIndex(item.color, 3)].hex;
        else if (subId === "consumos") icon = (APPLIANCES.find((a) => a.key === item.icon) || APPLIANCES[5]).icon;
        else icon = item.entityId ? this._entityIcon(item.entityId) : def.itemIcon;
        let subText = "";
        if (missing) subText = `Falta ${def.reqLabel}: será descartado ao guardar`;
        else if (subId === "pessoas") subText = item.calendarEntityId ? `${this._entityName(item.calendarEntityId)} · calendário pessoal` : "Sem calendário pessoal";
        const titled = subId === "pessoas" ? !!item.name.trim() : subId === "outros" ? !!item.entityId : !!(str(item.name).trim() || item[def.req]);
        const move = (delta) => {
          const j = i + delta;
          if (j < 0 || j >= list.length) return;
          [list[i], list[j]] = [list[j], list[i]];
          this._touch(true);
        };
        const title = this._itemTitle(subId, i);
        const head = h(
          "div.card-head",
          {},
          dot ? h("span.dot", { style: `background:${dot}` }) : null,
          icon
            ? h("span.hic", { style: missing ? "background:var(--fd-warn-tint); color:var(--fd-warn-text)" : "background:var(--fd-primary-tint); color:var(--fd-primary-text)" }, svg(icon, 20))
            : null,
          h(
            "div.txt",
            {},
            h("span.tt", { "data-title": `${subId}:${i}`, text: title, style: titled ? "" : "color:var(--fd-sec)" }),
            subText ? h("span.ss" + (missing ? ".warn" : ""), {}, missing ? svg(I.alert, 14, { sw: 2.2 }) : null, subText) : null
          ),
          h(
            "div.moves",
            {},
            h("button.icon-btn", { "aria-label": `Subir ${title}`, "aria-disabled": i === 0 ? "true" : "false", onClick: () => move(-1) }, svg(I.up, 20, { sw: 2 })),
            h("button.icon-btn", { "aria-label": `Descer ${title}`, "aria-disabled": i === list.length - 1 ? "true" : "false", onClick: () => move(1) }, svg(I.down, 20, { sw: 2 })),
            h(
              "button.icon-btn",
              {
                "aria-label": `Remover ${title}`,
                onClick: () => {
                  list.splice(i, 1);
                  this._touch(true);
                },
              },
              svg(I.trash, 20)
            )
          )
        );
        const raised = this._picker && this._picker.sub === subId && this._picker.idx === i;
        stack.appendChild(h("div.card" + (raised ? ".raised" : ""), {}, head, this._grid(subId, i, item, def.fields, { flagMissing: true, reqLabel: def.reqLabel })));
      });
      const full = def.max && list.length >= def.max;
      const add = h(
        "button.add",
        {
          "aria-disabled": full ? "true" : "false",
          onClick: () => {
            if (full) return;
            const blank = def.blank();
            if (subId === "pessoas") blank.color = COLORS[list.length % COLORS.length].key;
            list.push(blank);
            this._touch(true);
          },
        },
        svg(full ? I.block : I.plus, 20, { sw: 2 }),
        full ? `Máximo de ${def.max} atingido` : def.add
      );
      return h("div.stack", {}, stack, add);
    }

    _carSub(i) {
      return str(this._draft.carros[i].name).trim() || "Sem nome";
    }

    _renderCars(subId) {
      const def = SUBS[subId];
      const stack = h("div.stack");
      this._draft[subId].forEach((item, i) => {
        const head = h(
          "div.card-head",
          {},
          h("span.hic", { style: "background:var(--fd-primary-tint); color:var(--fd-primary-text)" }, svg(I.car, 20)),
          h("div.txt", {}, h("span.tt", { text: def.titles[i] }), h("span.ss", { "data-title": `${subId}:${i}`, text: this._carSub(i) }))
        );
        const raised = this._picker && this._picker.sub === subId && this._picker.idx === i;
        stack.appendChild(h("div.card" + (raised ? ".raised" : ""), {}, head, this._grid(subId, i, item, def.fields)));
      });
      return stack;
    }

    _areaCount(a) {
      return SUBS.areas.fields.filter((f) => a && str(a[f.k]).trim()).length;
    }

    _renderAreas(subId) {
      const def = SUBS[subId];
      const d = this._draft[subId];
      const out = h("div");
      if (!this._areas.length) {
        out.appendChild(
          h("div.card", {}, h("div.empty", {}, svg(I.info, 22, { style: "flex-shrink:0" }), h("span", { text: "Nenhuma área no Home Assistant. Crie áreas em Definições › Áreas, etiquetas e zonas." })))
        );
        return out;
      }
      const fmt = (st, unit) => (st && !isNaN(parseFloat(st.state)) ? String(Math.round(parseFloat(st.state) * 10) / 10).replace(".", ",") + unit : null);
      let group = null;
      let lastFloor;
      for (const a of this._areas) {
        const floor = this._floorById[a.floor_id];
        const floorName = floor ? floor.name : "Sem piso";
        if (floorName !== lastFloor) {
          group = h("div.floor-group", {}, h("div.floor", {}, svg(I.floor, 16, { sw: 2, style: "color:var(--fd-sec)" }), floorName));
          out.appendChild(group);
          lastFloor = floorName;
        }
        const item = d[a.area_id];
        const n = this._areaCount(item);
        const open = !!this._open[a.area_id];
        const meta = [floorName, fmt(a.temperature_entity_id && this._hass.states[a.temperature_entity_id], " ºC"), fmt(a.humidity_entity_id && this._hass.states[a.humidity_entity_id], " %")]
          .filter(Boolean)
          .join(" · ");
        const toggle = () => {
          this._open[a.area_id] = !open;
          this._picker = null;
          this._render();
        };
        const head = h(
          "div.card-head",
          {},
          h("span.hic", { style: n ? "background:var(--fd-primary-tint); color:var(--fd-primary-text)" : "background:var(--fd-neutral-tint); color:var(--fd-sec)" }, svg(I.rooms, 20)),
          h("div.txt", {}, h("span.tt", { text: a.name || a.area_id }), h("span.ss", { text: open ? meta : `${n} de ${def.fields.length} campos configurados` })),
          h(
            "button.icon-btn",
            { "aria-expanded": open ? "true" : "false", "aria-label": `${open ? "Fechar" : "Abrir"} ${a.name}`, onClick: toggle },
            svg(I.chevronDown, 22, { sw: 2, style: `transform:rotate(${open ? 180 : 0}deg); transition:transform .2s ease` })
          )
        );
        const raised = this._picker && this._picker.sub === subId && this._picker.idx === a.area_id;
        const card = h("div.card" + (raised ? ".raised" : ""), {}, head);
        if (open) {
          const grid = this._grid(subId, a.area_id, item, def.fields);
          grid.appendChild(
            h("div.note.full", {}, svg(I.info, 18, { style: "flex-shrink:0" }), h("span", { text: `Nome, piso, temperatura e humidade vêm da área "${a.name}" no Home Assistant.` }))
          );
          card.appendChild(grid);
        }
        group.appendChild(card);
      }
      return out;
    }

    _target(subId, idx) {
      const d = this._draft[subId];
      return idx === -1 ? d : d[idx];
    }

    _field(def, subId, idx, item, opts = {}) {
      const v = item[def.k];
      const wrap = h("div.field");
      const label = h("label", {}, def.label);
      if (def.req) label.appendChild(h("span.req", { text: " *" }));
      if (def.opt) label.appendChild(h("span.optional", { text: " (opcional)" }));
      wrap.appendChild(label);
      let help = def.help || "";
      let helpWarn = false;
      const set = (val, structural) => {
        this._target(subId, idx)[def.k] = val;
        this._touch(structural);
      };

      if (def.t === "text" || def.t === "number") {
        const input = h("input", {
          value: str(v),
          placeholder: def.ph || (def.t === "number" ? "10" : ""),
          inputMode: def.t === "number" ? "numeric" : "text",
          "aria-label": def.label,
          onInput: (e) => {
            const val = def.t === "number" ? e.target.value.replace(/[^0-9]/g, "") : e.target.value;
            if (val !== e.target.value) e.target.value = val;
            set(val, false);
          },
        });
        wrap.appendChild(h("div.textbox", {}, input, def.suffix ? h("span.suffix", { text: def.suffix }) : null));
        if (def.k === "name" && subId === "carros" && !str(v).trim()) help = "Sem nome, o cartão usa o nome da entidade da bateria.";
      } else if (def.t === "entity") {
        const open = !!(this._picker && this._picker.sub === subId && this._picker.idx === idx && this._picker.k === def.k);
        const flag = def.req && !str(v).trim() && opts.flagMissing;
        const area = v ? this._entityArea(v) : "";
        const btn = h(
          "button.pick-btn" + (open ? ".open" : "") + (flag ? ".missing" : ""),
          {
            "aria-haspopup": "listbox",
            "aria-expanded": open ? "true" : "false",
            "aria-label": `${def.label}: ${v ? this._entityName(v) : "Escolher entidade"}`,
            onClick: () => {
              this._picker = open ? null : { sub: subId, idx, k: def.k };
              this._pq = "";
              this._render();
            },
          },
          svg(v ? this._entityIcon(v) : I.plus, 22, { style: `flex-shrink:0; color:${v ? "var(--fd-sec)" : "var(--fd-faint)"}` }),
          h("span.txt", {}, h("span.nm" + (v ? "" : ".empty"), { text: v ? this._entityName(v) : "Escolher entidade" }), v ? h("span.meta", { text: v + (area ? ` · ${area}` : "") }) : null),
          v && !def.req
            ? h(
                "span.clear",
                {
                  role: "button",
                  "aria-label": `Limpar ${def.label}`,
                  onClick: (e) => {
                    e.stopPropagation();
                    set("", true);
                  },
                },
                svg(I.close, 18, { sw: 2 })
              )
            : null,
          svg(I.chevronDown, 22, { sw: 2, style: "flex-shrink:0; margin-right:4px; color:var(--fd-sec)" })
        );
        const picker = h("div.picker", { "data-picker": "" }, btn);
        if (open) picker.appendChild(this._renderMenu(def, subId, idx, v));
        wrap.appendChild(picker);
        if (flag) {
          help = `Obrigatório. Sem ${opts.reqLabel}, este item é descartado ao guardar.`;
          helpWarn = true;
        }
      } else if (def.t === "color") {
        const holiday = subId === "outros" && isHoliday(item.entityId + " " + this._entityName(item.entityId));
        const row = h("div.swatches", { role: "radiogroup", "aria-label": def.label });
        const current = colorIndex(v, subId === "pessoas" && typeof idx === "number" ? idx % COLORS.length : 3);
        const choices = holiday ? [{ key: null, hex: HOLIDAY_RED, name: "Vermelho" }] : COLORS;
        choices.forEach((c, i) => {
          const on = holiday || i === current;
          row.appendChild(
            h(
              "button.swatch",
              {
                role: "radio",
                "aria-checked": on ? "true" : "false",
                "aria-label": c.name,
                title: c.name,
                style: `background:${c.hex}; box-shadow:${on ? `0 0 0 3px var(--fd-card), 0 0 0 5px ${c.hex}` : "none"}`,
                onClick: () => {
                  if (!holiday) set(c.key, true);
                },
              },
              svg(I.check, 18, { sw: 3, stroke: on ? "#FFFFFF" : "transparent" })
            )
          );
        });
        if (holiday) {
          row.appendChild(h("span", { style: "font-size:13px; color:var(--fd-sec); line-height:1.4", text: "Reconhecido como feriados: fica sempre a vermelho." }));
          help = "";
        }
        wrap.appendChild(row);
      } else if (def.t === "icon") {
        const row = h("div.icons", { role: "radiogroup", "aria-label": def.label });
        for (const a of APPLIANCES) {
          const on = v === a.key;
          row.appendChild(
            h("button.icon-opt" + (on ? ".on" : ""), { role: "radio", "aria-checked": on ? "true" : "false", "aria-label": a.name, title: a.name, onClick: () => set(a.key, true) }, svg(a.icon, 24))
          );
        }
        wrap.appendChild(row);
        if (v === "boiler") {
          const hs = (this._settings && this._settings.house_screen) || {};
          const own = hs.waterHeaterEntityId || hs.waterHeaterTempEntityId || hs.waterHeaterPowerEntityId;
          help = own ? "O cartão Água quente usa as entidades de Casa › Alarme e água quente." : "Também alimenta o cartão Água quente, que não tem entidades próprias.";
        }
      }
      if (help) wrap.appendChild(h("span.help" + (helpWarn ? ".warn" : ""), { text: help }));
      return wrap;
    }

    _renderMenu(def, subId, idx, value) {
      const menu = h("div.menu", { role: "listbox", "aria-label": `Escolher ${def.label}` });
      const optsBox = h("div.opts");
      const foot = h("div.foot");
      const LIMIT = 80;
      const fill = () => {
        const all = this._entityOptions(def.dom, this._pq);
        optsBox.innerHTML = "";
        for (const o of all.slice(0, LIMIT)) {
          const on = o.id === value;
          optsBox.appendChild(
            h(
              "button.opt" + (on ? ".on" : ""),
              {
                role: "option",
                "aria-selected": on ? "true" : "false",
                onClick: () => {
                  this._target(subId, idx)[def.k] = o.id;
                  this._picker = null;
                  this._touch(true);
                },
              },
              svg(this._entityIcon(o.id), 22, { style: "flex-shrink:0; color:var(--fd-sec)" }),
              h("span.txt", {}, h("span.nm", { text: o.name }), h("span.id", { text: o.id })),
              o.area ? h("span.area", { text: o.area }) : null,
              svg(I.check, 20, { sw: 2.4, stroke: on ? "var(--fd-primary-text)" : "transparent", style: "flex-shrink:0" })
            )
          );
        }
        if (!all.length) optsBox.appendChild(h("div.none", { text: "Nenhuma entidade encontrada." }));
        const scope = def.dom ? "Só entidades do tipo " + def.dom.map((d) => DOMAIN_PT[d] || d).join(" ou ") : "Qualquer entidade";
        foot.textContent = `${scope} · ${all.length} ${all.length === 1 ? "resultado" : "resultados"}${all.length > LIMIT ? " · pesquise para ver mais" : ""}`;
      };
      const search = h("input", {
        value: this._pq,
        placeholder: "Pesquisar entidades",
        "aria-label": "Pesquisar entidades",
        "data-search": "",
        onInput: (e) => {
          this._pq = e.target.value;
          fill();
        },
      });
      menu.append(h("div.search", {}, svg(I.search, 20, { sw: 2, style: "color:var(--fd-sec)" }), search), optsBox, foot);
      fill();
      return menu;
    }

    _renderBar(entering) {
      const dirty = this._dirtySubs();
      const m = this._msg;
      let icon = null;
      let strong = "";
      let text = "";
      let color = "var(--fd-sec)";
      let spin = false;
      if (m && m.kind === "saving") {
        spin = true;
        strong = "A guardar…";
        color = "var(--fd-text)";
      } else if (m && m.kind === "err") {
        icon = I.alert;
        strong = "Erro ao guardar.";
        text = m.text;
        color = "var(--fd-error)";
      } else if (m && m.kind === "ok" && !dirty.length) {
        icon = I.check;
        strong = "Guardado.";
        text = m.text;
        color = "var(--fd-ok)";
      } else if (dirty.length) {
        icon = I.dot;
        strong = "Alterações por guardar";
        text = (this._section.subs.length > 1 ? "em " + joinPt(dirty.map((s) => SUBS[s].title)) : "") + ".";
        color = "var(--fd-warn-text)";
      } else {
        text = "Sem alterações por guardar.";
      }
      const canSave = dirty.length > 0 && !this._saving;
      return h(
        "div.bar-wrap" + (entering ? ".enter" : ""),
        { role: "region", "aria-label": "Guardar alterações" },
        h(
          "div.bar",
          {},
          h(
            "div.msg",
            { "aria-live": "polite", style: `color:${color}` },
            spin ? h("span.spin") : null,
            icon ? svg(icon, 20, { sw: 2, style: "flex-shrink:0" }) : null,
            h("span", {}, strong ? h("strong", { text: strong }) : null, text ? (strong && !text.startsWith(".") ? " " : "") + text : null)
          ),
          h(
            "div.acts",
            {},
            canSave ? h("button.btn-text", { onClick: () => this._discard() }, "Descartar") : null,
            h("button.btn-fill", { "aria-disabled": canSave ? "false" : "true", onClick: () => canSave && this._save() }, m && m.kind === "err" ? "Tentar de novo" : "Guardar")
          )
        )
      );
    }

    _renderLeave() {
      const names = joinPt(this._dirtySubs().map((s) => SUBS[s].title)) || "esta secção";
      return h(
        "div.scrim",
        {},
        h(
          "div.dialog",
          { role: "alertdialog", "aria-modal": "true", "aria-label": "Sair sem guardar?" },
          h("h2", { text: "Sair sem guardar?" }),
          h("p.lead", { text: `Há alterações por guardar em ${names}. Se sair agora, perdem-se.` }),
          h(
            "div.acts",
            {},
            h(
              "button.btn-text",
              {
                onClick: () => {
                  this._leave = false;
                  this._render();
                },
              },
              "Ficar"
            ),
            h("button.btn-text.danger", { onClick: () => this._goHome() }, "Sair sem guardar"),
            h(
              "button.btn-fill",
              {
                onClick: () => {
                  this._leave = false;
                  this._save(() => this._goHome());
                },
              },
              "Guardar e sair"
            )
          )
        )
      );
    }
  }

  if (!customElements.get("flutter-dashboard-panel")) {
    customElements.define("flutter-dashboard-panel", FlutterDashboardPanel);
  }
})();
