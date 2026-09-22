(function () {
  var toggle = document.querySelector(".nav-toggle");
  var nav = document.querySelector(".nav");
  var year = document.getElementById("year");
  var badge = document.getElementById("open-badge");

  if (year) {
    year.textContent = String(new Date().getFullYear());
  }

  if (toggle && nav) {
    toggle.addEventListener("click", function () {
      var open = nav.classList.toggle("is-open");
      toggle.setAttribute("aria-expanded", open ? "true" : "false");
    });

    nav.querySelectorAll("a").forEach(function (link) {
      link.addEventListener("click", function () {
        nav.classList.remove("is-open");
        toggle.setAttribute("aria-expanded", "false");
      });
    });
  }

  if (!badge || typeof Intl === "undefined") {
    return;
  }

  var now = new Date();
  var parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Europe/Warsaw",
    weekday: "short",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23"
  }).formatToParts(now);

  var weekday = "";
  var hour = 0;
  var minute = 0;
  parts.forEach(function (part) {
    if (part.type === "weekday") weekday = part.value;
    if (part.type === "hour") hour = Number(part.value);
    if (part.type === "minute") minute = Number(part.value);
  });

  var minutes = hour * 60 + minute;
  var weekdayOpen = ["Mon", "Tue", "Wed", "Thu", "Fri"].indexOf(weekday) !== -1;
  var open = weekdayOpen && minutes >= 8 * 60 && minutes < 15 * 60 + 30;

  badge.dataset.open = open ? "true" : "false";
  badge.textContent = open ? "Otwarte teraz · do 15:30" : "Pon.–pt. 8:00–15:30";
})();
