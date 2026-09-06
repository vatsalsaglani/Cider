/* Shared task components used by the workspace, toolbar capture, and HUD. */
function createCiderTasks(root, options) {
  const q=s=>root.querySelector(s), qa=s=>Array.from(root.querySelectorAll(s));
  const dayKey=d=>[d.getFullYear(),String(d.getMonth()+1).padStart(2,'0'),String(d.getDate()).padStart(2,'0')].join('-');
  const dayDate=k=>{const p=k.split('-').map(Number);return new Date(p[0],p[1]-1,p[2],12);};
  const shift=(key,n)=>{const d=dayDate(key);d.setDate(d.getDate()+n);return dayKey(d);};
  const fmt=(key,opts)=>dayDate(key).toLocaleDateString('en-US',opts);
  const today='2026-09-06';
  const state={day:today,month:today,view:'list',editing:null};
  let nextID=8;
  const items=[
    {id:1,title:'Review the stream experience',project:'Agent workspace',tag:'Review',date:today,done:false},
    {id:2,title:'Decide how interrupted work resumes',project:'Session engine',tag:'Decision',date:today,done:false},
    {id:3,title:'Check repeated events after a timeout',project:'Trace pipeline',tag:'Issue',date:today,done:false},
    {id:4,title:'Write down the next phase',project:'Agent workspace',tag:'Planning',date:today,done:true},
    {id:5,title:'Test the revised empty state',project:'Agent workspace',tag:'Review',date:shift(today,1),done:false},
    {id:6,title:'Clear a little space for deep work',project:'Personal',tag:'Focus',date:shift(today,2),done:false},
    {id:7,title:'Review this week’s progress',project:'Personal',tag:'Review',date:shift(today,5),done:false}
  ];
  const drafts={day:'',quick:'',hud:''};
  function node(tag,cls,text){const e=document.createElement(tag);if(cls)e.className=cls;if(text!==undefined)e.textContent=text;return e;}
  function IconButton(icon,label,action,kind='c-quiet') {
    const b=node('button','c-button c-icon-button '+kind);b.type='button';b.setAttribute('aria-label',label);b.dataset.tooltip=label;
    const i=node('i');i.dataset.lucide=icon;i.setAttribute('aria-hidden','true');b.append(i);if(action)b.addEventListener('click',action);return b;
  }
  function changed(){render();options.changed();}
  function createTask(title,date,project='Personal',tag='Task'){
    if(!title.trim())return;items.push({id:nextID++,title:title.trim(),project,tag,date,done:false});changed();options.announce('Added to '+(date===today?'Today':fmt(date,{month:'short',day:'numeric'})));
  }
  function TaskComposer(context,dateProvider,placeholder){
    const wrap=node('div','c-composer');const glyph=node('i');glyph.dataset.lucide='plus';glyph.setAttribute('aria-hidden','true');
    const input=node('input');input.type='text';input.placeholder=placeholder;input.autocomplete='off';input.id='c-'+context+'-task-input';input.value=drafts[context];input.setAttribute('aria-label',context==='hud'?'New task in notch':context==='quick'?'Quick task title':'New task for selected day');
    input.addEventListener('input',()=>{drafts[context]=input.value;});
    const submit=()=>{const value=input.value.trim();if(!value)return;drafts[context]='';input.value='';createTask(value,dateProvider());root.querySelector('#c-'+context+'-task-input')?.focus();};
    input.addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();submit();}});
    const add=IconButton('arrow-up','Add task',submit,'c-primary');add.id='c-'+context+'-task-add';wrap.append(glyph,input,add);return wrap;
  }
  function DateNavigator(compact){
    const wrap=node('div','c-date-controls');wrap.style.display='contents';
    const prev=IconButton('chevron-left','Previous day',()=>selectDay(shift(state.day,-1)));
    const label=node('span','c-date-label',fmt(state.day,{month:'short',day:'numeric'}));
    const next=IconButton('chevron-right','Next day',()=>selectDay(shift(state.day,1)));
    const reset=IconButton('rotate-ccw','Return to today',()=>selectDay(today));
    wrap.append(prev,label,next,reset);return wrap;
  }
  function selectDay(key){state.day=key;state.month=key;state.editing=null;q('#c-task-detail').hidden=true;options.openDay();render();options.announce(fmt(key,{weekday:'long',month:'long',day:'numeric'}));}
  function DayDots(day){const dots=node('span','c-day-dots');dots.setAttribute('aria-hidden','true');items.filter(t=>t.date===day&&!t.done).slice(0,3).forEach(()=>dots.append(node('i')));return dots;}
  function WeekStrip(){
    const container=q('#c-week-strip');container.replaceChildren();const start=shift(state.day,-dayDate(state.day).getDay());
    for(let i=0;i<7;i++){const key=shift(start,i);const button=node('button','c-week-day');button.dataset.day=key;button.setAttribute('aria-pressed',String(key===state.day));button.setAttribute('aria-label',fmt(key,{weekday:'long',month:'long',day:'numeric'}));button.append(node('span','c-small',fmt(key,{weekday:'short'})),node('span','c-week-number',String(dayDate(key).getDate())),DayDots(key));button.addEventListener('click',()=>selectDay(key));container.append(button);}
  }
  function MonthCalendar(){
    const month=dayDate(state.month);month.setDate(1);const first=dayKey(month);q('#c-month-title').textContent=fmt(first,{month:'long',year:'numeric'});
    const start=shift(first,-month.getDay()),grid=q('#c-month-grid');grid.replaceChildren();
    for(let i=0;i<42;i++){
      const key=shift(start,i),date=dayDate(key),tasks=items.filter(t=>t.date===key&&!t.done);const button=node('button','c-calendar-day'+(date.getMonth()!==month.getMonth()?' is-outside':'')+(key===today?' is-today':''));button.dataset.calendarDay=key;button.setAttribute('aria-pressed',String(key===state.day));button.setAttribute('aria-label',fmt(key,{month:'long',day:'numeric'})+', '+tasks.length+' tasks');button.append(node('span','c-calendar-number',String(date.getDate())));
      tasks.slice(0,1).forEach(t=>button.append(node('span','c-calendar-task',t.title)));if(tasks.length)button.append(DayDots(key));if(tasks.length>1)button.append(node('span','c-calendar-more','+'+(tasks.length-1)));
      button.addEventListener('click',()=>selectDay(key));grid.append(button);
    }
  }
  function TaskRow(task){
    const row=node('div','c-task-row'+(task.done?' is-done':''));row.dataset.taskId=task.id;
    const check=node('input','c-task-check');check.type='checkbox';check.checked=task.done;check.setAttribute('aria-label',(task.done?'Reopen ':'Complete ')+task.title);check.addEventListener('change',()=>{task.done=check.checked;changed();options.announce(task.done?'Task completed':'Task reopened');});
    const content=node('button','c-task-content');content.type='button';content.setAttribute('aria-label','Edit '+task.title);const title=node('div','c-task-title',task.title);const meta=node('div','c-task-meta');const icon=node('i');icon.dataset.lucide=task.project==='Personal'?'circle':'folder';icon.setAttribute('aria-hidden','true');meta.append(icon,node('span','',task.project),node('span','c-task-tag',task.tag));content.append(title,meta);content.addEventListener('click',()=>openEditor(task));
    const more=IconButton('ellipsis','Edit '+task.title,()=>openEditor(task));row.append(check,content,more);return row;
  }
  function openEditor(task){
    state.editing=task.id;const host=q('#c-task-detail');host.hidden=false;host.replaceChildren();const head=node('div','c-capture-heading');head.append(node('span','','Edit task'),IconButton('x','Close task details',()=>{host.hidden=true;state.editing=null;}));
    const title=node('input','c-input');title.value=task.title;title.setAttribute('aria-label','Task title');const label=node('label','c-capture-date','Planned for');const date=node('input','c-input');date.type='date';date.value=task.date;date.setAttribute('aria-label','Task planned date');label.append(date);const actions=node('div','c-task-detail-actions');actions.append(IconButton('check','Save task',()=>{if(!title.value.trim()||!date.value)return;task.title=title.value.trim();task.date=date.value;host.hidden=true;state.editing=null;changed();options.announce('Task updated');},'c-primary'));host.append(head,title,label,actions);options.icons();title.focus();
  }
  function render(){
    const dayItems=items.filter(t=>t.date===state.day),todo=dayItems.filter(t=>!t.done),done=dayItems.filter(t=>t.done);
    const relative=state.day===today?'Today':state.day===shift(today,1)?'Tomorrow':state.day===shift(today,-1)?'Yesterday':'Your day';
    q('#c-day-relative').textContent=relative;q('#c-day-title').textContent=fmt(state.day,{weekday:'long',month:'long',day:'numeric'});q('#c-task-count').textContent=todo.length+' to do'+(done.length?' · '+done.length+' completed':'');
    q('#c-sidebar-date').replaceChildren(DateNavigator(true));q('#c-inline-date').replaceChildren(DateNavigator(false));WeekStrip();MonthCalendar();
    q('#c-week-strip').hidden=state.view!=='list';q('#c-month-view').hidden=state.view!=='calendar';qa('[data-task-view]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.taskView===state.view)));
    q('#c-day-composer').replaceChildren(TaskComposer('day',()=>state.day,'Add something to this day…'));
    const host=q('#c-tasks');host.replaceChildren();const heading=node('div','c-task-section-title',state.view==='calendar'?fmt(state.day,{month:'short',day:'numeric'}):'To do');heading.append(node('span','c-total',String(todo.length)));host.append(heading);
    if(todo.length)todo.forEach(task=>host.append(TaskRow(task)));else{const empty=node('div','c-empty-day','A little breathing room.');empty.append(node('p','','Add a task whenever you’re ready.'));host.append(empty);}
    if(done.length){const completed=node('details','c-completed');completed.open=true;completed.append(node('summary','',done.length+' completed'));done.forEach(task=>completed.append(TaskRow(task)));host.append(completed);}
    options.icons();
  }
  function renderHUD(host){
    host.replaceChildren();const todo=items.filter(t=>t.date===today&&!t.done);
    todo.slice(0,3).forEach(task=>{const row=node('label','c-hud-task');const check=node('input','c-task-check');check.type='checkbox';check.setAttribute('aria-label','Complete '+task.title+' in notch');check.addEventListener('change',()=>{task.done=check.checked;changed();options.announce('Task completed');});row.append(check,node('span','',task.title));host.append(row);});
    if(!todo.length)host.append(node('p','c-small c-muted','Everything on your list is done.'));
    const compose=node('div','c-hud-composer');compose.append(TaskComposer('hud',()=>today,'Add a task for today…'));host.append(compose);q('#c-hud-day-label').textContent=todo.length+' to do';options.icons();
  }
  function quickCapture(){
    const host=q('#c-quick-capture');if(!host.hidden){host.hidden=true;return;}host.hidden=false;host.replaceChildren();
    const heading=node('div','c-capture-heading');heading.append(node('span','','New task'),IconButton('x','Close quick task',()=>{host.hidden=true;}));
    const label=node('label','c-capture-date','Planned for'),date=node('input','c-input');date.type='date';date.value=options.isDayView()?state.day:today;date.setAttribute('aria-label','Quick task date');label.append(date);host.append(heading,TaskComposer('quick',()=>date.value||today,'What’s on your mind?'),label);options.icons();q('#c-quick-task-input').focus();
  }
  root.addEventListener('click',event=>{
    const b=event.target.closest('button');if(!b)return;
    if(b.dataset.taskView){state.view=b.dataset.taskView;state.month=state.day;render();}
    if(b.dataset.monthShift){const d=dayDate(state.month);d.setDate(1);d.setMonth(d.getMonth()+Number(b.dataset.monthShift));state.month=dayKey(d);MonthCalendar();options.icons();}
    if(b.dataset.action==='quick-task')quickCapture();
    if(b.dataset.action==='focus-task'){state.view='list';render();q('#c-day-task-input').focus();}
  });
  return {render,renderHUD,selectDay,quickCapture,IconButton,addFinding(title,project){createTask(title,state.day,project,'Finding');},focusHUD(){q('#c-hud-task-input')?.focus();},closeCapture(){q('#c-quick-capture').hidden=true;q('#c-task-detail').hidden=true;},day:()=>state.day};
}
