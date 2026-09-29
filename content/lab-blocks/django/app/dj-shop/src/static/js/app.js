document.querySelectorAll("[data-confirm]").forEach((el) => {
  el.addEventListener("click", (event) => {
    if (!window.confirm(el.dataset.confirm)) event.preventDefault();
  });
});
