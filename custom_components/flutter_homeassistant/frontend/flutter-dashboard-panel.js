// Settings editor panel for the Flutter Home Assistant App integration.
//
// Talks to the `flutter_homeassistant/get_settings` and
// `flutter_homeassistant/set_settings` websocket commands (see
// custom_components/flutter_homeassistant/__init__.py). No build step, no
// external dependencies — reuses Home Assistant's own already-loaded
// custom elements (ha-card, ha-entity-picker, ha-icon, ha-button), which are
// globally registered by HA's frontend before any panel loads. Plain text/
// number fields use native <input> instead of ha-textfield - deliberately,
// so they can never silently fail to render (see the note on
// nativeInputField below).
//
// Only what maps the kiosk onto this house's entities lives here; the
// screen's own settings (brightness, restart) are on the screen itself, and
// meals, tasks and list icons are edited from the screen.

(() => {
  "use strict";

  const DOMAIN = "flutter_homeassistant";

  // The kiosk's person/calendar palette (KPersonColor). The stored keys
  // predate it — "accent" is purple and "amber" is orange there.
  const PERSON_COLORS = [
    { value: "blue", label: "Azul", swatch: "#1864AB" },
    { value: "amber", label: "Laranja", swatch: "#C2410C" },
    { value: "green", label: "Verde", swatch: "#2B8A3E" },
    { value: "accent", label: "Roxo", swatch: "#5F3DC4" },
    { value: "red", label: "Vermelho", swatch: "#B42318" },
  ];

  const SENSOR_ICONS = [
    { value: "plug", label: "Genérico", icon: "mdi:power-plug" },
    { value: "washer", label: "Máquina de lavar", icon: "mdi:washing-machine" },
    { value: "fridge", label: "Frigorífico", icon: "mdi:fridge" },
    { value: "tv", label: "TV", icon: "mdi:television" },
    { value: "ac", label: "Ar condicionado", icon: "mdi:air-conditioner" },
    { value: "boiler", label: "Bomba de calor (AQS)", icon: "mdi:water-boiler" },
  ];

  function field(key, type, label, opts = {}) {
    return { key, type, label, ...opts };
  }

  const DOMAINS = {
    // The kiosk's household: who tasks are for, and whose calendar a new
    // event goes to (see family_data.dart). Empty falls back to HA's own
    // person entities plus a shared "Família".
    family_members: {
      shape: "list",
      requiredField: "name",
      itemLabel: (item) => item.name || "(sem nome)",
      fields: [
        field("name", "text", "Nome", { hint: "João" }),
        field("color", "color-select", "Cor", { desc: "A cor desta pessoa nas tarefas e nos eventos do calendário." }),
        field("calendarEntityId", "entity", "Calendário (opcional)", {
          hint: "calendar.joao",
          domains: ["calendar"],
          desc: "Os eventos deste calendário aparecem com o nome e a cor desta pessoa; os novos eventos \"para\" ela são criados aqui.",
        }),
      ],
    },
    // Calendars that aren't anyone's: holidays, a shared house calendar…
    calendar_entities: {
      shape: "list",
      requiredField: "entityId",
      itemLabel: (item) => item.entityId || "(sem calendário)",
      fields: [
        field("entityId", "entity", "Calendário", { hint: "calendar.feriados", domains: ["calendar"] }),
        field("color", "color-select", "Cor", { desc: "Um calendário de feriados é reconhecido pelo nome e fica sempre a vermelho." }),
      ],
    },
    temperature_entities: {
      shape: "singleton",
      fields: [
        field("exteriorTempEntityId", "entity", "Temperatura exterior", { hint: "sensor.temperatura_exterior", desc: "O número grande da temperatura no cabeçalho." }),
        field("weatherStateEntityId", "entity", "Meteorologia", { hint: "weather.casa", domains: ["weather"], desc: "Estado do tempo, máximas/mínimas e a previsão dos próximos dias no cabeçalho." }),
      ],
    },
    // Area-backed (see renderAreaListDomain): one row per HA area, not a
    // user-created list. Name, floor, and temperature/humidity all come
    // straight from the area itself (HA's own Areas & Zones settings) —
    // only these fields are this app's own mapping, mirroring
    // RoomConfig in lib/src/providers/rooms_store.dart.
    rooms: {
      shape: "area-list",
      fields: [
        field("lightEntityId", "entity", "Luz", { hint: "light.quarto ou switch.quarto", desc: "O botão de luz no cartão da divisão; conta para \"Apagar todas as luzes\"." }),
        field("climateEntityId", "entity", "Ar condicionado", {
          hint: "climate.quarto",
          domains: ["climate"],
          desc: "O ar condicionado desta divisão nos controlos de Clima (Início, Casa e janela do ar condicionado).",
        }),
        field("windowEntityId", "entity", "Janela", { hint: "binary_sensor.quarto_janela", domains: ["binary_sensor"], desc: "\"Janela aberta\" no cartão da divisão." }),
        field("coverEntityId", "entity", "Estores", {
          hint: "cover.quarto_estores",
          domains: ["cover"],
          desc: "A posição dos estores no cartão da divisão.",
        }),
        field("secondaryEntityId", "entity", "Linha extra (opcional)", { hint: "sensor.quarto_co2 ou lock.quarto", desc: "Mais uma linha de estado no cartão; uma fechadura aparece como trancada/aberta." }),
      ],
    },
    // Casa page (see house_config.dart). Lists left empty fall back to
    // every scene.* / every lock.* plus garage/gate covers.
    house_screen: {
      shape: "singleton",
      sectionTitle: "Alarme e água quente",
      fields: [
        field("alarmEntityId", "entity", "Alarme", { hint: "alarm_control_panel.casa", domains: ["alarm_control_panel"] }),
        field("waterHeaterEntityId", "entity", "Água quente (bomba de calor)", {
          hint: "climate.bomba_de_calor_aqs",
          domains: ["climate", "water_heater"],
          desc: "Dá a temperatura alvo e se está a aquecer.",
        }),
        field("waterHeaterTempEntityId", "entity", "Temperatura da água (opcional)", { hint: "sensor.aqs_temperatura", domains: ["sensor"] }),
        field("waterHeaterPowerEntityId", "entity", "Potência da bomba de calor (opcional)", { hint: "sensor.aqs_potencia", domains: ["sensor"] }),
      ],
    },
    house_scenes: {
      shape: "list",
      sectionTitle: "Cenários",
      intro: "Vazio mostra todas as cenas do Home Assistant.",
      requiredField: "entityId",
      itemLabel: (item) => item.name || item.entityId || "(sem cenário)",
      fields: [
        field("name", "text", "Nome", { hint: "Bom dia" }),
        field("entityId", "entity", "Cena ou script", { hint: "scene.bom_dia", domains: ["scene", "script"] }),
      ],
    },
    house_locks: {
      shape: "list",
      sectionTitle: "Fechaduras e portões",
      intro: "A secção Segurança. Vazio mostra todas as fechaduras e os portões/garagens.",
      requiredField: "entityId",
      itemLabel: (item) => item.name || item.entityId || "(sem entidade)",
      fields: [
        field("name", "text", "Nome", { hint: "Porta da frente" }),
        field("entityId", "entity", "Fechadura ou portão", { hint: "lock.porta_entrada", domains: ["lock", "cover"] }),
      ],
    },
    house_cameras: {
      shape: "list",
      sectionTitle: "Câmaras",
      requiredField: "entityId",
      itemLabel: (item) => item.name || item.entityId || "(sem câmara)",
      fields: [
        field("name", "text", "Nome", { hint: "Garagem" }),
        field("entityId", "entity", "Câmara", { hint: "camera.garagem", domains: ["camera"] }),
      ],
    },
    energy_entities: {
      shape: "singleton",
      sectionTitle: "Fluxo de energia",
      fields: [
        field("solarPowerEntityId", "entity", "Potência solar", { hint: "sensor.solar_power", domains: ["sensor"], desc: "Produção solar instantânea (sempre ≥ 0)." }),
        field("gridPowerEntityId", "entity", "Potência da rede", { hint: "sensor.grid_power", domains: ["sensor"], desc: "Positivo = a importar da rede; negativo = a exportar." }),
        field("batteryPowerEntityId", "entity", "Potência da bateria", { hint: "sensor.battery_power", domains: ["sensor"], desc: "Positivo = a descarregar; negativo = a carregar." }),
        field("batterySocEntityId", "entity", "Carga da bateria", { hint: "sensor.battery_soc", domains: ["sensor"], desc: "Percentagem, 0-100%." }),
        field("homePowerEntityId", "entity", "Consumo da casa", { hint: "sensor.home_power", domains: ["sensor"], desc: "Consumo total da casa (sempre ≥ 0)." }),
        field("solarZeroThresholdW", "number", "Ignorar solar abaixo de (W)", { hint: "10" }),
        field("gridZeroThresholdW", "number", "Ignorar rede abaixo de (W)", { hint: "10" }),
        field("batteryZeroThresholdW", "number", "Ignorar bateria abaixo de (W)", { hint: "10" }),
        field("homeZeroThresholdW", "number", "Ignorar casa abaixo de (W)", { hint: "10", desc: "Valores mais pequenos do que estes contam como zero, para o fluxo não piscar com ruído dos sensores." }),
      ],
    },
    individual_sensors: {
      shape: "list",
      sectionTitle: "Consumos",
      intro: "Até 4 aparelhos na coluna de consumos do cartão Energia (página Casa). Um com o ícone de bomba de calor também alimenta o cartão Água quente se este não tiver entidades próprias.",
      requiredField: "name",
      maxItems: 4,
      itemLabel: (item) => item.name || "(sem nome)",
      fields: [
        field("name", "text", "Nome", { hint: "Máquina de lavar" }),
        field("icon", "icon-select", "Ícone"),
        field("powerEntityId", "entity", "Potência", { hint: "sensor.maquina_lavar_potencia", domains: ["sensor"] }),
        field("temperatureEntityId", "entity", "Temperatura (opcional)", { hint: "sensor.aqs_temperatura", domains: ["sensor"] }),
      ],
    },
    ev_cars: {
      shape: "singleton",
      fixedSlots: ["left", "right"],
      slotLabels: { left: "Primeiro carro", right: "Segundo carro" },
      fields: [
        field("name", "text", "Nome", { hint: "Renault 5" }),
        field("batterySocEntityId", "entity", "Bateria", { hint: "sensor.carro_bateria", domains: ["sensor"], desc: "Carga da bateria, 0-100%." }),
        field("rangeEntityId", "entity", "Autonomia", { hint: "sensor.carro_autonomia", domains: ["sensor"], desc: "Autonomia restante, em km." }),
        field("chargingEntityId", "entity", "A carregar", { hint: "binary_sensor.carro_a_carregar", desc: 'Estado "on"/"charging" enquanto carrega.' }),
        field("plugConnectedEntityId", "entity", "Ficha ligada", { hint: "binary_sensor.carro_ficha", desc: 'Estado "on"/"connected" com a ficha ligada, mesmo sem carregar ("à espera de carga").' }),
        field("chargeLimitEntityId", "entity", "Limite de carga", { hint: "number.carro_limite_carga", desc: "A marca na barra da bateria." }),
        field("chargePowerEntityId", "entity", "Potência de carga", { hint: "sensor.carro_potencia_carga", domains: ["sensor"], desc: "Em W ou kW." }),
      ],
    },
  };

  // Ordered as the screen's pages are.
  const MENU = [
    { title: "Família", icon: "mdi:account-group", desc: "Pessoas, cores e calendários pessoais", keys: ["family_members"] },
    { title: "Outros calendários", icon: "mdi:calendar", desc: "Feriados e calendários partilhados", keys: ["calendar_entities"] },
    { title: "Meteorologia", icon: "mdi:weather-partly-cloudy", desc: "Temperatura e previsão no cabeçalho", keys: ["temperature_entities"] },
    { title: "Divisões", icon: "mdi:floor-plan", desc: "Luz, clima, janela e estores de cada área", keys: ["rooms"] },
    { title: "Casa", icon: "mdi:home-automation", desc: "Alarme, água quente, cenários, fechaduras e câmaras", keys: ["house_screen", "house_scenes", "house_locks", "house_cameras"] },
    { title: "Energia", icon: "mdi:lightning-bolt", desc: "Solar, rede, bateria e consumos", keys: ["energy_entities", "individual_sensors"] },
    { title: "Carros elétricos", icon: "mdi:car-electric", desc: "Bateria, autonomia e carregamento", keys: ["ev_cars"] },
  ];

  async function wsGet(hass, key) {
    const res = await hass.connection.sendMessagePromise({ type: `${DOMAIN}/get_settings`, key });
    return res.value;
  }

  async function wsSet(hass, key, value) {
    await hass.connection.sendMessagePromise({ type: `${DOMAIN}/set_settings`, key, value });
  }

  function deepClone(obj) {
    return obj ? JSON.parse(JSON.stringify(obj)) : obj;
  }

  function normalizeValue(type, value) {
    if (type === "number") {
      if (value === "" || value === null || value === undefined) return null;
      const n = Number(value);
      return Number.isNaN(n) ? null : n;
    }
    if (typeof value === "string") {
      const trimmed = value.trim();
      return trimmed === "" ? null : trimmed;
    }
    return value === undefined ? null : value;
  }

  function normalizeItem(item, fields) {
    const out = {};
    fields.forEach((f) => {
      out[f.key] = normalizeValue(f.type, item[f.key]);
    });
    return out;
  }

  function mkIconButton(icon, title, onClick) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "icon-btn";
    if (title) btn.title = title;
    const ic = document.createElement("ha-icon");
    ic.icon = icon;
    btn.appendChild(ic);
    btn.addEventListener("click", onClick);
    return btn;
  }

  // Native <input> instead of ha-textfield: guarantees a visible, working
  // text box regardless of exact HA frontend version/element registration
  // (unlike ha-textfield, a plain <input> can't silently fail to render).
  function nativeInputField(fieldDef, value, onChange, inputType) {
    const wrap = document.createElement("div");
    wrap.className = "text-field";
    const label = document.createElement("div");
    label.className = "text-field-label";
    label.textContent = fieldDef.label;
    const input = document.createElement("input");
    input.type = inputType;
    if (fieldDef.hint) input.placeholder = fieldDef.hint;
    input.value = value === null || value === undefined ? "" : String(value);
    input.addEventListener("input", () => onChange(input.value));
    wrap.append(label, input);
    return wrap;
  }

  function buildFieldInput(hass, fieldDef, value, onChange) {
    switch (fieldDef.type) {
      case "text":
        return nativeInputField(fieldDef, value, onChange, "text");
      case "number":
        return nativeInputField(fieldDef, value, onChange, "number");
      case "entity": {
        const el = document.createElement("ha-entity-picker");
        el.hass = hass;
        el.label = fieldDef.label;
        el.allowCustomEntity = true;
        if (fieldDef.domains) el.includeDomains = fieldDef.domains;
        el.value = value ?? "";
        el.style.display = "block";
        el.addEventListener("value-changed", (e) => {
          e.stopPropagation();
          onChange(e.detail.value ?? "");
        });
        return el;
      }
      case "icon-select":
      case "color-select": {
        const opts = fieldDef.type === "icon-select" ? SENSOR_ICONS : PERSON_COLORS;
        const wrap = document.createElement("div");
        wrap.className = "swatch-row";
        let current = value;
        const paint = () => {
          wrap.innerHTML = "";
          opts.forEach((opt) => {
            const btn = document.createElement("button");
            btn.type = "button";
            btn.className = "swatch-btn" + (current === opt.value ? " selected" : "");
            btn.title = opt.label;
            if (fieldDef.type === "icon-select") {
              const ic = document.createElement("ha-icon");
              ic.icon = opt.icon;
              btn.appendChild(ic);
            } else {
              btn.classList.add("color-btn");
              btn.style.background = opt.swatch;
            }
            btn.addEventListener("click", () => {
              current = opt.value;
              onChange(current);
              paint();
            });
            wrap.appendChild(btn);
          });
        };
        paint();
        return wrap;
      }
      default:
        return document.createElement("div");
    }
  }

  function renderFieldRow(container, hass, fieldDef, value, onChange) {
    const row = document.createElement("div");
    row.className = "field-row";
    row.appendChild(buildFieldInput(hass, fieldDef, value, onChange));
    if (fieldDef.desc) {
      const desc = document.createElement("div");
      desc.className = "field-desc";
      desc.textContent = fieldDef.desc;
      row.appendChild(desc);
    }
    container.appendChild(row);
  }

  async function renderListDomain(root, hass, key, domainDef) {
    const loaded = (await wsGet(hass, key)) || [];
    let items = deepClone(loaded);

    const wrap = document.createElement("div");
    wrap.className = "domain-section";
    const cardsWrap = document.createElement("div");
    wrap.appendChild(cardsWrap);

    function paintCards() {
      cardsWrap.innerHTML = "";
      items.forEach((item, index) => {
        const card = document.createElement("ha-card");
        card.className = "item-card";

        const header = document.createElement("div");
        header.className = "item-header";
        const title = document.createElement("span");
        title.textContent = domainDef.itemLabel(item);
        header.appendChild(title);

        const controls = document.createElement("div");
        controls.className = "item-controls";
        if (index > 0) {
          controls.appendChild(
            mkIconButton("mdi:arrow-up", "Mover para cima", () => {
              [items[index - 1], items[index]] = [items[index], items[index - 1]];
              paintCards();
            })
          );
        }
        if (index < items.length - 1) {
          controls.appendChild(
            mkIconButton("mdi:arrow-down", "Mover para baixo", () => {
              [items[index + 1], items[index]] = [items[index], items[index + 1]];
              paintCards();
            })
          );
        }
        controls.appendChild(
          mkIconButton("mdi:delete", "Remover", () => {
            items.splice(index, 1);
            paintCards();
            updateAddState();
          })
        );
        header.appendChild(controls);
        card.appendChild(header);

        const body = document.createElement("div");
        body.className = "item-body";
        domainDef.fields.forEach((f) => {
          renderFieldRow(body, hass, f, item[f.key], (v) => {
            item[f.key] = v;
            if (f.key === domainDef.requiredField) title.textContent = domainDef.itemLabel(item);
          });
        });
        card.appendChild(body);
        cardsWrap.appendChild(card);
      });
    }

    const addBtn = document.createElement("ha-button");
    function updateAddState() {
      const atMax = !!domainDef.maxItems && items.length >= domainDef.maxItems;
      addBtn.disabled = atMax;
      addBtn.textContent = atMax ? `Máximo de ${domainDef.maxItems} atingido` : "Adicionar";
    }
    addBtn.addEventListener("click", () => {
      items.push({});
      paintCards();
      updateAddState();
    });

    paintCards();
    updateAddState();
    wrap.appendChild(addBtn);

    const saveRow = document.createElement("div");
    saveRow.className = "save-row";
    const saveBtn = document.createElement("ha-button");
    saveBtn.setAttribute("raised", "");
    saveBtn.textContent = "Guardar";
    const msg = document.createElement("span");
    msg.className = "save-msg";
    saveBtn.addEventListener("click", async () => {
      const required = domainDef.requiredField;
      const valid = items.filter((it) => !required || (it[required] || "").toString().trim());
      const dropped = items.length - valid.length;
      const cleaned = valid.map((it) => normalizeItem(it, domainDef.fields));
      saveBtn.disabled = true;
      try {
        await wsSet(hass, key, cleaned);
        items = deepClone(cleaned);
        paintCards();
        updateAddState();
        msg.textContent =
          dropped > 0
            ? `Guardado. ${dropped} sem "${required}" ${dropped === 1 ? "não foi guardado" : "não foram guardados"}.`
            : "Guardado.";
      } catch (err) {
        msg.textContent = `Erro ao guardar: ${err.message || err}`;
      } finally {
        saveBtn.disabled = false;
        setTimeout(() => {
          msg.textContent = "";
        }, 5000);
      }
    });
    saveRow.append(saveBtn, msg);
    wrap.appendChild(saveRow);

    root.appendChild(wrap);
  }

  // Rooms mirror HA's own areas — one row per area (see DOMAINS.rooms'
  // own doc), not a user-created list, so there's no add/remove/reorder
  // here at all: just per-area field editing and a save. Name/floor come
  // straight from `config/area_registry/list`/`config/floor_registry/list`
  // (a core old enough to have no floor registry command just gets every
  // area grouped under "Sem piso" via the empty `.catch`).
  async function renderAreaListDomain(root, hass, key, domainDef) {
    const [areas, floors, saved] = await Promise.all([
      hass.callWS({ type: "config/area_registry/list" }),
      hass.callWS({ type: "config/floor_registry/list" }).catch(() => []),
      wsGet(hass, key),
    ]);

    const floorById = {};
    floors.forEach((f) => (floorById[f.floor_id] = f));

    // A saved entry from before this app pointed rooms at real areas
    // (identified by a free-typed `name`, no `areaId`) is matched onto
    // whichever current area has the same name — same migration the Dart
    // app's own RoomsStore.read does — so a room configured before this
    // change isn't silently dropped.
    const savedByAreaId = {};
    const savedByLowerName = {};
    (Array.isArray(saved) ? saved : []).forEach((it) => {
      if (it.areaId) savedByAreaId[it.areaId] = it;
      else if (it.name) savedByLowerName[String(it.name).trim().toLowerCase()] = it;
    });

    const sortedAreas = [...areas].sort((a, b) => {
      const levelOf = (area) => {
        const floor = floorById[area.floor_id];
        return floor && typeof floor.level === "number" ? floor.level : Number.MAX_SAFE_INTEGER;
      };
      const byLevel = levelOf(a) - levelOf(b);
      return byLevel !== 0 ? byLevel : (a.name || "").localeCompare(b.name || "");
    });

    const items = sortedAreas.map((area) => {
      const existing = savedByAreaId[area.area_id] || savedByLowerName[(area.name || "").trim().toLowerCase()] || {};
      const item = { areaId: area.area_id, _area: area, _floor: floorById[area.floor_id] || null, _expanded: false };
      domainDef.fields.forEach((f) => {
        item[f.key] = existing[f.key] ?? null;
      });
      return item;
    });

    const wrap = document.createElement("div");
    wrap.className = "domain-section";
    const cardsWrap = document.createElement("div");
    wrap.appendChild(cardsWrap);

    function paintCards() {
      cardsWrap.innerHTML = "";
      if (items.length === 0) {
        const empty = document.createElement("div");
        empty.className = "item-summary";
        empty.textContent = "Nenhuma área encontrada na Home Assistant. Cria áreas em Definições → Áreas e Zonas.";
        cardsWrap.appendChild(empty);
        return;
      }
      items.forEach((item) => {
        const card = document.createElement("ha-card");
        card.className = "item-card";

        const header = document.createElement("div");
        header.className = "item-header";
        const titleWrap = document.createElement("div");
        titleWrap.className = "item-header-text";
        const title = document.createElement("span");
        title.textContent = item._area.name || item.areaId;
        const floorLine = document.createElement("span");
        floorLine.className = "item-floor";
        floorLine.textContent = item._floor ? item._floor.name : "Sem piso";
        titleWrap.append(title, floorLine);
        header.appendChild(titleWrap);

        const controls = document.createElement("div");
        controls.className = "item-controls";
        controls.appendChild(
          mkIconButton(item._expanded ? "mdi:chevron-up" : "mdi:chevron-down", item._expanded ? "Colapsar" : "Expandir", () => {
            item._expanded = !item._expanded;
            paintCards();
          })
        );
        header.appendChild(controls);
        card.appendChild(header);

        if (!item._expanded) {
          const filledCount = domainDef.fields.filter((f) => item[f.key]).length;
          const summary = document.createElement("div");
          summary.className = "item-summary";
          summary.textContent = filledCount === 0 ? "Nenhum campo configurado" : `${filledCount} de ${domainDef.fields.length} campos configurados`;
          card.appendChild(summary);
        } else {
          const body = document.createElement("div");
          body.className = "item-body";
          domainDef.fields.forEach((f) => {
            renderFieldRow(body, hass, f, item[f.key], (v) => {
              item[f.key] = v;
            });
          });
          card.appendChild(body);
        }
        cardsWrap.appendChild(card);
      });
    }

    paintCards();

    const saveRow = document.createElement("div");
    saveRow.className = "save-row";
    const saveBtn = document.createElement("ha-button");
    saveBtn.setAttribute("raised", "");
    saveBtn.textContent = "Guardar";
    const msg = document.createElement("span");
    msg.className = "save-msg";
    saveBtn.addEventListener("click", async () => {
      // An area with nothing configured isn't saved as a divisão at all —
      // an HA instance with dozens of areas shouldn't turn into dozens of
      // empty Divisões cards just because every one of them is listed here.
      const configured = items.filter((it) => domainDef.fields.some((f) => it[f.key]));
      const cleaned = configured.map((it) => {
        const out = { areaId: it.areaId };
        domainDef.fields.forEach((f) => {
          out[f.key] = normalizeValue(f.type, it[f.key]);
        });
        return out;
      });
      saveBtn.disabled = true;
      try {
        await wsSet(hass, key, cleaned);
        msg.textContent = "Guardado.";
      } catch (err) {
        msg.textContent = `Erro ao guardar: ${err.message || err}`;
      } finally {
        saveBtn.disabled = false;
        setTimeout(() => {
          msg.textContent = "";
        }, 5000);
      }
    });
    saveRow.append(saveBtn, msg);
    wrap.appendChild(saveRow);

    root.appendChild(wrap);
  }

  async function renderSingletonDomain(root, hass, key, domainDef) {
    const loaded = (await wsGet(hass, key)) || {};
    const data = deepClone(loaded);

    if (domainDef.fixedSlots) {
      domainDef.fixedSlots.forEach((slot) => {
        if (!data[slot]) data[slot] = {};
      });
    }

    const wrap = document.createElement("div");
    wrap.className = "domain-section";

    function renderFields(container, target) {
      domainDef.fields.forEach((f) => {
        renderFieldRow(container, hass, f, target[f.key], (v) => {
          target[f.key] = v;
        });
      });
    }

    if (domainDef.fixedSlots) {
      domainDef.fixedSlots.forEach((slot) => {
        const card = document.createElement("ha-card");
        card.className = "item-card";
        const header = document.createElement("div");
        header.className = "item-header";
        header.textContent = domainDef.slotLabels[slot];
        card.appendChild(header);
        const body = document.createElement("div");
        body.className = "item-body";
        renderFields(body, data[slot]);
        card.appendChild(body);
        wrap.appendChild(card);
      });
    } else {
      const card = document.createElement("ha-card");
      card.className = "item-card";
      const body = document.createElement("div");
      body.className = "item-body";
      renderFields(body, data);
      card.appendChild(body);
      wrap.appendChild(card);
    }

    const saveRow = document.createElement("div");
    saveRow.className = "save-row";
    const saveBtn = document.createElement("ha-button");
    saveBtn.setAttribute("raised", "");
    saveBtn.textContent = "Guardar";
    const msg = document.createElement("span");
    msg.className = "save-msg";
    saveBtn.addEventListener("click", async () => {
      const cleaned = domainDef.fixedSlots
        ? Object.fromEntries(domainDef.fixedSlots.map((slot) => [slot, normalizeItem(data[slot], domainDef.fields)]))
        : normalizeItem(data, domainDef.fields);
      saveBtn.disabled = true;
      try {
        await wsSet(hass, key, cleaned);
        msg.textContent = "Guardado.";
      } catch (err) {
        msg.textContent = `Erro ao guardar: ${err.message || err}`;
      } finally {
        saveBtn.disabled = false;
        setTimeout(() => {
          msg.textContent = "";
        }, 5000);
      }
    });
    saveRow.append(saveBtn, msg);
    wrap.appendChild(saveRow);

    root.appendChild(wrap);
  }

  const STYLE_TAG = `<style>
    :host { display:block; background: var(--primary-background-color); min-height:100vh; }
    .container { max-width:900px; margin:0 auto; padding:16px 16px 64px; color: var(--primary-text-color); font-family: var(--paper-font-body1_-_font-family, Roboto, sans-serif); }
    .title-bar { display:flex; align-items:center; gap:12px; margin-bottom:16px; }
    .back-btn { background:none; border:none; color: var(--primary-color); font-size:14px; cursor:pointer; padding:8px 0; }
    h1 { font-size:20px; margin:0; }
    h3 { margin:24px 0 8px; color: var(--secondary-text-color); font-size:13px; text-transform:uppercase; letter-spacing:.04em; }
    .menu-grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(160px,1fr)); gap:12px; }
    .menu-tile { padding:24px 12px; display:flex; flex-direction:column; align-items:center; gap:10px; cursor:pointer; text-align:center; }
    .menu-tile ha-icon { --mdc-icon-size:32px; color: var(--primary-color); }
    .menu-desc, .section-intro { font-size:12px; color: var(--secondary-text-color); }
    .section-intro { margin:0 0 12px; }
    .item-card { margin-bottom:12px; padding:12px 16px; display:block; }
    .item-header { display:flex; align-items:center; justify-content:space-between; font-weight:500; margin-bottom:8px; }
    .item-controls { display:flex; gap:4px; }
    .icon-btn { background:none; border:none; cursor:pointer; color: var(--secondary-text-color); padding:4px; display:flex; border-radius:50%; }
    .icon-btn:hover { color: var(--primary-text-color); background: var(--secondary-background-color); }
    .item-body { display:flex; flex-direction:column; gap:12px; }
    .item-summary { font-size:12px; color: var(--secondary-text-color); }
    .field-row ha-entity-picker { width:100%; }
    .field-desc { font-size:12px; color: var(--secondary-text-color); margin-top:2px; }
    .text-field { display:flex; flex-direction:column; gap:4px; }
    .text-field-label { font-size:12px; color: var(--secondary-text-color); }
    .text-field input { padding:8px; border-radius:4px; border:1px solid var(--divider-color); background: var(--card-background-color); color: var(--primary-text-color); font-size:15px; width:100%; box-sizing:border-box; }
    .swatch-row { display:flex; gap:8px; flex-wrap:wrap; }
    .swatch-btn, .color-btn { width:36px; height:36px; border-radius:50%; border:2px solid transparent; cursor:pointer; display:flex; align-items:center; justify-content:center; background: var(--card-background-color); }
    .swatch-btn.selected, .color-btn.selected { border-color: var(--primary-color); }
    .item-header-text { display:flex; flex-direction:column; gap:2px; }
    .item-floor { font-size:12px; color: var(--secondary-text-color); font-weight:400; }
    .save-row { display:flex; align-items:center; gap:12px; margin-top:16px; }
    .save-msg { font-size:13px; color: var(--secondary-text-color); }
    .error { color: var(--error-color); margin-bottom:8px; }
  </style>`;

  class FlutterDashboardPanel extends HTMLElement {
    constructor() {
      super();
      this._hass = null;
      this._activeIndex = null;
      this.attachShadow({ mode: "open" });
    }

    set hass(hass) {
      const first = !this._hass;
      this._hass = hass;
      if (first) this._paint();
    }

    get hass() {
      return this._hass;
    }

    set panel(v) {
      this._panel = v;
    }

    set narrow(v) {
      this._narrow = v;
    }

    connectedCallback() {
      this._paint();
    }

    _paint() {
      if (!this._hass) return;
      const root = this.shadowRoot;
      root.innerHTML = STYLE_TAG;

      const container = document.createElement("div");
      container.className = "container";
      root.appendChild(container);

      const titleBar = document.createElement("div");
      titleBar.className = "title-bar";
      if (this._activeIndex !== null) {
        const back = document.createElement("button");
        back.className = "back-btn";
        back.textContent = "← Voltar";
        back.addEventListener("click", () => {
          this._activeIndex = null;
          this._paint();
        });
        titleBar.appendChild(back);
      }
      const h1 = document.createElement("h1");
      h1.textContent = this._activeIndex === null ? "Flutter Dashboard" : MENU[this._activeIndex].title;
      titleBar.appendChild(h1);
      container.appendChild(titleBar);

      if (this._activeIndex === null) {
        const grid = document.createElement("div");
        grid.className = "menu-grid";
        MENU.forEach((entry, i) => {
          const tile = document.createElement("ha-card");
          tile.className = "menu-tile";
          const ic = document.createElement("ha-icon");
          ic.icon = entry.icon;
          const label = document.createElement("div");
          label.textContent = entry.title;
          const desc = document.createElement("div");
          desc.className = "menu-desc";
          desc.textContent = entry.desc;
          tile.append(ic, label, desc);
          tile.addEventListener("click", () => {
            this._activeIndex = i;
            this._paint();
          });
          grid.appendChild(tile);
        });
        container.appendChild(grid);
      } else {
        const entry = MENU[this._activeIndex];
        const body = document.createElement("div");
        body.className = "section-body";
        body.textContent = "A carregar...";
        container.appendChild(body);
        this._loadSection(entry, body);
      }
    }

    async _loadSection(entry, body) {
      body.innerHTML = "";
      for (const key of entry.keys) {
        const domainDef = DOMAINS[key];
        if (entry.keys.length > 1) {
          const heading = document.createElement("h3");
          heading.textContent = domainDef.sectionTitle || key;
          body.appendChild(heading);
        }
        if (domainDef.intro) {
          const intro = document.createElement("p");
          intro.className = "section-intro";
          intro.textContent = domainDef.intro;
          body.appendChild(intro);
        }
        try {
          if (domainDef.shape === "list") {
            await renderListDomain(body, this._hass, key, domainDef);
          } else if (domainDef.shape === "area-list") {
            await renderAreaListDomain(body, this._hass, key, domainDef);
          } else {
            await renderSingletonDomain(body, this._hass, key, domainDef);
          }
        } catch (err) {
          const errEl = document.createElement("div");
          errEl.className = "error";
          errEl.textContent = `Erro ao carregar "${key}": ${err.message || err}`;
          body.appendChild(errEl);
        }
      }
    }
  }

  if (!customElements.get("flutter-dashboard-panel")) {
    customElements.define("flutter-dashboard-panel", FlutterDashboardPanel);
  }
})();
