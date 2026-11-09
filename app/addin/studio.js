/* Report Style Designer: live preview on the left, styling panel on the right.
   Every change re-renders a preview for the current user only; nothing is applied until a save button is used. */

var studio = {
    root: null,
    data: null,
    state: null,
    seq: 0,            // last preview request sent to AL
    busy: false,
    pending: false,
    debounce: null,
    lastPdf: null,
    expanded: {},                 // section key -> true when open; every section starts collapsed when the designer opens
    foldKeys: []                  // sections on the current tab, for "Collapse all"
};

function StudioInit(root) {
    studio.root = root;
    root.innerHTML =
        '<div class="rss">' +
        '  <section class="rss-preview">' +
        '    <header class="rss-preview-bar">' +
        '      <div class="rss-title">Report Style Designer</div>' +
        '      <div class="rss-view" role="tablist" aria-label="Preview">' +
        '        <button class="on" data-view="single" role="tab" aria-selected="true">This document</button>' +
        '        <button data-view="gallery" role="tab" aria-selected="false">Your documents</button></div>' +
        '      <button class="rss-primary rss-draft" data-draft="1" title="Describe a look and get three Copilot themes">Draft a theme</button>' +
        '      <div class="rss-layout" role="tablist" aria-label="Layout">' +
        '        <button data-layout="left" class="on" role="tab">Preview left</button>' +
        '        <button data-layout="center" role="tab">Preview centre</button>' +
        '        <button data-layout="right" role="tab">Preview right</button></div>' +
        '      <div class="rss-badge" id="rss-badge">Preview only. Nothing changes until you apply.</div>' +
        '    </header>' +
        '    <div class="rss-stage" id="rss-stage">' +
        '      <div class="rss-pages" id="rss-pages"></div>' +
        '      <div class="rss-gallery" id="rss-gallery" hidden></div>' +
        '      <div class="rss-overlay" id="rss-overlay"><div class="rss-spinner"></div><div id="rss-overlay-text">Rendering preview…</div></div>' +
        '      <div class="rss-error" id="rss-error" hidden></div>' +
        '    </div>' +
        '  </section>' +
        '  <aside class="rss-panel" id="rss-panel"><div class="rss-loading">Loading…</div></aside>' +
        '  <div class="rss-toast" id="rss-toast" hidden></div>' +
        '</div>';
    root.querySelector('[data-draft]').addEventListener('click', function () {
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('DraftThemeRequested', []);
    });
    root.querySelectorAll('[data-layout]').forEach(function (b) {
        b.addEventListener('click', function () { setLayout(b.getAttribute('data-layout')); });
    });
    root.querySelectorAll('[data-view]').forEach(function (b) {
        b.addEventListener('click', function () { setView(b.getAttribute('data-view')); });
    });
    document.addEventListener('mousedown', function (e) {
        var combo = byId('rss-combo');
        if (studio.pickerOpen && combo && !combo.contains(e.target)) closePicker();
    });
    window.addEventListener('resize', function () {
        clearTimeout(studio.resizeTimer);
        studio.resizeTimer = setTimeout(function () { if (studio.lastPdf) renderPdf(studio.lastPdf); }, 250);
    });
}

/* ---------- AL -> JS ---------- */

function Init(dataText) {
    var previous = studio.data && studio.data.copilot ? JSON.stringify(studio.data.copilot.suggestions || null) : 'null';
    studio.data = JSON.parse(dataText);
    studio.state = studio.data.state;
    // New Copilot proposals: open their section so the cards are visible straight away.
    var suggestions = studio.data.copilot && studio.data.copilot.suggestions;
    if (suggestions && suggestions.length && JSON.stringify(suggestions) !== previous) studio.expanded['Copilot suggestions'] = true;
    if (!findLayout(studio.state.reportId, studio.state.layoutName) && studio.data.layouts.length > 0) {
        var first = studio.data.layouts[0];
        studio.state.reportId = first.reportId;
        studio.state.layoutName = first.name;
        studio.state.layoutAppId = first.appId;
    }
    var current = findLayout(studio.state.reportId, studio.state.layoutName);
    if (current) rememberLayout(current);
    // The page's Copilot prompt action starts outside the add-in: give it the logo colours once.
    if (!studio.logoSent && studio.data.copilot && studio.data.copilot.enabled) {
        studio.logoSent = true;
        logoColors(studio.data.copilot.logo).then(function (colors) {
            Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('LogoColorsComputed', [JSON.stringify(colors)]);
        });
    }
    renderPanel();
    requestPreview(0);
}

function ShowPreview(seq, base64Pdf) {
    if (seq !== studio.seq) { afterResponse(); return; }   // a newer request is on its way
    hide('rss-error');
    studio.lastPdf = base64Pdf;
    renderPdf(base64Pdf).then(afterResponse, afterResponse);
}

function ShowPreviewError(seq, message) {
    if (seq === studio.seq) {
        var el = byId('rss-error');
        el.textContent = message;
        el.hidden = false;
    }
    afterResponse();
}

function Notify(message, kind) {
    var toast = byId('rss-toast');
    toast.textContent = message;
    toast.className = 'rss-toast ' + (kind || 'info');
    toast.hidden = false;
    clearTimeout(studio.toastTimer);
    studio.toastTimer = setTimeout(function () { toast.hidden = true; }, 5000);
}

function SetHasData(hasData) {
    studio.state.hasData = hasData;
    GalleryDataChanged(studio.state.reportId);
    renderPanel();
    requestPreview(0);
}

/* ---------- preview pipeline ---------- */

function requestPreview(delay) {
    // In the gallery the style goes to every shown document instead of the single preview.
    if (studio.view === 'gallery') { refreshGallery(delay); return; }
    clearTimeout(studio.debounce);
    studio.debounce = setTimeout(sendPreview, delay === undefined ? 450 : delay);
}

function sendPreview() {
    if (studio.busy) { studio.pending = true; return; }
    studio.busy = true;
    studio.pending = false;
    studio.seq += 1;
    show('rss-overlay');
    Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('PreviewRequested', [JSON.stringify(studio.state), studio.seq]);
}

function afterResponse() {
    studio.busy = false;
    if (studio.pending) {
        sendPreview();
    } else {
        hide('rss-overlay');
    }
}

function renderPdf(base64Pdf) {
    var pdfjsLib = globalThis.pdfjsLib;
    if (!pdfjsLib) {
        ShowPreviewError(studio.seq, 'The PDF viewer could not be loaded (no internet access to cdn-bc.dynamics.com?).');
        return Promise.resolve();
    }
    pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdn-bc.dynamics.com/common/js/pdfjs-4.10.38/pdf.worker.min.mjs';
    var raw = atob(base64Pdf);
    var bytes = new Uint8Array(raw.length);
    for (var i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);

    return pdfjsLib.getDocument({ data: bytes }).promise.then(function (pdf) {
        var host = byId('rss-pages');
        var width = Math.max(320, byId('rss-stage').clientWidth - 64);
        var pageCount = Math.min(pdf.numPages, 5);
        var canvases = [];
        var chain = Promise.resolve();
        for (var p = 1; p <= pageCount; p++) {
            (function (pageNo) {
                chain = chain.then(function () {
                    return pdf.getPage(pageNo).then(function (page) {
                        var base = page.getViewport({ scale: 1 });
                        var scale = Math.min(width / base.width, 1.6);
                        var viewport = page.getViewport({ scale: scale });
                        var ratio = window.devicePixelRatio || 1;
                        var canvas = document.createElement('canvas');
                        canvas.className = 'rss-page';
                        canvas.width = Math.floor(viewport.width * ratio);
                        canvas.height = Math.floor(viewport.height * ratio);
                        canvas.style.width = Math.floor(viewport.width) + 'px';
                        canvas.style.height = Math.floor(viewport.height) + 'px';
                        canvases.push(canvas);
                        return page.render({
                            canvasContext: canvas.getContext('2d'),
                            viewport: viewport,
                            transform: ratio !== 1 ? [ratio, 0, 0, ratio, 0, 0] : null
                        }).promise;
                    });
                });
            })(p);
        }
        return chain.then(function () {
            // Swap all pages in at once so the old preview stays visible while the new one renders.
            host.innerHTML = '';
            canvases.forEach(function (c) { host.appendChild(c); });
            if (pdf.numPages > pageCount) {
                var more = document.createElement('div');
                more.className = 'rss-more';
                more.textContent = '+ ' + (pdf.numPages - pageCount) + ' more page(s)';
                host.appendChild(more);
            }
        });
    });
}

/* ---------- panel ---------- */

function renderPanel() {
    var d = studio.data, s = studio.state;
    var layout = findLayout(s.reportId, s.layoutName) || {};
    var html = '';
    studio.foldKeys = [];

    html += section('Document',
        '<div class="rss-combo" id="rss-combo">' +
        '<button class="rss-combo-btn" id="rss-combo-btn" aria-haspopup="listbox" aria-expanded="' + !!studio.pickerOpen + '">' +
        '<span class="rss-combo-text"><b>' + esc(layout.reportName || 'Choose a report') + (layout.reportId ? ' (' + layout.reportId + ')' : '') + '</b>' +
        '<small>' + esc(layout.caption || layout.name || '') + '</small></span>' + CHEVRON + '</button>' +
        (studio.pickerOpen
            ? '<div class="rss-picker"><input class="rss-input" id="rss-find" type="search" autocomplete="off" spellcheck="false" ' +
              'placeholder="Search report name, number or layout" value="' + esc(studio.find || '') + '" aria-controls="rss-picker-list">' +
              '<div class="rss-picker-list" id="rss-picker-list" role="listbox"></div>' +
              '<div class="rss-picker-foot"><span id="rss-picker-count"></span><button class="rss-link" id="rss-browse">Browse all…</button></div></div>'
            : '') +
        '</div>' +
        '<div class="rss-row-actions">' +
        '<button class="rss-link" id="rss-data">' + (s.hasData ? 'Change preview data…' : 'Choose preview data…') + '</button>' +
        (s.hasData ? '<button class="rss-link" id="rss-cleardata">Use defaults</button>' : '') +
        '</div>', 'Only Body layouts can be themed. The preview always shows Body + theme + header/footer together.');

    // 1 · Theme
    var copilot = d.copilot || {};
    // Copilot starts from the page's prompt action ("Draft a theme", top right), like other Business Central pages.
    var themeBody = modeSwitch('theme', s.themeMode, [['keep', 'Keep current'], ['default', 'Use default'], ['custom', 'Customize']]) +
        currentLine('theme', layout);
    if (s.themeMode === 'custom') {
        if (copilot.suggestions && copilot.suggestions.length) {
            var picked = null;
            var cards = copilot.suggestions.map(function (g, i) {
                var on = s.palette === copilot.customPalette && sameColors(g.colors, s.customColors) && g.fonts === s.fonts &&
                    g.tableStyle === s.tableStyle && g.pageColor === s.pageColor;
                if (on) picked = g;
                return '<button class="rss-card' + (on ? ' on' : '') + '" data-suggestion="' + i + '" title="' + esc(g.reason) + '">' +
                    swatchRow(g.colors) + '<div class="rss-card-caption">' + esc(g.name) + '</div></button>';
            }).join('');
            themeBody += sub(SPARKLE + ' Copilot suggestions', '<div class="rss-grid">' + cards + '</div>' +
                '<div class="rss-cmp-start"><button class="rss-link" data-compare="1">Compare them</button></div>' +
                (picked ? '<div class="rss-why">' + esc(picked.reason) + (picked.adjustments ? ' <i>' + esc(picked.adjustments) + '</i>' : '') + '</div>' : ''),
                'AI-generated. Check the preview before you apply. You can still change everything below.',
                sumText(picked ? picked.name : copilot.suggestions.length + ' proposals'));
        }
        var base = d.themes.filter(function (t) { return t.name === s.baseTheme; })[0];
        // A list of the themes in the tenant (like the header/footer designs), so it stays usable with many themes.
        themeBody += sub('Start from',
            '<select class="rss-select" id="rss-basetheme">' + d.themes.map(function (t) {
                return '<option value="' + esc(t.name) + '"' + (t.name === s.baseTheme ? ' selected' : '') + '>' + esc(t.caption || t.name) + '</option>';
            }).join('') + '</select>',
            base && base.summary && base.summary !== base.name && base.summary !== base.caption ? esc(base.summary) : '',
            sumText(base ? (base.caption || base.name) : s.baseTheme));
        var palettes = d.palettes.slice();
        if (hasCustomColors()) palettes.push({ id: copilot.customPalette, caption: 'Custom', colors: s.customColors });
        var currentPalette = palettes.filter(function (p) { return p.id === s.palette; })[0];
        themeBody += sub('Colour palette',
            '<div class="rss-grid">' + palettes.map(function (p) {
                var swatches = p.colors.length === 0
                    ? '<div class="rss-swatches keep">From base theme</div>'
                    : swatchRow(p.colors);
                return '<button class="rss-card' + (p.id === s.palette ? ' on' : '') + '" data-palette="' + p.id + '">' +
                    swatches + '<div class="rss-card-caption">' + esc(shortCaption(p.caption)) + '</div></button>';
            }).join('') + '</div>', '',
            currentPalette ? (currentPalette.colors.length ? miniSwatches(currentPalette.colors) : '') + sumText(shortCaption(currentPalette.caption)) : '');
        themeBody += sub('Fonts',
            '<div class="rss-fonts">' + d.fonts.map(function (f) {
                var sample = f.heading
                    ? '<div class="rss-font-h" style="font-family:\'' + f.heading + '\'">Aa Heading</div>' +
                      '<div class="rss-font-b" style="font-family:\'' + f.body + '\'">Invoice total 1,397.30</div>'
                    : '<div class="rss-font-h">Aa</div><div class="rss-font-b">From base theme</div>';
                return '<button class="rss-font' + (f.id === s.fonts ? ' on' : '') + '" data-fonts="' + f.id + '">' + sample +
                    '<div class="rss-card-caption">' + esc(shortCaption(f.caption)) + '</div></button>';
            }).join('') + '</div>', 'Bold labels in the shipped layouts use the heading font too.',
            sumText(shortCaption(captionOf(d.fonts, s.fonts))));
        var colors = paletteColors(s.palette);
        themeBody += sub('Table style',
            '<div class="rss-grid">' + d.tableStyles.map(function (t) {
                return '<button class="rss-card' + (t.id === s.tableStyle ? ' on' : '') + '" data-table="' + t.id + '">' +
                    tableThumb(t.id, colors) + '<div class="rss-card-caption">' + esc(shortCaption(t.caption)) + '</div></button>';
            }).join('') + '</div>', '', sumText(shortCaption(captionOf(d.tableStyles, s.tableStyle))));
        var keepSize = !s.size;
        themeBody += sub('Text size',
            '<label class="rss-check"><input type="checkbox" id="rss-keepsize"' + (keepSize ? ' checked' : '') + '> Use the theme\'s size</label>' +
            '<div class="rss-slider' + (keepSize ? ' off' : '') + '"><input type="range" id="rss-size" min="7" max="12" step="0.5" value="' + (s.size || 8) + '"' + (keepSize ? ' disabled' : '') + '>' +
            '<span id="rss-size-label">' + (s.size || 8) + ' pt</span></div>', '', sumText(keepSize ? 'Theme size' : s.size + ' pt'));
        // Fixed page colours, plus your own (a Copilot tint or one picked here); own colours are kept light.
        var pageList = d.pageColors.slice();
        if (s.customPage) pageList.push({ id: d.customPageId, caption: 'Your colour', hex: s.customPage });
        var page = pageList.filter(function (c) { return c.id === s.pageColor; })[0];
        themeBody += sub('Page colour',
            '<div class="rss-dots">' + pageList.map(function (c) {
                var style = c.id === 0 ? 'class="rss-dot keep"' : (c.hex ? 'class="rss-dot" style="background:#' + c.hex + '"' : 'class="rss-dot white"');
                return '<button ' + style.replace('class="', 'class="' + (c.id === s.pageColor ? 'on ' : '')) + ' data-page="' + c.id + '" title="' + esc(c.caption) + '"></button>';
            }).join('') +
            '<label class="rss-dot pick" title="Pick your own colour"><input type="color" id="rss-pagepick" value="#' + (s.customPage || 'FBF7F0') + '" aria-label="Pick your own page colour">+</label>' +
            '</div><div class="rss-hint">' + esc(page ? shortCaption(page.caption) : '') + ' · page colours print, so your own colours are kept light</div>', '',
            (page && page.hex ? '<i class="rss-sum-dot" style="background:#' + page.hex + '"></i>' : '') + sumText(shortCaption(page ? page.caption : '')));
        themeBody += sub('Save theme as',
            '<input class="rss-input" id="rss-name" value="' + esc(s.themeName || '') + '" placeholder="Theme name">', '', sumText(s.themeName));
    }
    var themeKeys = studio.foldKeys;
    studio.foldKeys = [];

    // 2 · Header & footer
    var headerBody = modeSwitch('header', s.headerMode, [['keep', 'Keep current'], ['default', 'Use default'], ['custom', 'Choose design'], ['design', 'Design your own']]) +
        currentLine('header', layout);
    if (s.headerMode === 'custom') {
        headerBody += '<select class="rss-select" id="rss-header">' +
            '<option value=""' + (s.headerPart ? '' : ' selected') + ' disabled>Choose a design…</option>' +
            d.headers.map(function (h) {
                return '<option value="' + esc(h.name) + '"' + (h.name === s.headerPart ? ' selected' : '') + '>' + esc(h.caption || h.name) + '</option>';
            }).join('') + '</select>';
    }
    if (s.headerMode === 'design') {
        headerBody += '<div class="rss-hint">Starts from the External Default Detailed design. Fonts and colours follow the theme.</div>';
        headerBody += logoSection();
        headerBody += hfSection('Page number', 'hfPageNumber', [['header', 'In the header'], ['footer', 'In the footer'], ['none', 'None']]);
        headerBody += hfSection('Pages after the first', 'hfLaterPages', [['minimal', 'Minimal header'], ['same', 'Same as first page']]);
        headerBody += hfSection('Footer', 'hfFooter', [['contact', 'Contact details'], ['bank', 'Contact + bank'], ['none', 'None']]);
        var extras = [s.hfShowDate ? 'Date' : '', s.hfAccentLine ? 'Accent line' : ''].filter(Boolean).join(' · ') || 'None';
        headerBody += sub('Extras',
            '<label class="rss-check"><input type="checkbox" id="rss-hfdate"' + (s.hfShowDate ? ' checked' : '') + '> Show the date</label>' +
            '<label class="rss-check"><input type="checkbox" id="rss-hfaccent"' + (s.hfAccentLine ? ' checked' : '') + '> Accent line under the header</label>', '', sumText(extras));
        headerBody += sub('Save header/footer as', '<input class="rss-input" id="rss-hfname" value="' + esc(s.hfName || '') + '" placeholder="Header/footer name">', '', sumText(s.hfName));
    }
    var headerKeys = studio.foldKeys;
    studio.foldKeys = [];

    // 3 · Apply
    // Two tabs (the two configuration modes); the document picker above and the apply bar below apply to both.
    var tab = studio.tab || 'theme';
    // The document picker (pickerHtml) sits above the tabs; the centre layout puts it in the left column.
    var pickerHtml = html;
    html = '<div class="rss-tabs" role="tablist">' +
        tabButton('theme', 'Theme', themeState()) +
        tabButton('header', 'Header & footer', headerState()) + '</div>';
    var tabKeys = tab === 'theme' ? themeKeys : headerKeys;
    studio.foldKeys = tabKeys;
    var allClosed = tabKeys.length > 0 && tabKeys.every(function (k) { return !studio.expanded[k]; });
    var foldAll = tabKeys.length > 1
        ? '<div class="rss-foldall"><button class="rss-link" data-foldall="' + (allClosed ? 'open' : 'close') + '">' + (allClosed ? 'Expand all' : 'Collapse all') + '</button></div>'
        : '';
    html += '<div class="rss-tabpanel" role="tabpanel">' + foldAll + (tab === 'theme' ? themeBody : headerBody) + '</div>';

    var nothing = s.themeMode === 'keep' && s.headerMode === 'keep';
    // The group of the selected document; "Apply to" can cover the whole group.
    var docGroup = groupOfReport(s.reportId);
    s.applyGroup = docGroup ? docGroup.id : '';
    if (s.applyTo === 'group' && !docGroup) s.applyTo = 'layout';
    var applyBar = '<div class="rss-applybar">' +
        '<div class="rss-summary">' + summaryText() + '</div>' +
        '<div class="rss-targets">Apply to ' +
        '<label class="rss-radio"><input type="radio" name="rss-target" value="layout"' + (s.applyTo !== 'company' && s.applyTo !== 'group' ? ' checked' : '') + '> this document</label>' +
        (docGroup ? '<label class="rss-radio" title="Every Body layout of the ' + docGroup.reports.length + ' reports in this group"><input type="radio" name="rss-target" value="group"' + (s.applyTo === 'group' ? ' checked' : '') + '> all ' + esc(docGroup.caption.toLowerCase()) + ' (' + docGroup.reports.length + ')</label>' : '') +
        '<label class="rss-radio"><input type="radio" name="rss-target" value="company"' + (s.applyTo === 'company' ? ' checked' : '') + '> company default</label></div>' +
        '<div class="rss-apply-actions">' +
        (s.themeMode === 'custom' ? '<button class="rss-secondary" data-save="theme" title="Saves the theme as a draft. Nothing changes for any report until you choose Apply.">Save as draft</button>' : '') +
        '<button class="rss-primary" data-save="apply" title="Changes the reports that use this style, so customers receive the new look."' + (nothing ? ' disabled' : '') + '>Apply</button></div>' +
        '</div>';

    var panel = byId('rss-panel');
    var previous = byId('rss-scroll');
    var scrollTop = previous && !studio.tabChanged ? previous.scrollTop : 0;
    studio.tabChanged = false;
    if (studio.layout === 'center') {
        // Options on both sides of the preview: theme on the left, header and footer on the right with Apply.
        panel.innerHTML = '<div class="rss-col rss-col-theme">' +
            '<div class="rss-scroll" id="rss-scroll">' + pickerHtml + suggestionBanner() + themeBody + '</div></div>' +
            '<div class="rss-col rss-col-header"><div class="rss-scroll rss-scroll-h">' + headerBody + '</div>' + applyBar + '</div>';
    } else {
        panel.innerHTML = '<div class="rss-scroll" id="rss-scroll">' + pickerHtml + suggestionBanner() + html + '</div>' + applyBar;
    }
    byId('rss-scroll').scrollTop = scrollTop;
    wirePanel(panel);
}

function tabButton(id, label, state) {
    var on = (studio.tab || 'theme') === id;
    return '<button class="rss-tab' + (on ? ' on' : '') + '" role="tab" aria-selected="' + on + '" data-tab="' + id + '">' + label +
        '<span class="rss-tab-state' + (state.changed ? ' changed' : '') + '">' + state.text + '</span></button>';
}

function themeState() {
    var m = studio.state.themeMode;
    return m === 'custom' ? { text: 'Customized', changed: true } : (m === 'default' ? { text: 'Default', changed: true } : { text: 'Keep current', changed: false });
}

function headerState() {
    var m = studio.state.headerMode;
    if (m === 'design') return { text: 'Designed', changed: true };
    if (m === 'custom') return { text: 'Chosen design', changed: true };
    if (m === 'default') return { text: 'Default', changed: true };
    return { text: 'Keep current', changed: false };
}
function wirePanel(panel) {
    var s = studio.state;
    wirePicker();
    on(panel, '[data-tab]', function (el) { studio.tab = el.getAttribute('data-tab'); studio.tabChanged = true; renderPanel(); });
    on(panel, '[data-fold]', function (el) {
        var key = el.getAttribute('data-fold');
        if (studio.expanded[key]) delete studio.expanded[key]; else studio.expanded[key] = true;
        renderPanel();
    });
    on(panel, '[data-foldall]', function (el) {
        var close = el.getAttribute('data-foldall') === 'close';
        studio.foldKeys.forEach(function (k) { if (close) delete studio.expanded[k]; else studio.expanded[k] = true; });
        renderPanel();
    });
    on(panel, '[data-mode]', function (el) {
        var kind = el.getAttribute('data-mode-kind');
        s[kind + 'Mode'] = el.getAttribute('data-mode');
        renderPanel();
        requestPreview(0);
    });
    panel.querySelectorAll('input[name="rss-target"]').forEach(function (r) {
        r.addEventListener('change', function () { s.applyTo = r.value; renderPanel(); requestPreview(0); });
    });
    on(panel, '[data-hf]', function (el) { s[el.getAttribute('data-hf')] = el.getAttribute('data-val'); renderPanel(); requestPreview(0); });
    var hfDate = byId('rss-hfdate');
    if (hfDate) hfDate.addEventListener('change', function (e) { s.hfShowDate = e.target.checked; requestPreview(0); });
    var hfAccent = byId('rss-hfaccent');
    if (hfAccent) hfAccent.addEventListener('change', function (e) { s.hfAccentLine = e.target.checked; requestPreview(0); });
    var hfName = byId('rss-hfname');
    if (hfName) hfName.addEventListener('input', function (e) { s.hfName = e.target.value; });
    var header = byId('rss-header');
    if (header) header.addEventListener('change', function (e) {
        s.headerPart = e.target.value;
        var h = studio.data.headers.filter(function (x) { return x.name === s.headerPart; })[0];
        s.headerAppId = h ? h.appId : '';
        renderPanel();
        requestPreview(0);
    });
    var baseTheme = byId('rss-basetheme');
    if (baseTheme) baseTheme.addEventListener('change', function (e) { s.baseTheme = e.target.value; renderPanel(); requestPreview(0); });
    on(panel, '[data-palette]', function (el) { s.palette = +el.getAttribute('data-palette'); renderPanel(); requestPreview(); });
    on(panel, '[data-suggestion]', function (el) {
        var g = studio.data.copilot.suggestions[+el.getAttribute('data-suggestion')];
        s.palette = studio.data.copilot.customPalette;
        s.customColors = g.colors.slice();
        s.fonts = g.fonts;
        s.tableStyle = g.tableStyle;
        s.pageColor = g.pageColor;
        if (g.customPage) s.customPage = g.customPage;
        s.themeName = g.name;
        renderPanel();
        requestPreview(0);
    });
    on(panel, '[data-compare]', function () {
        if (!studio.data.copilot || !studio.data.copilot.suggestions || !studio.data.copilot.suggestions.length) return;
        gallery.compare = studio.data.copilot.suggestions.slice();
        gallery.cmp = null;
        if (studio.view === 'gallery') renderGallery(); else setView('gallery');
    });
    on(panel, '[data-fonts]', function (el) { s.fonts = +el.getAttribute('data-fonts'); renderPanel(); requestPreview(); });
    on(panel, '[data-table]', function (el) { s.tableStyle = +el.getAttribute('data-table'); renderPanel(); requestPreview(); });
    on(panel, '[data-page]', function (el) { s.pageColor = +el.getAttribute('data-page'); renderPanel(); requestPreview(); });
    var pagePick = byId('rss-pagepick');
    if (pagePick) pagePick.addEventListener('change', function (e) {
        s.customPage = lightPage(e.target.value.replace('#', '').toUpperCase());
        s.pageColor = studio.data.customPageId;
        renderPanel();
        requestPreview(0);
    });
    on(panel, '[data-save]', function (el) {
        var name = byId('rss-name');
        if (name) s.themeName = name.value;
        var hfn = byId('rss-hfname');
        if (hfn) s.hfName = hfn.value;
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('SaveRequested', [JSON.stringify(s), el.getAttribute('data-save')]);
    });
    var keep = byId('rss-keepsize');
    if (keep) keep.addEventListener('change', function (e) {
        s.size = e.target.checked ? 0 : parseFloat(byId('rss-size').value);
        renderPanel();
        requestPreview();
    });
    var size = byId('rss-size');
    if (size) {
        size.addEventListener('input', function () { byId('rss-size-label').textContent = size.value + ' pt'; });
        size.addEventListener('change', function () { s.size = parseFloat(size.value); requestPreview(); });
    }
    var name = byId('rss-name');
    if (name) name.addEventListener('input', function (e) { s.themeName = e.target.value; });
    byId('rss-data').addEventListener('click', function () {
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('ChooseDataRequested', [JSON.stringify(s)]);
    });
    var clear = byId('rss-cleardata');
    if (clear) clear.addEventListener('click', function () {
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('ClearDataRequested', [JSON.stringify(s)]);
    });
}

function step(no, title, body) {
    return '<div class="rss-step"><div class="rss-step-title"><span class="rss-step-no">' + no + '</span>' + title + '</div>' + body + '</div>';
}

// A panel section that can be collapsed; Summary (HTML) shows the current choice while it is collapsed.
function sub(title, body, hint, summary) {
    var key = title.replace(/<[^>]*>/g, '').trim();
    var closed = !studio.expanded[key];
    studio.foldKeys.push(key);
    return '<div class="rss-sub rss-fold' + (closed ? ' collapsed' : '') + '">' +
        '<button class="rss-fold-head" data-fold="' + esc(key) + '" aria-expanded="' + !closed + '">' +
        '<span class="rss-section-title">' + title + '</span>' +
        '<span class="rss-fold-sum">' + (summary || '') + '</span>' + CHEVRON + '</button>' +
        '<div class="rss-fold-body">' + body + (hint ? '<div class="rss-hint">' + hint + '</div>' : '') + '</div></div>';
}

var CHEVRON = '<svg class="rss-chevron" viewBox="0 0 16 16" aria-hidden="true"><path d="M4 6l4 4 4-4" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>';



function sumText(text) { return esc(text || ''); }

function miniSwatches(colors) {
    return '<span class="rss-sum-sw">' + [6, 7, 8, 9].map(function (i) { return '<i style="background:#' + colors[i] + '"></i>'; }).join('') + '</span>';
}

// The logo choice shows the company logo in each position when it is known; otherwise the plain buttons.
function logoSection() {
    var options = [['left', 'Left'], ['right', 'Right'], ['none', 'None']];
    var logo = studio.data.copilot && studio.data.copilot.logo;
    if (!logo) return hfSection('Logo', 'hfLogo', options);
    var current = studio.state.hfLogo;
    var cells = options.map(function (o) {
        var picture = o[0] === 'none' ? '<span class="rss-logo-none">none</span>' : '<img src="data:image/png;base64,' + logo + '" alt="">';
        return '<button class="rss-logo-pick' + (o[0] === current ? ' on' : '') + '" data-hf="hfLogo" data-val="' + o[0] + '" title="' + o[1] + '">' +
            '<span class="rss-logo-sheet rss-logo-' + o[0] + '">' + picture + '</span><span class="rss-logo-cap">' + o[1] + '</span></button>';
    }).join('');
    return sub('Logo', '<div class="rss-logo-row">' + cells + '</div>', '', sumText(optionLabel(options, current)));
}

function hfSection(title, key, options) {
    return sub(title, hfSwitch(key, options), '', sumText(optionLabel(options, studio.state[key])));
}

function optionLabel(options, value) {
    var hit = options.filter(function (o) { return o[0] === value; })[0];
    return hit ? hit[1] : '';
}

function hfSwitch(key, options) {
    var current = studio.state[key];
    return '<div class="rss-seg small">' + options.map(function (o) {
        return '<button class="' + (o[0] === current ? 'on' : '') + '" data-hf="' + key + '" data-val="' + o[0] + '">' + o[1] + '</button>';
    }).join('') + '</div>';
}

function modeSwitch(kind, current, options) {
    return '<div class="rss-seg">' + options.map(function (o) {
        return '<button class="' + (o[0] === current ? 'on' : '') + '" data-mode="' + o[0] + '" data-mode-kind="' + kind + '">' + o[1] + '</button>';
    }).join('') + '</div>';
}

// What applies today at the chosen target, so "keep" and "default" are concrete.
function currentLine(kind, layout) {
    var s = studio.state, c = studio.data.company || {};
    var current, from;
    if (s.applyTo === 'company') {
        current = kind === 'theme' ? c.theme : c.header;
        from = 'company default';
        if (!current) { current = kind === 'theme' ? c.globalTheme : c.globalHeader; from = 'global default'; }
    } else {
        current = kind === 'theme' ? layout.currentTheme : layout.currentHeader;
        from = kind === 'theme' ? layout.currentThemeFrom : layout.currentHeaderFrom;
    }
    var label = current ? partCaption(current) : 'none';
    return '<div class="rss-current">Currently: <b>' + esc(label) + '</b>' + (current ? ' <span>· from ' + esc(from) + '</span>' : '') + '</div>';
}

function partCaption(name) {
    var all = studio.data.themes.concat(studio.data.headers);
    var hit = all.filter(function (p) { return p.name === name; })[0];
    return hit ? (hit.caption || hit.name) : name;
}

function summaryText() {
    var s = studio.state;
    var what = function (mode, custom) { return mode === 'keep' ? 'unchanged' : (mode === 'default' ? 'back to default' : custom); };
    var themeName = s.themeName ? '"' + s.themeName + '"' : 'your custom theme';
    var headerName = s.headerMode === 'design' ? '"' + (s.hfName || 'your design') + '" (designed)' : (s.headerPart ? '"' + partCaption(s.headerPart) + '"' : 'the chosen design');
    if (s.themeMode === 'keep' && s.headerMode === 'keep') return 'Nothing to apply yet: change the theme or the header/footer.';
    return 'Theme: <b>' + esc(what(s.themeMode, themeName)) + '</b> · Header/footer: <b>' + esc(what(s.headerMode, headerName)) + '</b>';
}
/* ---------- table style thumbnails ---------- */

function paletteColors(paletteId) {
    if (studio.data.copilot && paletteId === studio.data.copilot.customPalette && hasCustomColors()) return studio.state.customColors;
    var p = studio.data.palettes.filter(function (x) { return x.id === paletteId; })[0];
    // Base theme colours are unknown in the browser; show the Default theme's look.
    return (p && p.colors.length) ? p.colors : ['242424', 'FFFFFF', '242424', 'F5F7F8', 'F5F7F8', 'E2E2E2', '00838F', '9A9926', '52A621', 'DD765F', '8E939F', '525C6D'];
}

function tableThumb(styleId, c) {
    var text = '#' + c[0], accent = '#' + c[6], band = '#' + c[4];
    var header = { bg: 'transparent', fg: text, rule: '1px solid ' + text };
    var bandBg = '#' + c[5] + '55', total = '1px solid ' + text, totalBottom = '2px solid ' + text;
    if (styleId === 1) { bandBg = 'transparent'; }
    if (styleId === 2) { bandBg = band; }
    if (styleId === 3) { header = { bg: 'transparent', fg: text, rule: '2px solid ' + accent }; total = '1px solid ' + accent; totalBottom = '2px solid ' + accent; }
    if (styleId === 4) { header = { bg: accent + '66', fg: text, rule: '2px solid ' + accent }; bandBg = band; total = '1px solid ' + accent; totalBottom = '2px solid ' + accent; }
    var rows = '';
    for (var i = 0; i < 3; i++) {
        rows += '<div class="rss-tt-row" style="background:' + (i === 1 ? bandBg : 'transparent') + '"><i style="background:' + text + '"></i><i style="background:' + text + '"></i></div>';
    }
    return '<div class="rss-tt">' +
        '<div class="rss-tt-row head" style="background:' + header.bg + ';border-bottom:' + header.rule + '"><i style="background:' + header.fg + '"></i><i style="background:' + header.fg + '"></i></div>' +
        rows +
        '<div class="rss-tt-row total" style="border-top:' + total + ';border-bottom:' + totalBottom + '"><i style="background:' + text + '"></i><i style="background:' + text + '"></i></div>' +
        '</div>';
}

/* ---------- "Your documents" gallery ---------- */
// The current theme and header/footer on several documents at once, first page each, rendered one after another
// by the same private preview as "This document". Results are cached per document and style.

var GALLERY_MAX = 6;          // own selection
var GALLERY_GROUP_MAX = 12;   // a document group
// Typical customer-facing documents, preferred when the gallery is filled for the first time.
var GALLERY_PREFERRED = [1306, 1305, 1304, 1307, 1308, 1316, 1322, 1320, 1303, 117, 116, 206, 205, 204];
var gallery = { cache: {}, queue: [], jobs: {}, seq: 0, timer: null, poll: null, started: 0, adding: false, find: '', compare: null, cmp: null, expected: {} };
var COMPARE_MAX_DOCS = 4;     // a comparison renders every suggestion on every document, so keep the grid small
var GALLERY_TIMEOUT_MS = 120000;

// Where the preview sits: left (default), centre (options on both sides) or right.
function setLayout(layout) {
    studio.layout = layout;
    var root = studio.root.querySelector('.rss');
    root.classList.remove('layout-left', 'layout-center', 'layout-right');
    root.classList.add('layout-' + layout);
    studio.root.querySelectorAll('[data-layout]').forEach(function (b) { b.classList.toggle('on', b.getAttribute('data-layout') === layout); });
    if (studio.data) renderPanel();
}

function setView(view) {
    if (studio.view === view || !studio.data) return;
    studio.view = view;
    studio.root.querySelectorAll('[data-view]').forEach(function (b) {
        var on = b.getAttribute('data-view') === view;
        b.classList.toggle('on', on);
        b.setAttribute('aria-selected', on);
    });
    var g = byId('rss-gallery');
    g.hidden = view !== 'gallery';
    byId('rss-pages').hidden = view === 'gallery';
    hide('rss-error');
    if (view === 'gallery') { hide('rss-overlay'); refreshGallery(0); }
    else { gallery.queue = []; gallery.jobs = {}; gallery.compare = null; gallery.cmp = null; stopGalleryPoll(); requestPreview(0); }
}

function docKey(l) { return l.reportId + '|' + l.name; }

function groupOfReport(reportId) {
    return (studio.data.groups || []).filter(function (g) { return g.reports.indexOf(reportId) >= 0; })[0];
}

function galleryGroup() {
    var g = null;
    try { g = localStorage.getItem('rss-gallery-group'); } catch (e) { g = null; }
    if (g === 'mine' || (studio.data.groups || []).some(function (x) { return x.id === g; })) return g;
    var own = groupOfReport(studio.state.reportId);
    return own ? own.id : 'mine';
}

// One layout per report of a group: the one the report prints with, else its first Body layout.
function groupDocs(group) {
    var layouts = studio.data.layouts;
    return group.reports.map(function (id) {
        var mine = layouts.filter(function (l) { return l.reportId === id; });
        return mine.filter(function (l) { return l.isDefault; })[0] || mine[0];
    }).filter(Boolean);
}

function styleKey() {
    var s = studio.state, copy = {};
    Object.keys(s).forEach(function (k) { if (['reportId', 'layoutName', 'layoutAppId', 'hasData', 'applyTo', 'themeName', 'hfName'].indexOf(k) < 0) copy[k] = s[k]; });
    return JSON.stringify(copy);
}

function galleryDocs() {
    var groupId = galleryGroup();
    var group = (studio.data.groups || []).filter(function (g) { return g.id === groupId; })[0];
    if (group) return groupDocs(group).slice(0, GALLERY_GROUP_MAX);
    var keys = null, layouts = studio.data.layouts;
    try { keys = JSON.parse(localStorage.getItem('rss-gallery-docs') || 'null'); } catch (e) { keys = null; }
    var docs = (keys || []).map(function (k) { return layouts.filter(function (l) { return docKey(l) === k; })[0]; }).filter(Boolean);
    if (keys && docs.length) return docs;
    // First time: the selected document, then typical documents, one layout per report.
    var seen = {}, add = function (l) { if (l && !seen[l.reportId] && docs.length < GALLERY_MAX) { seen[l.reportId] = true; docs.push(l); } };
    add(findLayout(studio.state.reportId, studio.state.layoutName));
    GALLERY_PREFERRED.forEach(function (id) { add(layouts.filter(function (l) { return l.reportId === id; })[0]); });
    layouts.forEach(add);
    return docs;
}

function saveGalleryDocs(docs) {
    try { localStorage.setItem('rss-gallery-docs', JSON.stringify(docs.map(docKey))); } catch (e) { /* storage blocked: the default set is used */ }
}

function refreshGallery(delay) {
    clearTimeout(gallery.timer);
    gallery.timer = setTimeout(renderGallery, delay === undefined ? 450 : delay);
}

function renderGallery() {
    var host = byId('rss-gallery');
    if (!host || studio.view !== 'gallery') return;
    var docs = galleryDocs(), style = styleKey(), groupId = galleryGroup(), groups = studio.data.groups || [];
    var group = groups.filter(function (g) { return g.id === groupId; })[0];
    if (gallery.compare) { renderComparison(docs.slice(0, COMPARE_MAX_DOCS)); return; }
    gallery.queue = [];
    var tabs = groups.map(function (g) {
        return '<button class="' + (g.id === groupId ? 'on' : '') + '" data-ggroup="' + g.id + '"' + (g.reports.length ? '' : ' disabled') + '>' +
            esc(g.caption) + ' <span>' + g.reports.length + '</span></button>';
    }).join('') + '<button class="' + (groupId === 'mine' ? 'on' : '') + '" data-ggroup="mine">My selection</button>';
    var more = group && group.reports.length > docs.length ? ' Showing ' + docs.length + ' of ' + group.reports.length + ' reports.' : '';
    var html = '<div class="rss-gal-groups" role="tablist">' + tabs + '</div>' +
        '<div class="rss-gal-head"><span id="rss-gal-status"></span>' +
        '<span class="rss-gal-note">' + (group
            ? 'Each report in ' + esc(group.caption.toLowerCase()) + ' with the layout it prints with.' + more
            : 'Your own pick of documents.') + ' Click a page to open it.</span></div><div class="rss-gal-grid">';
    if (group && !docs.length) html += '<div class="rss-gal-empty">No document in this group has a Body layout yet.</div>';
    docs.forEach(function (l, i) {
        html += '<div class="rss-gal-card" data-doc="' + esc(docKey(l)) + '">' +
            '<div class="rss-gal-top"><div class="rss-gal-name"><b>' + esc(l.reportName) + ' <span>' + l.reportId + '</span></b><small>' + esc(l.caption || l.name) + '</small></div>' +
            (group ? '' : '<button class="rss-gal-x" data-remove="' + i + '" title="Remove from the gallery" aria-label="Remove ' + esc(l.reportName) + '">×</button>') + '</div>' +
            '<button class="rss-gal-page" data-open="' + i + '" aria-label="Open ' + esc(l.reportName) + '"><div class="rss-gal-thumb" id="rss-gal-' + i + '"><div class="rss-gal-wait"><div class="rss-spinner"></div>Waiting…</div></div></button>' +
            '<div class="rss-gal-foot"><button class="rss-link" data-gdata="' + l.reportId + '">Preview data…</button><span id="rss-gal-pages-' + i + '"></span></div></div>';
    });
    if (!group && docs.length < GALLERY_MAX) {
        html += '<div class="rss-gal-card add">' + (gallery.adding
            ? '<input class="rss-input" id="rss-gal-find" type="search" placeholder="Add a document: search report or layout" value="' + esc(gallery.find) + '" autocomplete="off"><div class="rss-gal-results" id="rss-gal-results"></div>'
            : '<button class="rss-gal-addbtn" id="rss-gal-add"><span>+</span>Add document</button>') + '</div>';
    }
    host.innerHTML = html + '</div>';

    docs.forEach(function (l, i) {
        var hit = gallery.cache[docKey(l) + '|' + style];
        if (hit) showGalleryResult(i, hit); else gallery.queue.push({ index: i, doc: l, key: docKey(l) + '|' + style });
    });
    host.querySelectorAll('[data-ggroup]').forEach(function (b) {
        b.addEventListener('click', function () {
            try { localStorage.setItem('rss-gallery-group', b.getAttribute('data-ggroup')); } catch (e) { /* the group of the document is used */ }
            gallery.adding = false;
            renderGallery();
        });
    });
    host.querySelectorAll('[data-open]').forEach(function (b) {
        b.addEventListener('click', function () { openFromGallery(docs[+b.getAttribute('data-open')]); });
    });
    host.querySelectorAll('[data-remove]').forEach(function (b) {
        b.addEventListener('click', function () {
            var rest = docs.filter(function (_, i) { return i !== +b.getAttribute('data-remove'); });
            if (!rest.length) return;
            saveGalleryDocs(rest);
            renderGallery();
        });
    });
    host.querySelectorAll('[data-gdata]').forEach(function (b) {
        b.addEventListener('click', function () {
            Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('GalleryChooseDataRequested', [JSON.stringify(studio.state), +b.getAttribute('data-gdata')]);
        });
    });
    var addBtn = byId('rss-gal-add');
    if (addBtn) addBtn.addEventListener('click', function () { gallery.adding = true; gallery.find = ''; renderGallery(); byId('rss-gal-find').focus(); });
    var find = byId('rss-gal-find');
    if (find) {
        find.addEventListener('input', function () { gallery.find = find.value; renderGalleryResults(docs); });
        find.addEventListener('keydown', function (e) { if (e.key === 'Escape') { gallery.adding = false; renderGallery(); } });
        renderGalleryResults(docs);
    }
    sendGalleryBatch();
}

// The designer's style with one Copilot suggestion applied, the same way a click on the suggestion applies it.
function suggestionState(g) {
    var s = JSON.parse(JSON.stringify(studio.state));
    s.palette = studio.data.copilot.customPalette;
    s.customColors = g.colors.slice();
    s.fonts = g.fonts;
    s.tableStyle = g.tableStyle;
    s.pageColor = g.pageColor;
    if (g.customPage) s.customPage = g.customPage;
    s.themeName = g.name;
    return JSON.stringify(s);
}

// Two large previews side by side, each with its own Copilot theme, and the documents below to pick from.
// Left and right can be any two suggestions; a click on a document shows it in both previews.
function renderComparison(docs) {
    var host = byId('rss-gallery'), list = gallery.compare, cmp = gallery.cmp, cells = [];
    if (!cmp) cmp = gallery.cmp = { a: 0, b: list.length > 1 ? 1 : 0, doc: 0 };
    if (cmp.doc >= docs.length) cmp.doc = 0;
    var doc = docs[cmp.doc], styleA = suggestionState(list[cmp.a]), styleB = suggestionState(list[cmp.b]);
    var chips = function (attr, current) {
        return list.map(function (g, k) {
            return '<button class="rss-chip' + (k === current ? ' on' : '') + '" ' + attr + '="' + k + '">' + esc(g.name) + '</button>';
        }).join('');
    };
    var side = function (id, g) {
        return '<div class="rss-cmp-side"><div class="rss-gal-thumb rss-cmp-large" id="rss-gal-' + id + '"><div class="rss-gal-wait"><div class="rss-spinner"></div>Waiting…</div></div>' +
            '<b>' + esc(g.name) + '</b><small>' + esc(g.reason) + '</small></div>';
    };
    var html = '<div class="rss-gal-head"><span id="rss-gal-status"></span>' +
        '<span class="rss-gal-note"><button class="rss-link" data-cmp-exit>Back to my documents</button></span></div>' +
        '<div class="rss-cmp-pick"><div><span>Left</span>' + chips('data-cmp-a', cmp.a) + '</div>' +
        '<div><span>Right</span>' + chips('data-cmp-b', cmp.b) + '</div></div>' +
        '<div class="rss-cmp-big">' + side('big-a', list[cmp.a]) + side('big-b', list[cmp.b]) + '</div>' +
        '<div class="rss-cmp-docs-head">Show on another document</div>' +
        '<div class="rss-cmp-docs">' + docs.map(function (l, i) {
            return '<button class="rss-cmp-doc' + (i === cmp.doc ? ' on' : '') + '" data-cmp-doc="' + i + '">' +
                '<div class="rss-gal-thumb" id="rss-gal-g-' + i + '"><div class="rss-gal-wait"><div class="rss-spinner"></div>Waiting…</div></div>' +
                '<span>' + esc(l.reportName) + '</span></button>';
        }).join('') + '</div>';
    host.innerHTML = html;

    host.querySelector('[data-cmp-exit]').addEventListener('click', function () { gallery.compare = null; gallery.cmp = null; renderGallery(); });
    host.querySelectorAll('[data-cmp-a]').forEach(function (b) { b.addEventListener('click', function () { cmp.a = +b.getAttribute('data-cmp-a'); renderGallery(); }); });
    host.querySelectorAll('[data-cmp-b]').forEach(function (b) { b.addEventListener('click', function () { cmp.b = +b.getAttribute('data-cmp-b'); renderGallery(); }); });
    host.querySelectorAll('[data-cmp-doc]').forEach(function (b) { b.addEventListener('click', function () { cmp.doc = +b.getAttribute('data-cmp-doc'); renderGallery(); }); });

    cells.push({ index: 'big-a', doc: doc, style: styleA }, { index: 'big-b', doc: doc, style: styleB });
    docs.forEach(function (l, i) { cells.push({ index: 'g-' + i, doc: l, style: styleA }); });
    gallery.expected = {};
    cells.forEach(function (c) {
        var key = docKey(c.doc) + '|' + c.style;
        gallery.expected[c.index] = key;
        var hit = gallery.cache[key];
        if (hit) showGalleryResult(c.index, hit); else gallery.queue.push({ index: c.index, doc: c.doc, key: key, state: c.style });
    });
    sendGalleryBatch();
}

// A banner at the top of the designer when Copilot has proposals, so they are easy to find.
function suggestionBanner() {
    var list = studio.data.copilot && studio.data.copilot.suggestions;
    if (!list || !list.length) return '';
    return '<div class="rss-cmp-banner"><span>Copilot suggested ' + list.length + ' themes.</span>' +
        '<button class="rss-primary" data-compare="1">Compare them</button></div>';
}

// Everything that is not cached goes to one background session; finished pages are picked up by polling.
function sendGalleryBatch() {
    gallery.jobs = {};
    stopGalleryPoll();
    if (!gallery.queue.length) { updateGalleryStatus(); return; }
    var docs = gallery.queue.map(function (item) {
        gallery.seq += 1;
        gallery.jobs[gallery.seq] = item;
        var box = byId('rss-gal-' + item.index);
        if (box) box.innerHTML = '<div class="rss-gal-wait"><div class="rss-spinner"></div>Rendering…</div>';
        var entry = { reportId: item.doc.reportId, name: item.doc.name, appId: item.doc.appId || '', seq: gallery.seq };
        if (item.state) entry.state = item.state;   // a comparison cell carries its own style
        return entry;
    });
    gallery.queue = [];
    gallery.started = Date.now();
    updateGalleryStatus();
    Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('GalleryBatchRequested', [JSON.stringify(studio.state), JSON.stringify(docs)]);
}

// AL -> JS: how many pages of the batch are still being rendered.
function GalleryProgress(pending) {
    stopGalleryPoll();
    updateGalleryStatus();
    if (studio.view !== 'gallery' || pending <= 0 || !Object.keys(gallery.jobs).length) return;
    if (Date.now() - gallery.started > GALLERY_TIMEOUT_MS) {
        Object.keys(gallery.jobs).forEach(function (seq) { showGalleryResult(gallery.jobs[seq].index, { error: 'This page took too long. Switch views to try again.' }); });
        gallery.jobs = {};
        updateGalleryStatus();
        return;
    }
    gallery.poll = setTimeout(function () {
        gallery.poll = null;
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('GalleryPoll', []);
    }, 1000);
}

function stopGalleryPoll() {
    if (gallery.poll) clearTimeout(gallery.poll);
    gallery.poll = null;
}

function renderGalleryResults(docs) {
    var list = byId('rss-gal-results');
    if (!list) return;
    var shown = docs.map(docKey), words = gallery.find.toLowerCase().split(/\s+/).filter(Boolean);
    var hits = studio.data.layouts.filter(function (l) {
        var text = (l.reportName + ' ' + l.reportId + ' ' + (l.caption || '') + ' ' + l.name).toLowerCase();
        return shown.indexOf(docKey(l)) < 0 && words.every(function (w) { return text.indexOf(w) >= 0; });
    }).slice(0, 6);
    list.innerHTML = hits.length
        ? hits.map(function (l, i) { return '<div class="rss-pick" data-gadd="' + i + '"><b>' + esc(l.reportName) + ' <span>' + l.reportId + '</span></b><small>' + esc(l.caption || l.name) + '</small></div>'; }).join('')
        : '<div class="rss-pick-empty">No other Body layout matches.</div>';
    list.querySelectorAll('[data-gadd]').forEach(function (el) {
        el.addEventListener('mousedown', function (e) {
            e.preventDefault();
            saveGalleryDocs(docs.concat([hits[+el.getAttribute('data-gadd')]]));
            gallery.adding = false;
            renderGallery();
        });
    });
}

function ShowGalleryPage(seq, base64Pdf) { galleryResponse(seq, { pdf: base64Pdf }); }
function ShowGalleryError(seq, message) { galleryResponse(seq, { error: message }); }

function galleryResponse(seq, result) {
    var job = gallery.jobs[seq];
    if (!job) return;   // from a batch that was replaced
    delete gallery.jobs[seq];
    gallery.cache[job.key] = result;
    // Only draw when the card still shows that document in that style.
    // A comparison cell expects the key it was given; a gallery card expects its document in the current style.
    var card = byId('rss-gal-' + job.index), doc = card ? card.closest('[data-doc]') : null, wanted;
    if (job.state) wanted = gallery.expected[job.index];
    else if (doc) wanted = doc.getAttribute('data-doc') + '|' + styleKey();
    if (card && wanted === job.key) showGalleryResult(job.index, result);
    updateGalleryStatus();
}

function GalleryDataChanged(reportId) {
    Object.keys(gallery.cache).forEach(function (k) { if (k.indexOf(reportId + '|') === 0) delete gallery.cache[k]; });
    if (studio.view === 'gallery') renderGallery();
}

function showGalleryResult(index, result) {
    var box = byId('rss-gal-' + index);
    if (!box) return;
    if (result.error) {
        box.innerHTML = '<div class="rss-gal-err">' + esc(result.error) + '</div>';
        updateGalleryStatus();
        return;
    }
    var pdfjsLib = globalThis.pdfjsLib;
    if (!pdfjsLib) { box.innerHTML = '<div class="rss-gal-err">The PDF viewer could not be loaded.</div>'; return; }
    pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdn-bc.dynamics.com/common/js/pdfjs-4.10.38/pdf.worker.min.mjs';
    var raw = atob(result.pdf), bytes = new Uint8Array(raw.length);
    for (var i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
    pdfjsLib.getDocument({ data: bytes }).promise.then(function (pdf) {
        return pdf.getPage(1).then(function (page) {
            var base = page.getViewport({ scale: 1 });
            var width = Math.max(160, box.clientWidth || 240), ratio = window.devicePixelRatio || 1;
            var viewport = page.getViewport({ scale: width / base.width });
            var canvas = document.createElement('canvas');
            canvas.width = Math.floor(viewport.width * ratio);
            canvas.height = Math.floor(viewport.height * ratio);
            canvas.style.width = '100%';
            return page.render({ canvasContext: canvas.getContext('2d'), viewport: viewport, transform: ratio !== 1 ? [ratio, 0, 0, ratio, 0, 0] : null }).promise.then(function () {
                box.innerHTML = '';
                box.appendChild(canvas);
                var more = byId('rss-gal-pages-' + index);
                if (more) more.textContent = pdf.numPages > 1 ? pdf.numPages + ' pages' : '1 page';
                updateGalleryStatus();
            });
        });
    }).catch(function () { box.innerHTML = '<div class="rss-gal-err">This page could not be shown.</div>'; });
}

function updateGalleryStatus() {
    var el = byId('rss-gal-status');
    if (!el) return;
    var left = Object.keys(gallery.jobs).length;
    el.textContent = left ? 'Rendering… ' + left + ' to go' : '';
}

function openFromGallery(l) {
    var s = studio.state;
    s.reportId = l.reportId;
    s.layoutName = l.name;
    s.layoutAppId = l.appId;
    rememberLayout(l);
    renderPanel();
    setView('single');
}

/* ---------- document picker ---------- */
// Search instead of one long list: matches report name, report number and layout name (all words must match).
// Recently used layouts come first; "Browse all…" opens the Body Layouts list page with its own search and filters.

var PICKER_LIMIT = 30;

function wirePicker() {
    byId('rss-combo-btn').addEventListener('click', function () {
        studio.pickerOpen = !studio.pickerOpen;
        studio.find = '';
        studio.pickIndex = 0;
        renderPanel();
        if (studio.pickerOpen) byId('rss-find').focus();
    });
    var find = byId('rss-find');
    if (!find) return;
    renderPickerList();
    find.addEventListener('input', function () { studio.find = find.value; studio.pickIndex = 0; renderPickerList(); });
    find.addEventListener('keydown', function (e) {
        var count = studio.pickItems.length;
        if (e.key === 'ArrowDown') { studio.pickIndex = Math.min(count - 1, studio.pickIndex + 1); renderPickerList(); e.preventDefault(); }
        else if (e.key === 'ArrowUp') { studio.pickIndex = Math.max(0, studio.pickIndex - 1); renderPickerList(); e.preventDefault(); }
        else if (e.key === 'Enter') { if (studio.pickItems[studio.pickIndex]) pickLayout(studio.pickItems[studio.pickIndex]); e.preventDefault(); }
        else if (e.key === 'Escape') { closePicker(); e.preventDefault(); }
    });
    byId('rss-browse').addEventListener('click', function () {
        closePicker();
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('BrowseLayoutsRequested', [JSON.stringify(studio.state)]);
    });
}

function renderPickerList() {
    var list = byId('rss-picker-list');
    if (!list) return;
    var all = studio.data.layouts, query = (studio.find || '').toLowerCase().split(/\s+/).filter(Boolean);
    var items = [], html = '';
    if (!query.length) {
        var recent = recentLayouts();
        if (recent.length) {
            html += '<div class="rss-pick-group">Recent</div>';
            recent.forEach(function (l) { html += pickRow(l, items.length); items.push(l); });
            html += '<div class="rss-pick-group">All reports</div>';
        }
        all.forEach(function (l) { if (recent.indexOf(l) < 0 && items.length < PICKER_LIMIT) { html += pickRow(l, items.length); items.push(l); } });
    } else {
        all.forEach(function (l) {
            var text = (l.reportName + ' ' + l.reportId + ' ' + (l.caption || '') + ' ' + l.name).toLowerCase();
            if (items.length < PICKER_LIMIT && query.every(function (w) { return text.indexOf(w) >= 0; })) { html += pickRow(l, items.length); items.push(l); }
        });
        if (!items.length) html = '<div class="rss-pick-empty">No Body layout matches "' + esc(studio.find) + '". Try Browse all…</div>';
    }
    studio.pickItems = items;
    list.innerHTML = html;
    list.querySelectorAll('[data-pick]').forEach(function (el) {
        el.addEventListener('mousedown', function (e) { e.preventDefault(); pickLayout(items[+el.getAttribute('data-pick')]); });
    });
    var active = list.querySelector('.active');
    if (active) active.scrollIntoView({ block: 'nearest' });
    var matched = query.length ? countMatches(query) : all.length;
    byId('rss-picker-count').textContent = items.length < matched ? items.length + ' of ' + matched + ' shown' : matched + ' layout' + (matched === 1 ? '' : 's');
}

function pickRow(l, index) {
    var s = studio.state, current = l.reportId === s.reportId && l.name === s.layoutName;
    return '<div class="rss-pick' + (index === studio.pickIndex ? ' active' : '') + (current ? ' current' : '') + '" role="option" aria-selected="' + current + '" data-pick="' + index + '">' +
        '<b>' + esc(l.reportName) + ' <span>' + l.reportId + '</span></b><small>' + esc(l.caption || l.name) + '</small></div>';
}

function countMatches(query) {
    return studio.data.layouts.filter(function (l) {
        var text = (l.reportName + ' ' + l.reportId + ' ' + (l.caption || '') + ' ' + l.name).toLowerCase();
        return query.every(function (w) { return text.indexOf(w) >= 0; });
    }).length;
}

function pickLayout(l) {
    var s = studio.state;
    s.reportId = l.reportId;
    s.layoutName = l.name;
    s.layoutAppId = l.appId;
    rememberLayout(l);
    closePicker();
    requestPreview(0);
}

function closePicker() {
    studio.pickerOpen = false;
    renderPanel();
}

// Recently used layouts, kept in this browser only (a convenience; the list works without it).
function recentLayouts() {
    var keys = [];
    try { keys = JSON.parse(localStorage.getItem('rss-recent-layouts') || '[]'); } catch (e) { keys = []; }
    var s = studio.state, current = s.reportId + '|' + s.layoutName;
    if (keys.indexOf(current) < 0) keys.unshift(current);
    return keys.map(function (k) {
        return studio.data.layouts.filter(function (l) { return l.reportId + '|' + l.name === k; })[0];
    }).filter(Boolean).slice(0, 5);
}

function rememberLayout(l) {
    try {
        var key = l.reportId + '|' + l.name;
        var keys = JSON.parse(localStorage.getItem('rss-recent-layouts') || '[]').filter(function (k) { return k !== key; });
        keys.unshift(key);
        localStorage.setItem('rss-recent-layouts', JSON.stringify(keys.slice(0, 8)));
    } catch (e) { /* storage blocked: no recent list */ }
}

/* ---------- Copilot ---------- */

var SPARKLE = '<svg class="rss-sparkle" viewBox="0 0 16 16" aria-hidden="true"><path d="M8 1l1.6 4.4L14 7l-4.4 1.6L8 13l-1.6-4.4L2 7l4.4-1.6z"/><path d="M13 11l.6 1.4L15 13l-1.4.6L13 15l-.6-1.4L11 13l1.4-.6z"/></svg>';

// Same rule as the server: blend towards white until the colour is a pale tint (lightness >= 92%).
function lightPage(hex) {
    var c = [0, 2, 4].map(function (i) { return parseInt(hex.substr(i, 2), 16); });
    for (var step = 0; step <= 20; step++) {
        var m = c.map(function (v) { return Math.round(v + (255 - v) * step * 0.05); });
        if ((Math.max.apply(null, m) + Math.min.apply(null, m)) / 510 >= 0.92 || step === 20)
            return m.map(function (v) { return ('0' + v.toString(16)).slice(-2); }).join('').toUpperCase();
    }
}

function hasCustomColors() { return studio.state.customColors && studio.state.customColors.length === 12; }

function sameColors(a, b) { return !!a && !!b && a.join() === b.join(); }

function swatchRow(colors) {
    return '<div class="rss-swatches">' + [0, 6, 7, 8, 9, 3].map(function (i) {
        return '<span style="background:#' + colors[i] + '"></span>';
    }).join('') + '</div>';
}

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

/* ---------- helpers ---------- */

function section(title, body, hint) {
    return '<div class="rss-section"><div class="rss-section-title">' + title + '</div>' + body +
        (hint ? '<div class="rss-hint">' + hint + '</div>' : '') + '</div>';
}
function shortCaption(caption) { return caption.replace('Keep base theme ', 'Theme ').replace('Keep base theme', 'Theme'); }
function captionOf(list, id) { for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i].caption; return ''; }
function findLayout(reportId, name) {
    return studio.data.layouts.filter(function (l) { return l.reportId === reportId && l.name === name; })[0];
}
function on(root, selector, handler) {
    root.querySelectorAll(selector).forEach(function (el) { el.addEventListener('click', function () { handler(el); }); });
}
function byId(id) { return document.getElementById(id); }
function show(id) { byId(id).classList.add('visible'); }
function hide(id) { var el = byId(id); if (id === 'rss-error') { el.hidden = true; } else { el.classList.remove('visible'); } }
function esc(text) {
    return String(text).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}
