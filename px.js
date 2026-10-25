// Meta pixel for the המוח site · dataset "Theofrina Event Data" in Ofri's portfolio.
// Every event goes twice — from the browser and from our server (api/event.js, Conversions API) —
// with one shared event_id, so Meta counts it once. The visitor's first UTMs are kept, so a sale
// made days later still knows where she came from.
(function () {
  var PIXEL_ID = "1039595395638788";
  !function(f,b,e,v,n,t,s){if(f.fbq)return;n=f.fbq=function(){n.callMethod?n.callMethod.apply(n,arguments):n.queue.push(arguments)};
  if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';n.queue=[];t=b.createElement(e);t.async=!0;
  t.src=v;s=b.getElementsByTagName(e)[0];s.parentNode.insertBefore(t,s)}(window,document,'script','https://connect.facebook.net/en_US/fbevents.js');
  fbq("init", PIXEL_ID);

  var KEYS = ["utm_source", "utm_medium", "utm_campaign", "utm_content", "utm_term", "fbclid"];
  var q = new URLSearchParams(location.search), src = {};
  try { src = JSON.parse(localStorage.getItem("hm_src") || "{}"); } catch (e) {}
  if (KEYS.some(function (k) { return q.get(k); })) {
    src = { at: Date.now() };
    KEYS.forEach(function (k) { if (q.get(k)) src[k] = q.get(k); });
    try { localStorage.setItem("hm_src", JSON.stringify(src)); } catch (e) {}
  }

  function cookie(n) { var m = document.cookie.match("(?:^|; )" + n + "=([^;]*)"); return m ? m[1] : undefined; }

  // opx("InitiateCheckout") · opx("Purchase", { value: 555, currency: "ILS" }, "stripe-session-id")
  window.opx = function (name, data, id) {
    data = data || {};
    id = id || name + "-" + Date.now() + "-" + Math.random().toString(36).slice(2, 8);
    fbq("track", name, data, { eventID: id });
    var body = { event_name: name, event_id: id, url: location.href, custom_data: data,
      fbp: cookie("_fbp"), fbc: cookie("_fbc") || (src.fbclid ? "fb.1." + (src.at || Date.now()) + "." + src.fbclid : undefined) };
    KEYS.forEach(function (k) { if (src[k] && k !== "fbclid") body[k] = src[k]; });
    var s = JSON.stringify(body);
    if (!(navigator.sendBeacon && navigator.sendBeacon("/api/event", new Blob([s], { type: "application/json" }))))
      fetch("/api/event", { method: "POST", headers: { "Content-Type": "application/json" }, body: s, keepalive: true });
  };
  opx("PageView");
})();
