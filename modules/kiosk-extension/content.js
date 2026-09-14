let allowContextMenu = false;

async function refreshContextMenuFlag() {
  try {
    const res = await fetch("http://127.0.0.1:4173/api/status", {
      cache: "no-store",
    });
    if (!res.ok) return;
    const data = await res.json();
    allowContextMenu = !!(data.flags && data.flags["context-menu"]);
  } catch {
    // Keep last known value if the demo API is briefly unavailable.
  }
}

refreshContextMenuFlag();
setInterval(refreshContextMenuFlag, 1000);

document.addEventListener(
  "contextmenu",
  function (e) {
    if (allowContextMenu) return;
    e.preventDefault();
    e.stopPropagation();
    return false;
  },
  true
);
