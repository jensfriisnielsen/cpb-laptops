const ESCAPES = {
  overview: {
    title: "Aktiviteter / Super",
    how: "Tryk på Super (Windows-tast) for at åbne oversigt.",
    blocked: "Super og hot corners er slået fra.",
  },
  "alt-tab": {
    title: "Alt+Tab",
    how: "Hold Alt og tryk Tab for at skifte vindue.",
    blocked: "Vinduesskifteren er slået fra.",
  },
  close: {
    title: "Luk vindue",
    how: "Prøv Alt+F4 eller Ctrl+W. Der er også en knap herunder.",
    blocked: "Luk genstartes automatisk, hvis browseren lukkes.",
  },
  "new-window": {
    title: "Nyt vindue / fane",
    how: "Prøv Ctrl+N, Ctrl+T eller Ctrl+Shift+N.",
    blocked: "Tasterne til nye vinduer/faner er blokeret.",
  },
  devtools: {
    title: "Udviklerværktøj",
    how: "Prøv F12 eller Ctrl+Shift+I.",
    blocked: "Genveje til udviklerværktøj er blokeret.",
  },
  "context-menu": {
    title: "Højreklik",
    how: "Højreklik i boksen herunder.",
    blocked: "Kontekstmenuen er slået fra.",
  },
  "file-dialogs": {
    title: "Fil-dialoger",
    how: "Prøv Ctrl+O, Ctrl+S eller Ctrl+P.",
    blocked: "Åbn/gem/print-genveje er blokeret.",
  },
  tty: {
    title: "TTY (Ctrl+Alt+F-taster)",
    how: "Prøv Ctrl+Alt+F3 (vend tilbage med Ctrl+Alt+F1 eller F2).",
    blocked: "Skift til tekstkonsol er blokeret.",
  },
  "run-command": {
    title: "Kør kommando (Alt+F2)",
    how: "Tryk Alt+F2 og skriv fx gnome-terminal.",
    blocked: "Kør-kommando er slået fra.",
  },
  reboot: {
    title: "Genstart / sluk",
    how: "Prøv at genstarte via menuen eller kommandoen reboot.",
    blocked: "Systemet nægter almindelig genstart/sluk (fysisk tænd/sluk-knap i 4 sek. virker stadig).",
  },
  "usb-automount": {
    title: "USB-nøgle",
    how: "Sæt en USB-nøgle i — åbner Filer sig?",
    blocked: "Automatisk montering af USB-lager er slået fra.",
  },
  a11y: {
    title: "Tilgængelighed",
    how: "Hold Shift nede (klæbetaster), eller åbn skærmtastatur / forstørrelse.",
    blocked: "Tilgængeligheds-popups og genveje er slået fra.",
  },
};

function qsHints() {
  const v = new URLSearchParams(location.search).get("hints");
  if (v === "0") return false;
  if (v === "1") return true;
  return null;
}

async function fetchStatus() {
  const res = await fetch("/api/status");
  if (!res.ok) throw new Error("Kunne ikke hente status");
  return res.json();
}

function setActiveMode(scenario) {
  document.querySelectorAll(".modes button").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.mode === scenario);
  });
}

function render(status) {
  const hints =
    qsHints() !== null ? qsHints() : status.hints !== false && status.hints !== 0;
  const flags = status.flags || {};
  const content = document.getElementById("content");
  const footer = document.getElementById("footer");

  setActiveMode(status.scenario || "random");

  if (!hints) {
    content.innerHTML =
      '<p class="challenge">Find en vej ud</p><p class="lead" style="text-align:center;margin:0">Ingen hints. Brug knapperne ovenfor for at skifte sværhedsgrad.</p>';
    footer.textContent = "";
    return;
  }

  const ids = Object.keys(ESCAPES);
  const isRandom = status.scenario === "random";
  let html = `<h2>${isRandom ? "Tilfældige veje ud" : "Escape-muligheder"}</h2>`;

  for (const id of ids) {
    const allowed = !!flags[id];

    const meta = ESCAPES[id];
    html += `<div class="escape">`;
    html += `<span class="badge ${allowed ? "ok" : "bad"}">${allowed ? "Tilladt" : "Blokeret"}</span>`;
    html += `<div><h3>${meta.title}</h3>`;
    html += `<p>${allowed ? meta.how : meta.blocked}</p>`;

    if (allowed && id === "context-menu") {
      html += `<div class="demo-box" id="ctx-demo">Højreklik her for at teste kontekstmenuen.</div>`;
    }
    if (allowed && id === "close") {
      html += `<div class="demo-box"><button type="button" id="close-demo">Prøv window.close()</button></div>`;
    }
    html += `</div></div>`;
  }

  if (isRandom) {
    const any = ids.some((id) => flags[id]);
    if (!any) {
      html += `<p class="lead">Ingen af de listede escapes er tilladt denne gang. Find en anden vej — eller skift til Let.</p>`;
    }
  }

  html += `<div class="card" style="margin-top:1rem;padding:0.85rem 0 0;border:0;background:transparent">
    <h2>Admin-udvej</h2>
    <p class="lead" style="margin:0">SSH er aldrig slået fra. Fra en anden maskine:
    <code>ssh admin@…</code> og kør <code>sudo koderup-kiosk stop</code>.</p>
  </div>`;

  content.innerHTML = html;

  const closeBtn = document.getElementById("close-demo");
  if (closeBtn) {
    closeBtn.addEventListener("click", () => {
      window.close();
      alert("window.close() blev ignoreret (typisk i kiosk). Prøv Alt+F4 i stedet.");
    });
  }

  footer.textContent =
    "Scenarie: " +
    (status.scenario || "?") +
    " · Skift tilstand med knapperne, eller kør koderup-kiosk status i en terminal.";
}

async function setMode(mode) {
  const content = document.getElementById("content");
  const buttons = document.querySelectorAll(".modes button");
  buttons.forEach((btn) => {
    btn.disabled = true;
  });
  content.innerHTML = "<p>Skifter til " + mode + "…</p>";
  try {
    const res = await fetch("/api/mode", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ scenario: mode }),
    });
    if (!res.ok) {
      const text = await res.text();
      content.innerHTML = `<p class="error">Fejl: ${text || res.status}</p>`;
      return;
    }
    const status = await fetchStatus();
    render(status);
  } catch (err) {
    content.innerHTML = `<p class="error">${err.message}</p>`;
  } finally {
    buttons.forEach((btn) => {
      btn.disabled = false;
    });
  }
}

document.querySelectorAll(".modes button").forEach((btn) => {
  btn.addEventListener("click", () => setMode(btn.dataset.mode));
});

fetchStatus()
  .then(render)
  .catch((err) => {
    document.getElementById("content").innerHTML =
      `<p class="error">${err.message}</p>`;
  });
