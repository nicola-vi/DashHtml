/* Injected by Tools\Test-DhContrast.ps1 into a COPY of an exported report. Measures WCAG contrast of the
   selectors in light and dark mode and writes the result as JSON into <pre id="dh-contrast">. */
(function () {
  var SELECTORS = /*%%SELECTORS%%*/[];
  function parse(c) { var m = /rgba?\(([^)]+)\)/.exec(c || ''); if (!m) return null; var p = m[1].split(/[ ,\/]+/).map(Number); return { r: p[0], g: p[1], b: p[2], a: p.length > 3 ? p[3] : 1 }; }
  function lum(c) { var f = function (v) { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }; return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b); }
  function ratio(a, b) { var x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); }
  function over(top, bot) { var a = top.a; return { r: top.r * a + bot.r * (1 - a), g: top.g * a + bot.g * (1 - a), b: top.b * a + bot.b * (1 - a), a: 1 }; }
  var skipped = 0;
  /* effective background: composite the translucent layers up to the first opaque one; null when an image/gradient is in the way */
  function bgOf(el) {
    var layers = [];
    for (var e = el; e && e.nodeType === 1; e = e.parentElement) {
      var cs = getComputedStyle(e);
      if (cs.backgroundImage && cs.backgroundImage !== 'none') return null;
      var c = parse(cs.backgroundColor);
      if (c && c.a > 0) { layers.push(c); if (c.a >= 1) break; }
    }
    var base = parse(getComputedStyle(document.body).backgroundColor); if (!base || base.a < 1) base = { r: 255, g: 255, b: 255, a: 1 };
    for (var i = layers.length - 1; i >= 0; i--) base = over(layers[i], base);
    return base;
  }
  function measure(mode, out) {
    var checked = 0;
    SELECTORS.forEach(function (sel) {
      var seen = {};
      document.querySelectorAll(sel).forEach(function (el) {
        var cs = getComputedStyle(el);
        if (cs.display === 'none' || cs.visibility === 'hidden') return;
        var isSvg = el instanceof SVGElement, txt = (el.textContent || '').trim();
        if (!txt) return;
        var fg = parse(isSvg && cs.fill && cs.fill !== 'none' ? cs.fill : cs.color); if (!fg) return;
        var bg = bgOf(el);
        if (isSvg) {
          var rect = el.parentElement && el.parentElement.querySelector('rect'), fc = rect && parse(getComputedStyle(rect).fill);
          var outer = bgOf(el.closest('svg')); if (fc && fc.a > 0 && outer) bg = over(fc, outer);
        }
        if (!bg) { skipped++; return; }
        fg = over(fg, bg);
        var px = parseFloat(cs.fontSize) || 16, bold = parseInt(cs.fontWeight, 10) >= 700;
        var large = px >= 24 || (px >= 18.66 && bold);
        var key = sel + '|' + txt.slice(0, 12);
        if (seen[key]) return; seen[key] = 1;
        checked++;
        out.push({ mode: mode, selector: sel, ratio: Math.round(ratio(fg, bg) * 100) / 100, large: large, text: txt.slice(0, 24) });
      });
    });
    return checked;
  }
  function run() {
    var st = document.createElement('style'); st.textContent = '*,*::before,*::after{transition:none!important;animation:none!important}'; document.head.appendChild(st);
    var rows = [], checked = measure('light', []), all = [];
    measure('light', all);
    var btn = document.getElementById('btn-theme-toggle');
    if (btn) { btn.click(); setTimeout(function () { measure('dark', all); finish(all); }, 300); } else { finish(all); }
  }
  function finish(all) {
    var pre = document.createElement('pre'); pre.id = 'dh-contrast';
    pre.textContent = JSON.stringify({ rows: all, skipped: skipped, dark: !!document.getElementById('btn-theme-toggle') });
    document.body.appendChild(pre);
    /* headless dump-dom prints nothing in current Edge: hand the result to the tool's local listener instead */
    try { fetch('http://127.0.0.1:' + /*%%PORT%%*/0 + '/result', { method: 'POST', mode: 'no-cors', body: pre.textContent }); } catch (e) {}
  }
  if (document.readyState === 'complete') setTimeout(run, 400); else window.addEventListener('load', function () { setTimeout(run, 400); });
})();