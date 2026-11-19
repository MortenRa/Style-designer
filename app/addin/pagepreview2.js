// Page 1 of the preview PDF, drawn with pdf.js at the screen's resolution.
// A click steps through: whole page -> full width -> larger -> whole page.
var preview = { page: null, zoom: 0, tooltip: '', opensFull: false, suggestion: null, note: '' };
var ZOOMS = ['page', 'width', 'large'];

function ShowPdf(pdfBase64, tooltip) {
    var pdfjsLib = globalThis.pdfjsLib;
    if (!pdfjsLib) {
        ShowMessage('The PDF viewer could not be loaded (no internet access to cdn-bc.dynamics.com?).');
        return;
    }
    pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdn-bc.dynamics.com/common/js/pdfjs-4.10.38/pdf.worker.min.mjs';
    var raw = atob(pdfBase64);
    var bytes = new Uint8Array(raw.length);
    for (var i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
    preview.tooltip = tooltip;
    pdfjsLib.getDocument({ data: bytes }).promise
        .then(function (pdf) { return pdf.getPage(1); })
        .then(function (page) { preview.page = page; draw(); })
        .catch(function (e) { ShowMessage(String(e && e.message || e)); });
}

// On Quick Start a click opens the page full size in its own window instead of zooming in the small box.
function SetOpenOnClick(open) {
    preview.opensFull = !!open;
    draw();
}

function ShowMessage(message) {
    preview.page = null;
    var p = document.createElement('div');
    p.className = 'pp-msg';
    p.textContent = message;
    replaceContent(p);
}

function SetNote(note) {
    preview.note = note || '';
    body();
    renderNote();
}
function renderNote() {
    var el = document.getElementById('pp-note');
    if (!el) return;
    el.hidden = !preview.note;
    el.textContent = preview.note || '';
}

// The server cannot update the page while it renders, so the busy text is shown first and the render is asked for after.
function ShowBusy(message, requestRender) {
    var b = body();
    var old = b.querySelector('.pp-busy');
    if (old) old.remove();
    var busy = document.createElement('div');
    busy.className = 'pp-busy' + (b.querySelector('canvas') ? ' over' : '');
    busy.setAttribute('role', 'status');
    busy.innerHTML = '<span class="pp-spin" aria-hidden="true"></span><span></span>';
    busy.lastChild.textContent = message;
    if (!b.querySelector('canvas')) b.innerHTML = '';
    b.appendChild(busy);
    if (requestRender) requestAnimationFrame(function () {
        requestAnimationFrame(function () { Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('RenderRequested', []); });
    });
}

function draw() {
    var page = preview.page;
    if (!page) return;
    var root = body();
    var mode = ZOOMS[preview.zoom];
    var base = page.getViewport({ scale: 1 });
    var boxW = root.clientWidth - 8, boxH = root.clientHeight - 8;
    var scale = mode === 'page' ? Math.min(boxW / base.width, boxH / base.height)
        : mode === 'width' ? boxW / base.width
        : 1.5;
    var viewport = page.getViewport({ scale: scale });
    var ratio = window.devicePixelRatio || 1;
    var canvas = document.createElement('canvas');
    canvas.width = Math.floor(viewport.width * ratio);
    canvas.height = Math.floor(viewport.height * ratio);
    canvas.style.width = Math.floor(viewport.width) + 'px';
    canvas.style.height = Math.floor(viewport.height) + 'px';
    page.render({
        canvasContext: canvas.getContext('2d'),
        viewport: viewport,
        transform: ratio !== 1 ? [ratio, 0, 0, ratio, 0, 0] : null
    }).promise.then(function () {
        var box = document.createElement('div');
        box.className = 'pp ' + mode;
        box.title = preview.tooltip;
        box.appendChild(canvas);
        if (preview.opensFull) box.classList.add('opens');
        box.addEventListener('click', function () {
            if (preview.opensFull) {
                Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('FullViewRequested', []);
                return;
            }
            preview.zoom = (preview.zoom + 1) % ZOOMS.length;
            draw();
        });
        replaceContent(box);
    });
}

// The page sits under an optional bar with the Copilot suggestion in the preview and arrows to the others.
function body() {
    var root = document.getElementById('controlAddIn');
    var b = document.getElementById('pp-body');
    if (!b) {
        root.innerHTML = '<div id="pp-bar" class="pp-bar" hidden></div><div id="pp-note" class="pp-note" hidden></div><div id="pp-body" class="pp-body"></div>';
        b = document.getElementById('pp-body');
        renderBar();
        renderNote();
    }
    return b;
}

function replaceContent(node) {
    var b = body();
    b.innerHTML = '';
    b.appendChild(node);
}

// Count 0 hides the bar. Index 0: none of the suggestions is in the preview yet.
function SetSuggestion(name, index, count, reason) {
    preview.suggestion = count > 0 ? { name: name, index: index, count: count, reason: reason } : null;
    body();
    renderBar();
    draw();
}

function renderBar() {
    var bar = document.getElementById('pp-bar');
    if (!bar) return;
    var s = preview.suggestion;
    bar.hidden = !s;
    if (!s) { bar.innerHTML = ''; return; }
    var label = s.index > 0 ? s.name : 'Copilot suggestions';
    var place = s.index > 0 ? s.index + ' of ' + s.count : s.count + ' from your last run';
    bar.innerHTML = '';
    bar.appendChild(stepButton(-1, 'Previous suggestion', '\u2039'));
    var text = document.createElement('div');
    text.className = 'pp-sug';
    text.title = s.reason || '';
    text.innerHTML = '<span class="pp-spark">\u2726</span><b></b><span class="pp-place"></span><small></small>';
    text.querySelector('b').textContent = label;
    text.querySelector('.pp-place').textContent = place;
    text.querySelector('small').textContent = s.index > 0 ? (s.reason || '') : 'Use the arrows to see them on your document.';
    bar.appendChild(text);
    if (s.index > 0) {
        var leave = document.createElement('button');
        leave.type = 'button';
        leave.className = 'pp-leave';
        leave.textContent = 'Use my theme';
        leave.title = 'Leave the Copilot suggestion and show your theme as it is';
        leave.addEventListener('click', function () { Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('UseMyThemeRequested', []); });
        bar.appendChild(leave);
    }
    bar.appendChild(stepButton(1, 'Next suggestion', '\u203a'));
}

function stepButton(delta, label, glyph) {
    var b = document.createElement('button');
    b.type = 'button';
    b.className = 'pp-step';
    b.textContent = glyph;
    b.title = label;
    b.setAttribute('aria-label', label);
    b.addEventListener('click', function () {
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('SuggestionStep', [delta]);
    });
    return b;
}

window.addEventListener('resize', function () {
    clearTimeout(preview.resizeTimer);
    preview.resizeTimer = setTimeout(draw, 200);
});
