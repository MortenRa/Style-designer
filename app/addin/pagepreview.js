// The page fits the box; a click switches to the full width (scrolling) and back.
function ShowImage(pngBase64, tooltip) {
    var box = document.createElement('div');
    box.className = 'pp';
    box.title = tooltip;
    var img = document.createElement('img');
    img.alt = '';
    img.src = 'data:image/png;base64,' + pngBase64;
    box.appendChild(img);
    box.addEventListener('click', function () { box.classList.toggle('wide'); });
    replaceContent(box);
}

function ShowMessage(message) {
    var p = document.createElement('div');
    p.className = 'pp-msg';
    p.textContent = message;
    replaceContent(p);
}

function replaceContent(node) {
    var root = document.getElementById('controlAddIn');
    root.innerHTML = '';
    root.appendChild(node);
}
