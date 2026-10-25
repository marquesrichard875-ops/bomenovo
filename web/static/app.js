// Atualiza a lista de tarefas periodicamente, buscando os dados novamente na API
// (via rota /tasks/fragment do Flask). Assim, mudanças feitas no app Flutter
// aparecem aqui sem precisar recarregar a página.
(function () {
  const container = document.getElementById("tasks-container");
  const lastUpdate = document.getElementById("last-update");
  const dot = document.getElementById("sync-dot");
  const refreshBtn = document.getElementById("refresh-now");
  if (!container) return;

  async function refresh() {
    try {
      const res = await fetch(window.TASKS_FRAGMENT_URL, {
        headers: { "X-Requested-With": "fetch" },
        credentials: "same-origin",
      });
      if (res.status === 401) { window.location = window.LOGIN_URL; return; }
      if (!res.ok) throw new Error("HTTP " + res.status);
      container.innerHTML = await res.text();
      lastUpdate.textContent = new Date().toLocaleTimeString("pt-BR");
      dot.classList.remove("off");
    } catch (e) {
      dot.classList.add("off"); // API fora do ar: mantém a lista atual e tenta de novo depois
    }
  }

  // Confirmação antes de excluir (delegação de evento: funciona após cada atualização)
  container.addEventListener("submit", function (ev) {
    const msg = ev.target.dataset.confirm;
    if (msg && !confirm(msg)) ev.preventDefault();
  });

  refreshBtn.addEventListener("click", refresh);
  setInterval(function () { if (!document.hidden) refresh(); }, window.REFRESH_MS);
})();
