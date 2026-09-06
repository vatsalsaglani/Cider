(function(){
  const root=document.getElementById('cider-canvas');
  const q=function(s){return root.querySelector(s);};
  const qa=function(s){return Array.from(root.querySelectorAll(s));};
  const state={page:'notes',hudTab:'today',edge:'top',expanded:true,pinned:false,compact:false,hover:true,external:true,feature:'workspace',annotating:false,source:false,accent:'#ff8a3d',radius:16};
  const details={
    ui:{provider:'Codex · UI lane',title:'Ready for your eyes.',message:'The stream view is in place. Unit tests passed. Please check the empty state and reconnect behavior.',status:'Awaiting your test',path:'feature/stream-ui · Head 7a4c2e1 · Phase 03'},
    schema:{provider:'Claude Code · Architect',title:'A decision before the next run.',message:'Should checkpoints resume the entire phase, or only the interrupted worker? The other lanes can continue while you decide.',status:'Waiting for your input',path:'feature/checkpoints · Head a63e9d0 · Phase 02'},
    worker:{provider:'Codex · Worker lane',title:'One case needs another look.',message:'The timeout fixture reproduces a duplicate event after retry. The agent left the failing test and a proposed fix for review.',status:'Failed check · needs review',path:'feature/event-retry · Head c73f15b · Phase 04'}
  };
  let selected='ui',dwell,leave,activeNote='review';
  const notes={review:{title:'Orchestration review',filename:'phase-03-review.md',body:q('#c-document').innerHTML,images:[]},draft:{title:'',filename:'untitled.md',body:'',images:[]}};
  const taskKit=createCiderTasks(root,{announce,icons,isDayView:()=>state.page==='today',openDay:()=>showPage('today'),changed:()=>{if(state.hudTab==='today')renderHUD();}});
  const lanes={workspace:[['UI lane','Codex · feature/stream-ui','Awaiting test'],['API lane','Codex · feature/stream-api','Running'],['Contract review','Claude Code · phase-03','Running']],session:[['Architect','Claude Code · feature/checkpoints','Needs input'],['Persistence','Codex · feature/session-db','Running'],['Recovery','Codex · feature/recovery','Running']],trace:[['Worker retry','Codex · feature/event-retry','Failed check'],['Ingest adapter','Codex · feature/trace-ingest','Running'],['Replay checks','Claude Code · feature/replay','Running']]};
  function icons(){if(globalThis.lucide){globalThis.lucide.createIcons({attrs:{width:15,height:15}});}}
  function announce(text){q('#c-feedback').textContent=text;}
  function updateNotePresentation(){
    const title=q('#c-note-title'),body=q('#c-document');
    title.dataset.empty=String(!title.textContent.trim());
    body.dataset.empty=String(!body.textContent.trim()&&!body.querySelector('img,hr,table'));
    const text=body.innerText.trim(),words=text?text.split(/\s+/u).length:0;
    q('#c-note-word-count').textContent=words+' '+(words===1?'word':'words');
    notes[activeNote].title=title.textContent.trim();
    q('#c-draft-label').textContent=activeNote==='draft'?(title.textContent.trim()||'Untitled'):(notes.draft.title||'Untitled');
  }
  function openNote(id,focusEditor=false){
    notes[activeNote].title=q('#c-note-title').textContent.trim();
    notes[activeNote].body=q('#c-document').innerHTML;
    notes[activeNote].images=Array.from(q('#c-pasted-images').children);
    activeNote=id;const note=notes[id];
    q('#c-note-title').textContent=note.title;q('#c-note-filename').textContent=note.filename;
    q('#c-document').innerHTML=note.body;q('#c-pasted-images').replaceChildren(...note.images);
    q('#c-note-meta').hidden=id!=='review';qa('[data-review-only]').forEach(function(x){x.hidden=id!=='review';});
    q('#c-note-rendered').classList.toggle('is-draft',id==='draft');
    q('#c-note-kind').textContent=id==='draft'?'New note':'Review';
    qa('[data-note-link]').forEach(function(x){if(x.dataset.noteLink===id)x.setAttribute('aria-current','true');else x.removeAttribute('aria-current');});
    state.source=false;q('#c-note-mode').setAttribute('aria-pressed','false');q('#c-note-mode').setAttribute('aria-label','Markdown source');q('#c-note-mode').dataset.tooltip='Markdown source';q('#c-note-rendered').hidden=false;q('#c-note-source').hidden=true;
    updateNotePresentation();
    showPage('notes');
    if(focusEditor)q(note.title?'#c-document':'#c-note-title').focus();
  }
  function renderShell(){
    q('#c-app').classList.toggle('c-compact',state.compact);
    q('#c-sidebar-toggle').setAttribute('aria-pressed',String(state.compact));
    qa('.c-nav > button').forEach(function(button){button.dataset.tooltip=button.getAttribute('aria-label');button.dataset.tooltipPlacement='right';});
    q('#c-sidebar-mode').value=state.compact?'compact':'expanded';
    const hud=q('#c-hud');hud.dataset.edge=state.edge;hud.classList.toggle('c-collapsed',!state.expanded);
    q('#c-hud-body').hidden=!state.expanded;q('#c-hud-toggle').setAttribute('aria-expanded',String(state.expanded));
    q('#c-pin-hud').setAttribute('aria-pressed',String(state.pinned));
    q('#c-pin-hud').dataset.tooltip=state.pinned?'Unpin notch':'Pin notch';q('#c-pin-hud').setAttribute('aria-label',state.pinned?'Unpin notch':'Pin notch');
    q('#c-anchor-label').textContent='Built-in display · '+state.edge;
    q('#c-edge').value=state.edge;
    q('#c-focus-label').textContent=state.external?'External display in use':'MacBook in use';
    root.style.setProperty('--c-orange',state.accent);root.style.setProperty('--c-radius',state.radius+'px');
    icons();
  }
  function showPage(page){state.page=page;qa('[data-pane]').forEach(function(p){p.hidden=p.dataset.pane!==page;});qa('.c-nav [data-page]').forEach(function(b){if(b.dataset.page===page)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current');});if(page==='features')renderLanes();}
  function selectAttention(id){selected=id;const d=details[id];if(!d)return;showPage('inbox');qa('.c-attention').forEach(function(b){b.setAttribute('aria-pressed',String(b.dataset.attention===id));});q('#c-detail-provider').textContent=d.provider;q('#c-detail-title').textContent=d.title;q('#c-detail-message').textContent=d.message;q('#c-detail-state').textContent=d.status;q('#c-detail-path').textContent=d.path;qa('[data-verify]').forEach(function(c){c.checked=false;});announce('Selected '+d.provider+' · source and human verification are separate');}
  function renderLanes(){qa('[data-feature]').forEach(function(b){b.setAttribute('aria-pressed',String(b.dataset.feature===state.feature));});const names={workspace:'Agent workspace · Phase 03',session:'Session engine · Phase 02',trace:'Trace pipeline · Phase 04'};q('#c-feature-label').textContent=names[state.feature]+' lanes';q('#c-lanes').replaceChildren();lanes[state.feature].forEach(function(l){const row=document.createElement('div');row.className='c-lane';const title=document.createElement('span');title.textContent=l[0];const small=document.createElement('small');small.textContent=l[1];title.append(small);const mid=document.createElement('span');mid.className='c-muted';mid.textContent='Plan linked';const tag=document.createElement('span');tag.className='c-pill'+(l[2]!=='Running'?' c-warm':'');tag.textContent=l[2];row.append(title,mid,tag);q('#c-lanes').append(row);});}
  function renderHUD(){
    qa('[data-hud-tab]').forEach(function(b){b.setAttribute('aria-pressed',String(b.dataset.hudTab===state.hudTab));});
    const el=q('#c-hud-content');el.replaceChildren();
    if(state.hudTab==='inbox'){[['schema','Schema decision needed','8m'],['worker','Worker retry check failed','14m'],['ui','UI lane ready to test','2m']].forEach(function(r){const b=document.createElement('button');b.className='c-hud-row';b.dataset.attention=r[0];b.innerHTML='<span class="c-dot"></span>';b.append(document.createTextNode(r[1]));const age=document.createElement('span');age.textContent=r[2];b.append(age);el.append(b);});}
    q('#c-hud-day-label').textContent=state.hudTab==='inbox'?'3 need you':state.hudTab==='notes'?'Notes':state.hudTab==='usage'?'Usage':'Today';
    if(state.hudTab==='today')taskKit.renderHUD(el);
    if(state.hudTab==='notes'){const wrap=document.createElement('div');wrap.innerHTML='<p class="c-small c-muted" style="padding:9px 0">A thought, a screenshot, a quick finding.</p><button class="c-hud-row" data-page="notes">Orchestration review<span>Recent</span></button>';el.append(wrap);}
    if(state.hudTab==='usage'){[['Codex','21% used'],['Claude Code','73% used'],['Cursor','52% · stale']].forEach(function(r){const b=document.createElement('button');b.className='c-hud-row';b.dataset.page='usage';b.textContent=r[0];const n=document.createElement('span');n.textContent=r[1];b.append(n);el.append(b);});}
  }
  root.addEventListener('click',function(e){
    const b=e.target.closest('button');if(!b||!root.contains(b))return;
    if(b.dataset.page){showPage(b.dataset.page);}
    if(b.dataset.attention){selectAttention(b.dataset.attention);}
    if(b.dataset.hudTab){state.hudTab=b.dataset.hudTab;renderHUD();}
    if(b.dataset.feature){state.feature=b.dataset.feature;renderLanes();}
    if(b.dataset.folder){showPage('notes');q('#c-note-folder').textContent=b.dataset.folder+' /';announce('Folder selected · '+b.dataset.folder);}
    if(b.dataset.action==='new-note'){openNote('draft',true);announce('New note');}
    if(b.dataset.action==='review-note'){openNote('review');announce('Review notes');}
    if(b.dataset.action==='hud-task'){state.hudTab='today';state.expanded=true;renderShell();renderHUD();taskKit.focusHUD();}
    if(b.dataset.action==='finding-task'){taskKit.addFinding(activeNote==='review'?'Make reconnect state clearer':q('#c-document').innerText.trim().slice(0,100)||'Review my note',notes[activeNote].title||'Untitled');showPage('today');}
    if(b.classList.contains('c-pin')){announce(b.getAttribute('aria-label'));}
  });
  q('#c-sidebar-toggle').addEventListener('click',function(){state.compact=!state.compact;renderShell();});
  q('#c-sidebar-mode').addEventListener('change',function(e){state.compact=e.target.value==='compact';renderShell();});
  q('#c-edge').addEventListener('change',function(e){state.edge=e.target.value;state.expanded=true;renderShell();announce('Notch moved to '+state.edge+' · still on the built-in display');});
  q('#c-focus-switch').addEventListener('click',function(){state.external=!state.external;renderShell();announce('Focus changed · the notch stays on the MacBook');});
  q('#c-hud-toggle').addEventListener('click',function(){clearTimeout(dwell);clearTimeout(leave);state.expanded=!state.expanded;renderShell();});
  q('#c-pin-hud').addEventListener('click',function(){state.pinned=!state.pinned;state.expanded=true;renderShell();});
  q('#c-hud').addEventListener('mouseenter',function(){clearTimeout(leave);if(state.hover&&!state.expanded)dwell=setTimeout(function(){state.expanded=true;renderShell();},250);});
  q('#c-hud').addEventListener('mouseleave',function(){clearTimeout(dwell);if(state.hover&&!state.pinned)leave=setTimeout(function(){const focus=document.activeElement;if(q('#c-hud').contains(focus)&&focus.matches('input,textarea,[contenteditable]'))return;state.expanded=false;renderShell();},450);});
  q('#c-hover-mode').addEventListener('click',function(){state.hover=!state.hover;q('#c-hover-mode').setAttribute('aria-pressed',String(state.hover));q('#c-hover-mode').setAttribute('aria-label',state.hover?'Disable hover opening':'Enable hover opening');q('#c-hover-mode').dataset.tooltip=state.hover?'Disable hover opening':'Enable hover opening';clearTimeout(dwell);clearTimeout(leave);});
  root.addEventListener('keydown',function(e){if(e.key==='Escape'){taskKit.closeCapture();state.pinned=false;state.expanded=false;renderShell();}});
  q('#c-open-origin').addEventListener('click',function(){announce(details[selected].provider+' · '+details[selected].path);});
  qa('[data-verify]').forEach(function(c){c.addEventListener('change',function(){const n=qa('[data-verify]').filter(function(x){return x.checked;}).length;announce(n+' of 2 checks completed');});});
  q('#c-document').addEventListener('input',function(){updateNotePresentation();announce('Note updated');});
  q('#c-note-title').addEventListener('input',function(){updateNotePresentation();announce('Note title updated');});
  q('#c-note-title').addEventListener('keydown',function(e){if(e.key==='Enter'&&!e.isComposing){e.preventDefault();q('#c-document').focus();}});
  q('#c-note-rendered').addEventListener('click',function(e){if(e.target===q('#c-note-rendered'))q('#c-document').focus();});
  q('#c-annotate').addEventListener('click',function(){state.annotating=!state.annotating;root.classList.toggle('c-annotation-on',state.annotating);q('#c-annotate').setAttribute('aria-pressed',String(state.annotating));announce(state.annotating?'Click an image to place a numbered annotation':'Annotation mode off');});
  root.addEventListener('click',function(e){if(!state.annotating||e.target.closest('.c-pin'))return;const shot=e.target.closest('.c-shot');if(!shot)return;const rect=shot.getBoundingClientRect();const count=shot.querySelectorAll('.c-pin').length+1;const pin=document.createElement('button');pin.className='c-pin';pin.style.left=Math.min(96,Math.max(4,100*(e.clientX-rect.left)/rect.width))+'%';pin.style.top=Math.min(89,Math.max(11,100*(e.clientY-rect.top)/rect.height))+'%';pin.textContent=String(count);pin.setAttribute('aria-label','Annotation '+count+': new review finding');shot.append(pin);if(shot.id==='c-demo-shot')q('#c-pin-count').textContent='Original preserved · '+count+' pins';announce('Annotation '+count+' added · original image unchanged');});
  function addImage(file){if(!file||!file.type.startsWith('image/'))return;if(file.size>25*1024*1024){announce('Choose an image smaller than 25 MB');return;}const targetNote=activeNote;const reader=new FileReader();reader.onload=function(){const box=document.createElement('div');box.className='c-shot';box.setAttribute('aria-label','Pasted review image');const img=document.createElement('img');img.src=String(reader.result);img.alt='Pasted review evidence';box.append(img);if(targetNote===activeNote)q('#c-pasted-images').append(box);else notes[targetNote].images.push(box);announce('Image added to '+(notes[targetNote].title||'Untitled'));};reader.readAsDataURL(file);}
  q('#c-insert-image').addEventListener('click',function(){q('#c-image-file').click();});
  q('#c-image-file').addEventListener('change',function(e){addImage(e.target.files[0]);e.target.value='';});
  q('#c-document').addEventListener('paste',function(e){const items=e.clipboardData?Array.from(e.clipboardData.items):[];const item=items.find(function(i){return i.type.startsWith('image/');});if(item){e.preventDefault();addImage(item.getAsFile());}});
  q('#c-asset-policy').addEventListener('change',function(e){const path={file:'phase-03-review.assets/reconnect.png',workspace:'assets/reconnect.png',custom:'evidence/phase-03/reconnect.png'};q('#c-asset-path').textContent=path[e.target.value];announce('Image folder selected');});
  q('#c-note-mode').addEventListener('click',function(){state.source=!state.source;q('#c-note-mode').setAttribute('aria-pressed',String(state.source));q('#c-note-mode').dataset.tooltip=state.source?'Live view':'Markdown source';q('#c-note-mode').setAttribute('aria-label',state.source?'Live view':'Markdown source');q('#c-note-rendered').hidden=state.source;q('#c-note-source').hidden=!state.source;if(state.source){const review=activeNote==='review';q('#c-note-source').value=(review?'---\nphase: 03\nstatus: verification\nagent: Codex\n---\n\n':'')+(q('#c-note-title').textContent.trim()?'# '+q('#c-note-title').textContent.trim()+'\n\n':'')+q('#c-document').innerText+(review?'\n\n![Reconnect evidence]('+q('#c-asset-path').textContent+')\n\n'+String.fromCharCode(96).repeat(3)+'mermaid\nflowchart LR\n  Plan --> Build --> Verify\n'+String.fromCharCode(96).repeat(3):'');}announce(state.source?'Markdown source':'Live view');});
  q('#c-refresh-usage').addEventListener('click',function(){qa('.c-fresh-label').forEach(function(x){x.textContent='updated just now';});q('#c-cursor-usage').classList.remove('is-stale');q('#c-cursor-state').textContent='Current';q('#c-cursor-freshness').textContent='Resets in 12 days · updated just now';q('#c-cursor-unit').textContent='used';announce('Usage updated');});
  renderShell();renderLanes();taskKit.render();renderHUD();openNote('draft');icons();
  if(globalThis.Tweak){const tweak=new Tweak({container:root,onChange:renderShell});tweak.addSelect(state,'edge',{options:['top','left','right','bottom'],label:'Notch edge'});tweak.addToggle(state,'compact',{label:'Compact sidebar'});tweak.addToggle(state,'expanded',{label:'Expanded notch'});tweak.addColorPicker(state,'accent',{label:'Ember accent',reference:'--c-orange'});}
})();
