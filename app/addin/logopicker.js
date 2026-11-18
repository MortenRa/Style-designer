// The company logo on four small pages (left, centre, right, no logo). A click picks the placement.
// The sketch follows the generated header: title first and the logo under it on the left or right,
// or the logo on its own centred line above the title.
var picker = { logo: '', current: 'right' };
var PLACEMENTS = [['left', 'Left'], ['center', 'Center'], ['right', 'Right'], ['none', 'No logo']];

function ShowLogo(logoBase64, placement) {
    picker.logo = logoBase64;
    picker.current = placement || 'right';
    render();
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
    img.src = 'data:image/png;base64,' + picker.logo;
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
