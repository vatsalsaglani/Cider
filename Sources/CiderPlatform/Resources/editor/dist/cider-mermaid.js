/* Cider's preview adapter. Markdown source nodes are never modified. */
(() => {
  const theme = {
    startOnLoad: false, securityLevel: 'strict', suppressErrorRendering: true,
    theme: 'base', fontFamily: '-apple-system, BlinkMacSystemFont, sans-serif',
    themeVariables: {
      darkMode: true, background: '#101011', primaryColor: '#38271f',
      primaryTextColor: '#f5f2ed', primaryBorderColor: '#d98245',
      secondaryColor: '#242326', secondaryTextColor: '#f5f2ed',
      secondaryBorderColor: '#8e8178', tertiaryColor: '#211c19',
      tertiaryTextColor: '#f5f2ed', tertiaryBorderColor: '#796153',
      lineColor: '#efa665', textColor: '#f5f2ed', mainBkg: '#38271f',
      nodeBorder: '#d98245', clusterBkg: '#1c1917', clusterBorder: '#796153',
      edgeLabelBackground: '#171515', titleColor: '#f5f2ed',
      actorBkg: '#38271f', actorBorder: '#d98245', actorTextColor: '#f5f2ed',
      signalColor: '#efa665', signalTextColor: '#f5f2ed',
      noteBkgColor: '#342b22', noteTextColor: '#f5f2ed', noteBorderColor: '#ad865d'
    },
    flowchart: { htmlLabels: false, useMaxWidth: true },
    sequence: { useMaxWidth: true }
  };
  mermaid.initialize(theme);
  const states = new WeakMap();
  let queue = Promise.resolve();
  let nextID = 0;
  function render(root = document) {
    root.querySelectorAll('.language-mermaid').forEach(node => {
      // IR and WYSIWYG keep a separate source <pre>. Only touch projections.
      if (node.closest('.vditor-ir__marker--pre, .vditor-wysiwyg__pre')) return;
      const previous = states.get(node);
      if (previous && (previous.pending || node.querySelector('svg, .cider-diagram-error'))) return;
      const source = node.textContent;
      if (!source.trim()) return;
      const state = { source, pending: true };
      states.set(node, state);
      queue = queue.then(async () => {
        if (!node.isConnected || node.textContent !== source) { states.delete(node); if (node.isConnected) setTimeout(() => render(node.parentElement), 0); return; }
        try {
          const result = await mermaid.render('ciderDiagram' + (++nextID), source);
          if (!node.isConnected || node.textContent !== source) { states.delete(node); if (node.isConnected) setTimeout(() => render(node.parentElement), 0); return; }
          node.innerHTML = result.svg;
          node.setAttribute('data-processed', 'true');
        } catch (_) {
          if (!node.isConnected || node.textContent !== source) { states.delete(node); if (node.isConnected) setTimeout(() => render(node.parentElement), 0); return; }
          const error = document.createElement('div');
          error.className = 'cider-diagram-error';
          error.textContent = 'This diagram needs a small correction. Edit the Mermaid block to try again.';
          error.setAttribute('role', 'status');
          node.replaceChildren(error);
        } finally { state.pending = false; }
      });
    });
    return queue;
  }
  window.ciderRenderMermaid = render;
  // Vditor can replace a preview after its render callback has already returned.
  let timer;
  new MutationObserver(records => {
    if (records.every(record => record.target.nodeType === 1 && record.target.closest('svg, .cider-diagram-error'))) return;
    clearTimeout(timer);
    timer = setTimeout(() => document.querySelectorAll('.vditor-ir__preview, .vditor-wysiwyg__preview, .vditor-preview').forEach(render), 100);
  }).observe(document.getElementById('editor'), { subtree: true, childList: true, characterData: true });
})();
