// The company logo on four small pages (left, centre, right, no logo). A click picks the placement.
// The sketch follows the generated header: title first and the logo under it on the left or right,
// or the logo on its own centred line above the title.
var picker = { logo: '', current: 'right' };
var PLACEMENTS = [['left', 'Left'], ['center', 'Center'], ['right', 'Right'], ['none', 'No logo']];

function ShowLogo(logoBase64, placement) {
    var first = picker.logo !== logoBase64;
    picker.logo = logoBase64;
    picker.current = placement || 'right';
    render();
    // The logo's main colours, once per logo, for Draft with Copilot on the page. Only the colours are sent.
    if (first) logoColors(logoBase64).then(function (colors) {
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('LogoColorsComputed', [JSON.stringify(colors)]);
    });
}

function ShowNoLogo(message) {
    var box = el('div', 'lp-empty');
    box.appendChild(text('p', message));
    var button = el('button', 'lp-upload');
    button.type = 'button';
    button.textContent = 'Upload logo';
    button.addEventListener('click', function () {
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('UploadRequested', []);
    });
    box.appendChild(button);
    replaceContent(box);
}

function render() {
    var row = el('div', 'lp-row');
    PLACEMENTS.forEach(function (p) {
        var pick = el('button', 'lp-pick' + (p[0] === picker.current ? ' on' : ''));
        pick.type = 'button';
        pick.title = p[1];
        pick.setAttribute('aria-pressed', p[0] === picker.current ? 'true' : 'false');
        pick.appendChild(sheet(p[0]));
        pick.appendChild(text('span', p[1], 'lp-cap'));
        pick.addEventListener('click', function () {
            if (picker.current === p[0]) return;
            picker.current = p[0];
            render();
            Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('PlacementChosen', [p[0]]);
        });
        row.appendChild(pick);
    });
    replaceContent(row);
}

// One small A4 page: the header as the generator builds it, then grey lines for the body.
function sheet(placement) {
    var page = el('span', 'lp-sheet');
    if (placement === 'center') page.appendChild(logoLine('center'));
    page.appendChild(el('span', 'lp-title'));
    if (placement === 'left' || placement === 'right') page.appendChild(logoLine(placement));
    for (var i = 0; i < 5; i++) page.appendChild(el('span', 'lp-text' + (i === 0 ? ' lp-gap' : '')));
    return page;
}

function logoLine(placement) {
    var line = el('span', 'lp-logo-line lp-' + placement);
    var img = document.createElement('img');
    img.src = 'data:' + imageType(picker.logo) + ';base64,' + picker.logo;
    img.alt = '';
    line.appendChild(img);
    return line;
}

function el(tag, className) {
    var node = document.createElement(tag);
    node.className = className;
    return node;
}

function text(tag, value, className) {
    var node = el(tag, className || '');
    node.textContent = value;
    return node;
}

function replaceContent(node) {
    var root = document.getElementById('controlAddIn');
    root.innerHTML = '';
    root.appendChild(node);
}

// Copied from the designer (studio.js), so this small add-in has no dependency on it.
// The logo's main colours, most used first (up to 5). White, transparent and near-white pixels are ignored.
function logoColors(base64) {
    return new Promise(function (resolve) {
        if (!base64) { resolve([]); return; }
        var img = new Image();
        img.onerror = function () { resolve([]); };
        img.onload = function () {
            try {
                var size = 64, canvas = document.createElement('canvas');
                var scale = Math.min(size / img.width, size / img.height, 1);
                canvas.width = Math.max(1, Math.round(img.width * scale));
                canvas.height = Math.max(1, Math.round(img.height * scale));
                var ctx = canvas.getContext('2d');
                ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
                var px = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
                var buckets = {}, total = 0;
                for (var i = 0; i < px.length; i += 4) {
                    var r = px[i], g = px[i + 1], b = px[i + 2];
                    // skip transparent pixels and white or pale grey background
                    if (px[i + 3] < 128 || (Math.min(r, g, b) > 215 && Math.max(r, g, b) - Math.min(r, g, b) < 20)) continue;
                    var key = (r >> 4) + ',' + (g >> 4) + ',' + (b >> 4);
                    var k = buckets[key] || (buckets[key] = { n: 0, r: 0, g: 0, b: 0 });
                    k.n++; k.r += r; k.g += g; k.b += b; total++;
                }
                var list = Object.keys(buckets).map(function (key) {
                    var k = buckets[key];
                    return { n: k.n, c: [k.r / k.n, k.g / k.n, k.b / k.n] };
                }).sort(function (a, b) { return b.n - a.n; });
                var picked = [];
                list.forEach(function (x) {
                    if (picked.length >= 5 || x.n < total * 0.02) return;
                    var near = picked.some(function (p) {
                        return Math.abs(p.c[0] - x.c[0]) + Math.abs(p.c[1] - x.c[1]) + Math.abs(p.c[2] - x.c[2]) < 90;
                    });
                    if (!near) picked.push(x);
                });
                resolve(picked.map(function (x) {
                    return x.c.map(function (v) { return ('0' + Math.round(v).toString(16)).slice(-2); }).join('').toUpperCase();
                }));
            } catch (e) { resolve([]); }
        };
        img.src = 'data:' + imageType(base64) + ';base64,' + base64;
    });
}

function imageType(base64) {
    if (base64.indexOf('iVBOR') === 0) return 'image/png';
    if (base64.indexOf('/9j/') === 0) return 'image/jpeg';
    if (base64.indexOf('R0lG') === 0) return 'image/gif';
    if (base64.indexOf('Qk') === 0) return 'image/bmp';
    return 'image/png';
}
