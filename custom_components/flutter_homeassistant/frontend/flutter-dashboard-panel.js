// Settings editor panel for the Flutter Home Assistant App integration.
//
// Talks to the `flutter_homeassistant/get_settings` and
// `flutter_homeassistant/set_settings` websocket commands (see
// custom_components/flutter_homeassistant/__init__.py). No build step, no
// external dependencies — reuses Home Assistant's own already-loaded
// custom elements (ha-card, ha-entity-picker, ha-icon, ha-button), which are
// globally registered by HA's frontend before any panel loads. Plain text/
// number/password/date fields use native <input> instead of ha-textfield -
// deliberately, so they can never silently fail to render (see the note on
// nativeInputField below).

(() => {
  "use strict";

  const DOMAIN = "flutter_homeassistant";

  const CALENDAR_COLORS = [
    { value: "accent", label: "Roxo", swatch: "#a78bfa" },
    { value: "blue", label: "Azul", swatch: "#60a5fa" },
    { value: "green", label: "Verde", swatch: "#4ade80" },
    { value: "amber", label: "Âmbar", swatch: "#fbbf24" },
    { value: "red", label: "Vermelho", swatch: "#f87171" },
  ];

  const SENSOR_ICONS = [
    { value: "plug", label: "Genérico", icon: "mdi:power-plug" },
    { value: "washer", label: "Máquina de lavar", icon: "mdi:washing-machine" },
    { value: "fridge", label: "Frigorífico", icon: "mdi:fridge" },
    { value: "tv", label: "TV", icon: "mdi:television" },
    { value: "ac", label: "Ar condicionado", icon: "mdi:air-conditioner" },
    { value: "boiler", label: "Termoacumulador (AQS)", icon: "mdi:water-boiler" },
  ];

  const FORECAST_DAY_LABELS = ["Hoje", "Amanhã", "D+3", "D+4", "D+5", "D+6", "D+7"];

  function field(key, type, label, opts = {}) {
    return { key, type, label, ...opts };
  }

  const DOMAINS = {
    rooms: {
      shape: "list",
      requiredField: "name",
      itemLabel: (item) => item.name || "(sem nome)",
      fields: [
        field("name", "text", "Nome", { hint: "Sala" }),
        field("temperatureEntityId", "entity", "Temperatura", { hint: "sensor.quarto_temperature", domains: ["sensor"] }),
        field("secondaryEntityId", "entity", "Sensor secundário (opcional)", { hint: "sensor.quarto_humidity ou lock.quarto" }),
        field("lightEntityId", "entity", "Luz", { hint: "light.quarto ou switch.quarto" }),
        field("windowEntityId", "entity", "Janela", { hint: "binary_sensor.quarto_window", domains: ["binary_sensor"] }),
        field("climateEntityId", "entity", "Ar condicionado", { hint: "climate.quarto ou switch.quarto_ac" }),
        field("speakerEntityId", "entity", "Altifalante", { hint: "media_player.quarto", domains: ["media_player"] }),
        field("coverEntityId", "entity", "Estores", { hint: "cover.quarto_estores", domains: ["cover"] }),
      ],
    },
    temperature_entities: {
      shape: "singleton",
      fields: [
        field("interiorTempEntityId", "entity", "Temperatura interior", { hint: "sensor.temperatura_interior", desc: "Leitura principal mostrada no cartão e no topo da folha." }),
        field("interiorHumidityEntityId", "entity", "Humidade interior", { hint: "sensor.humidade_interior", desc: "Percentagem de humidade relativa." }),
        field("co2EntityId", "entity", "CO₂", { hint: "sensor.co2", desc: "Dióxido de carbono, em ppm." }),
        field("pm25EntityId", "entity", "PM2.5", { hint: "sensor.pm25", desc: "Partículas finas, em µg/m³." }),
        field("vocEntityId", "entity", "VOC", { hint: "sensor.voc", desc: "Compostos orgânicos voláteis, em mg/m³." }),
        field("radonEntityId", "entity", "Radão", { hint: "sensor.radao", desc: "Concentração de radão, em Bq/m³." }),
        field("exteriorTempEntityId", "entity", "Temperatura exterior", { hint: "sensor.temperatura_exterior", desc: "Leitura principal mostrada no cartão e na folha." }),
        field("exteriorHumidityEntityId", "entity", "Humidade exterior", { hint: "sensor.humidade_exterior", desc: "Percentagem de humidade relativa exterior." }),
        field("rainEntityId", "entity", "Chuva hoje", { hint: "sensor.chuva_hoje", desc: "Precipitação acumulada hoje, em mm." }),
        field("windEntityId", "entity", "Vento", { hint: "sensor.vento", desc: "Velocidade do vento, em km/h." }),
        field("gustEntityId", "entity", "Rajada máxima", { hint: "sensor.rajada_maxima", desc: "Rajada máxima, em km/h." }),
        field("pressureEntityId", "entity", "Pressão", { hint: "sensor.pressao", desc: "Pressão atmosférica, em hPa." }),
        field("uvEntityId", "entity", "Índice UV", { hint: "sensor.indice_uv", desc: "Índice de radiação ultravioleta." }),
        field("weatherStateEntityId", "entity", "Estado do tempo", { hint: "weather.estacao", desc: 'Estado do tempo em texto (ex.: "Chuva fraca").' }),
      ],
    },
    calendar_entities: {
      shape: "list",
      requiredField: "entityId",
      itemLabel: (item) => item.entityId || "(sem entidade)",
      fields: [
        field("entityId", "entity", "Calendário", { hint: "calendar.pessoal", domains: ["calendar"] }),
        field("color", "color-select", "Cor"),
      ],
    },
    energy_entities: {
      shape: "singleton",
      sectionTitle: "Entidades de energia",
      fields: [
        field("gridPowerEntityId", "entity", "Potência da rede", { hint: "sensor.grid_power", domains: ["sensor"], desc: "Sinal positivo = a importar da rede; negativo = a exportar." }),
        field("solarPowerEntityId", "entity", "Potência solar", { hint: "sensor.solar_power", domains: ["sensor"], desc: "Produção solar instantânea (sempre ≥ 0)." }),
        field("batteryPowerEntityId", "entity", "Potência da bateria", { hint: "sensor.battery_power", domains: ["sensor"], desc: "Sinal positivo = a descarregar; negativo = a carregar." }),
        field("batterySocEntityId", "entity", "Carga da bateria (SOC)", { hint: "sensor.battery_soc", domains: ["sensor"], desc: "Percentagem de carga da bateria, 0-100%." }),
        field("homePowerEntityId", "entity", "Potência da casa", { hint: "sensor.home_power", domains: ["sensor"], desc: "Consumo total da casa (sempre ≥ 0)." }),
        field("gridZeroThresholdW", "number", "Limiar de zero — Rede (W)"),
        field("solarZeroThresholdW", "number", "Limiar de zero — Solar (W)"),
        field("batteryZeroThresholdW", "number", "Limiar de zero — Bateria (W)"),
        field("homeZeroThresholdW", "number", "Limiar de zero — Casa (W)"),
      ],
    },
    individual_sensors: {
      shape: "list",
      sectionTitle: "Sensores individuais",
      requiredField: "name",
      maxItems: 4,
      itemLabel: (item) => item.name || "(sem nome)",
      fields: [
        field("name", "text", "Nome", { hint: "Máquina de lavar" }),
        field("icon", "icon-select", "Ícone"),
        field("powerEntityId", "entity", "Potência", { hint: "sensor.washing_machine_power", domains: ["sensor"] }),
        field("temperatureEntityId", "entity", "Temperatura (opcional)", { hint: "sensor.water_heater_temperature", domains: ["sensor"] }),
      ],
    },
    ev_cars: {
      shape: "singleton",
      fixedSlots: ["left", "right"],
      slotLabels: { left: "Carro esquerdo", right: "Carro direito" },
      fields: [
        field("name", "text", "Nome"),
        field("photoUrl", "text", "Foto (URL)", { desc: 'URL de uma foto do carro (ex.: um ficheiro em /config/www/ do Home Assistant, servido como http://<ha>/local/..., ou o "entity_picture" de uma entidade camera/image/person).' }),
        field("batterySocEntityId", "entity", "Bateria", { hint: "sensor.car_battery", domains: ["sensor"], desc: "Carga da bateria, 0-100%." }),
        field("rangeEntityId", "entity", "Autonomia", { hint: "sensor.car_range", domains: ["sensor"], desc: "Autonomia restante, na unidade que o sensor reportar." }),
        field("chargingEntityId", "entity", "Estado de carregamento", { hint: "binary_sensor.car_charging", desc: 'Sensor cujo estado seja "on"/"charging" enquanto carrega.' }),
        field("plugConnectedEntityId", "entity", "Ficha ligada", { hint: "binary_sensor.car_plugged_in", desc: 'Sensor cujo estado seja "on"/"connected" quando a ficha está ligada, mesmo sem carregar.' }),
        field("monthEnergyEntityId", "entity", "Energia do mês", { hint: "sensor.car_energy_this_month", domains: ["sensor"], desc: "Energia carregada este mês, em kWh." }),
        field("monthEnergyDeltaEntityId", "entity", "Variação da energia", { hint: "sensor.car_energy_delta_percent", domains: ["sensor"], desc: "Variação face ao mês anterior, em %." }),
        field("monthCostEntityId", "entity", "Custo do mês", { hint: "sensor.car_cost_this_month", domains: ["sensor"], desc: "Custo da carga este mês, em euros." }),
        field("monthCostDeltaEntityId", "entity", "Variação do custo", { hint: "sensor.car_cost_delta_eur", domains: ["sensor"], desc: "Variação face ao mês anterior, em euros." }),
      ],
    },
    energy_page_settings: {
      shape: "singleton",
      fields: [
        field("installedKwp", "number", "Potência instalada (kWp)"),
        field("panelCount", "number", "Número de painéis"),
        field("panelOrientation", "text", "Orientação", { hint: "sul 30°" }),
        field("importPricePerKwh", "number", "Preço da eletricidade importada (€/kWh)"),
        field("exportPricePerKwh", "number", "Preço da eletricidade injetada (€/kWh)"),
        field("inverterStatusEntityId", "entity", "Estado do inversor", { hint: "sensor.inverter_status" }),
        field("inverterTemperatureEntityId", "entity", "Temperatura do inversor", { hint: "sensor.inverter_temperature", domains: ["sensor"] }),
        field("inverterEfficiencyEntityId", "entity", "Eficiência do inversor", { hint: "sensor.inverter_efficiency", domains: ["sensor"] }),
        field("forecastDayEntityIds", "entity-array", "Previsão solar", {
          count: 7,
          dayLabels: FORECAST_DAY_LABELS,
          domains: ["sensor"],
          hint: "sensor.solcast_pv_forecast_forecast_today",
        }),
        field("weatherEntityId", "entity", "Entidade de meteorologia", { hint: "weather.casa", domains: ["weather"], desc: 'Opcional — só usado se a entidade expuser o atributo "forecast".' }),
        field("lastCleaningDate", "date", "Última limpeza"),
        field("nextCleaningDate", "date", "Próxima limpeza"),
      ],
    },
    mqtt: {
      shape: "singleton",
      fields: [
        field("host", "text", "Anfitrião (host)", { hint: "192.168.1.10" }),
        field("port", "number", "Porta", { hint: "1883" }),
        field("username", "text", "Utilizador (opcional)"),
        field("password", "password", "Palavra-passe (opcional)"),
      ],
    },
    music_assistant: {
      shape: "singleton",
      fields: [
        field("baseUrl", "text", "URL do servidor", {
          hint: "http://192.168.1.130:8095",
          desc: "Endereço do add-on/servidor Music Assistant na rede local.",
        }),
        field("accessToken", "password", "Token de acesso", {
          desc: "Token de longa duração, criado em Definições → Perfil no Music Assistant — não é a mesma credencial do Home Assistant.",
        }),
      ],
    },
  };

  const MENU = [
    { title: "Divisões", icon: "mdi:floor-plan", keys: ["rooms"] },
    { title: "Temperatura", icon: "mdi:thermometer", keys: ["temperature_entities"] },
    { title: "Calendário", icon: "mdi:calendar", keys: ["calendar_entities"] },
    { title: "Energia", icon: "mdi:lightning-bolt", keys: ["energy_entities", "individual_sensors"] },
    { title: "Carros elétricos", icon: "mdi:car-electric", keys: ["ev_cars"] },
    { title: "Página de Energia", icon: "mdi:solar-power", keys: ["energy_page_settings"] },
    { title: "MQTT", icon: "mdi:swap-horizontal", keys: ["mqtt"] },
    { title: "Music Assistant", icon: "mdi:speaker-wireless", keys: ["music_assistant"] },
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
      if (f.type === "entity-array") {
        out[f.key] = (item[f.key] || []).map((v) => normalizeValue("entity", v));
        return;
      }
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
      case "password":
        return nativeInputField(fieldDef, value, onChange, "password");
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
      case "date": {
        const wrap = document.createElement("div");
        wrap.className = "date-field";
        const label = document.createElement("div");
        label.className = "date-label";
        label.textContent = fieldDef.label;
        const input = document.createElement("input");
        input.type = "date";
        input.value = value ? String(value).slice(0, 10) : "";
        input.addEventListener("input", () => onChange(input.value || null));
        wrap.append(label, input);
        return wrap;
      }
      case "icon-select":
      case "color-select": {
        const opts = fieldDef.type === "icon-select" ? SENSOR_ICONS : CALENDAR_COLORS;
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
        if (f.type === "entity-array") {
          if (!Array.isArray(target[f.key])) target[f.key] = new Array(f.count).fill(null);
          const arr = target[f.key];
          f.dayLabels.forEach((label, i) => {
            renderFieldRow(
              container,
              hass,
              { type: "entity", label: `${label} (kWh previstos)`, hint: f.hint, domains: f.domains },
              arr[i],
              (v) => {
                arr[i] = v;
              }
            );
          });
          return;
        }
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
    .item-card { margin-bottom:12px; padding:12px 16px; display:block; }
    .item-header { display:flex; align-items:center; justify-content:space-between; font-weight:500; margin-bottom:8px; }
    .item-controls { display:flex; gap:4px; }
    .icon-btn { background:none; border:none; cursor:pointer; color: var(--secondary-text-color); padding:4px; display:flex; border-radius:50%; }
    .icon-btn:hover { color: var(--primary-text-color); background: var(--secondary-background-color); }
    .item-body { display:flex; flex-direction:column; gap:12px; }
    .field-row ha-entity-picker { width:100%; }
    .field-desc { font-size:12px; color: var(--secondary-text-color); margin-top:2px; }
    .date-field, .text-field { display:flex; flex-direction:column; gap:4px; }
    .date-label, .text-field-label { font-size:12px; color: var(--secondary-text-color); }
    .date-field input, .text-field input { padding:8px; border-radius:4px; border:1px solid var(--divider-color); background: var(--card-background-color); color: var(--primary-text-color); font-size:15px; width:100%; box-sizing:border-box; }
    .swatch-row { display:flex; gap:8px; flex-wrap:wrap; }
    .swatch-btn, .color-btn { width:36px; height:36px; border-radius:50%; border:2px solid transparent; cursor:pointer; display:flex; align-items:center; justify-content:center; background: var(--card-background-color); }
    .swatch-btn.selected, .color-btn.selected { border-color: var(--primary-color); }
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
      h1.textContent = this._activeIndex === null ? "Definições da app" : MENU[this._activeIndex].title;
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
          tile.append(ic, label);
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
        try {
          if (domainDef.shape === "list") {
            await renderListDomain(body, this._hass, key, domainDef);
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
