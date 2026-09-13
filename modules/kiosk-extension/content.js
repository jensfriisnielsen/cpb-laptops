document.addEventListener(
  "contextmenu",
  function (e) {
    e.preventDefault();
    e.stopPropagation();
    return false;
  },
  true
);
