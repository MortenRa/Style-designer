// Page 1 of the preview PDF, drawn with pdf.js at the screen's resolution.
// A click steps through: whole page -> full width -> larger -> whole page.
var preview = { page: null, zoom: 0, tooltip: '' };
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

function ShowMessage(message) {
    preview.page = null;
    var p = document.createElement('div');
    p.className = 'pp-msg';
    p.textContent = message;
    replaceContent(p);
}

function draw() {
    var page = preview.page;
    if (!page) return;
    var root = document.getElementById('controlAddIn');
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
        box.addEventListener('click', function () {
            preview.zoom = (preview.zoom + 1) % ZOOMS.length;
            draw();
        });
        replaceContent(box);
    });
}

function replaceContent(node) {
    var root = document.getElementById('controlAddIn');
    root.innerHTML = '';
    root.appendChild(node);
}

window.addEventListener('resize', function () {
    clearTimeout(preview.resizeTimer);
    preview.resizeTimer = setTimeout(draw, 200);
});
