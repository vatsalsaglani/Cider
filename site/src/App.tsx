import { useEffect, useState } from 'react'
import { ArrowUpRight, ArrowRight, Download, Github, Command, Check, FileText, GitBranch, Activity, ChevronDown, Menu, X, Music2, CircleCheck, Sparkles } from 'lucide-react'
import { Docs } from './Docs'
export const repo = 'https://github.com/vatsalsaglani/Cider'
export const asset = (name: string) => `${import.meta.env.BASE_URL}images/${name}`
const previews = [
  { name: 'Agents', image: 'notch-agents.png', icon: Activity, line: 'Know when to step in. Keep going when you don’t.' },
  { name: 'TODO', image: 'notch-todo.png', icon: CircleCheck, line: 'Catch the next thing before it slips away.' },
  { name: 'Now Playing', image: 'notch-music.png', icon: Music2, line: 'A little rhythm. Without leaving your flow.' },
  { name: 'Usage', image: 'notch-usage.png', icon: Sparkles, line: 'See what’s left. Make room for what’s next.' },
]
export default function App() {
  const [hash, setHash] = useState(location.hash)
  const [menu, setMenu] = useState(false)
  useEffect(() => { const update = () => { setHash(location.hash); setMenu(false); window.scrollTo(0,0) }; window.addEventListener('hashchange', update); return () => window.removeEventListener('hashchange', update) }, [])
  useEffect(() => {
    const observer = new IntersectionObserver(entries => entries.forEach(e => { if (e.isIntersecting) { e.target.classList.add('in-view'); observer.unobserve(e.target) } }), { threshold: .12 })
    document.querySelectorAll('.reveal').forEach(el => observer.observe(el)); return () => observer.disconnect()
  }, [hash])
  const docs = hash.startsWith('#/docs')
  return <><a href="#main" className="skip-link" onClick={e=>{e.preventDefault();document.getElementById("main")?.focus()}}>Skip to content</a><div className="ambient" aria-hidden="true"><i/><i/><i/></div>
    <header className="site-header"><a className="brand" href="#/" aria-label="Cider home"><img src={asset('cider.png')} alt=""/>cider<span className="brand-dot">.</span></a>
      <nav className={menu ? 'nav-links open' : 'nav-links'} aria-label="Main navigation"><a href="#/docs/features">Features</a><a href="#/docs/getting-started">The guide</a><a href={repo} target="_blank" rel="noreferrer">GitHub <ArrowUpRight size={13}/></a></nav>
      <a className="button button-small" href={`${repo}/releases/latest`}>Get Cider <Download size={14}/></a><button className="mobile-menu" onClick={() => setMenu(!menu)} aria-label={menu ? 'Close navigation' : 'Open navigation'} aria-expanded={menu}>{menu ? <X/> : <Menu/>}</button>
    </header>
    <main id="main" tabIndex={-1}>{docs ? <Docs slug={hash.split('/')[2] || 'getting-started'}/> : <Home/>}</main>
    <footer className="footer"><a href="#/" className="brand"><img src={asset('cider.png')} alt=""/>cider.</a><p>A calmer corner of your Mac.</p><div><a href="#/docs/getting-started">Guide</a><a href={`${repo}/releases`}>Releases</a><a href={`${repo}/issues`}>Feedback <ArrowUpRight size={12}/></a></div><span>Made for the work in front of you.</span></footer>
  </>
}
function Home() {
  const [tab,setTab] = useState(0)
  return <>
    <section className="hero section-wrap"><div className="hero-copy"><p className="eyebrow"><span className="live-dot"/> YOUR WORK. A LITTLE CLOSER.</p><h1>Less switching.<br/>More <em>flow.</em></h1><p className="hero-description">Your agents are working. Your ideas keep coming.<br className="desktop-break"/> Cider keeps the next thing within reach.</p><div className="cta-row"><a className="button" href={`${repo}/releases/latest`}>Find your flow <Download size={17}/></a><a className="text-link" href="#/docs/getting-started">Meet your new sidekick <ArrowRight size={16}/></a></div><p className="availability"><Command size={12}/> Made for macOS 26+ <span>·</span> Early release</p></div>
      <div className="hero-scene" aria-label="A preview of Cider's agent activity notch"><div className="orbit orbit-one"/><div className="orbit orbit-two"/><div className="scene-glow"/><div className="floating-label"><span className="live-dot"/> A little heads-up. A lot less checking.</div><div className="notch-preview"><img src={asset('notch-agents.png')} alt="Cider's notch shows agent activity and recent responses" fetchPriority="high"/></div><div className="scene-caption"><span className="tiny-line"/> RIGHT THERE, WHEN YOU NEED IT.</div></div>
    </section>
    <section className="trust-strip section-wrap"><span>Room for the way you work.</span><div><Command size={17}/> Codex</div><div><Sparkles size={17}/> Claude Code</div><div><ArrowUpRight size={17}/> Cursor</div><a href="#/docs/agents">See connections <ArrowRight size={14}/></a></section>
    <section className="intro section-wrap reveal"><p className="eyebrow">PICK UP WHERE YOUR MIND LEFT OFF</p><h2>Big ideas.<br/><span>Fewer loose ends.</span></h2><p>The task in one window. The plan in another. An agent waiting somewhere else. Bring the pieces together, and stay with the work that matters.</p></section>
    <section className="feature-grid section-wrap">
      <article className="feature-note reveal"><div className="feature-heading"><span className="feature-number">01 / KEEP IT TOGETHER</span><FileText size={22}/></div><h3>A thought becomes a plan.<br/>A plan stays with its task.</h3><p>Write freely. Link your notes to the work they belong to. Come back with the context already there.</p><a className="text-link" href="#/docs/notes">Give your ideas a home <ArrowUpRight size={15}/></a><div className="screenshot-window"><img loading="lazy" src={asset('notes.png')} alt="Cider notes workspace with folders, document tabs and a Markdown plan"/></div></article>
      <article className="feature-task reveal"><div className="feature-heading"><span className="feature-number">02 / MAKE TODAY LIGHTER</span><CircleCheck size={22}/></div><h3>A little less<br/>on your mind.</h3><p>Capture a task in a moment. Give it a day, a plan, and a clear finish line.</p><div className="task-demo" aria-label="Illustrative task checklist"><div><span className="check-circle done"><Check size={12}/></span><s>Get the idea down</s><span className="tag">Done</span></div><div><span className="check-circle"/>Shape the next step<span className="tag warm">Today</span></div><div className="demo-note"><FileText size={14}/><span>Launch notes</span><span>↗</span></div><div className="task-add">＋ A little room to breathe.</div></div><a className="text-link" href="#/docs/tasks">Make space for what’s next <ArrowUpRight size={15}/></a></article>
    </section>
    <section className="notch-section section-wrap reveal"><div className="notch-copy"><p className="eyebrow">SMALL SPACE. GOOD COMPANY.</p><h2>Your Mac has<br/>a new <em>sweet spot.</em></h2><p>A glance for your agents. A place for your tasks. Your music, your limits, your next move. All tucked into the notch.</p><div className="preview-tabs" role="tablist" aria-label="Explore the notch">{previews.map((p,i)=><button id={`tab-${i}`} aria-controls="notch-panel" role="tab" aria-selected={i===tab} className={i===tab?'selected':''} key={p.name} onClick={()=>setTab(i)}><p.icon size={16}/>{p.name}<ArrowRight size={14}/></button>)}</div><a className="text-link" href="#/docs/notch">Get to know the notch <ArrowUpRight size={15}/></a></div><div className="notch-display" id="notch-panel" role="tabpanel" aria-labelledby={`tab-${tab}`}><div className="warm-halo"/><img key={tab} className="tab-image" loading="lazy" src={asset(previews[tab].image)} alt={`Cider ${previews[tab].name} notch panel`}/><p aria-live="polite">{previews[tab].line}</p></div></section>
    <section className="connections section-wrap reveal"><div><p className="eyebrow">THE THREAD THROUGH YOUR WORK</p><h2>See how it<br/><span>all connects.</span></h2><p>Notes, tasks, and conversations don’t happen in isolation. Follow their connections and find your way back to the bigger picture.</p><a className="text-link" href="#/docs/features">Explore your workspace <ArrowUpRight size={15}/></a></div><div className="graph-shot"><img loading="lazy" src={asset('graph.png')} alt="Cider graph showing connections between notes and work"/></div></section>
    <section className="values section-wrap reveal"><div><span>01</span><h3>Your notes, yours.</h3><p>Ordinary Markdown files in folders you choose. Keep using them outside Cider.</p></div><div><span>02</span><h3>A nudge, not a distraction.</h3><p>Spot who’s working and who needs you. Return to the conversation when you’re ready.</p></div><div><span>03</span><h3>Your pace. Your place.</h3><p>Keep an eye on usage, plan the next task, and let your day find its rhythm.</p></div></section>
    <section className="faq section-wrap reveal"><div><p className="eyebrow">A FEW GOOD QUESTIONS</p><h2>Before you<br/>settle in.</h2></div><div>{[
      ['What do I need to run Cider?','A Mac running macOS 26 or later. The first release is for Apple Silicon. Check the release notes for installation details and the latest requirements.'],
      ['Does Cider run my agents?','Cider brings their activity into view. You keep working in Codex, Claude Code, or Cursor. Optional Cider plugins let supported agents work with the tasks and notes you request.'],
      ['Where do my notes live?','In local folders you choose. New notes use your Documents/Cider folder by default. Your Markdown files remain usable in other editors.'],
      ['Is this an early release?','Yes. Cider is still growing. The first builds are not Apple-notarized; the release notes explain what to expect. Feedback and bug reports are welcome on GitHub.']
    ].map(([q,a])=><details key={q}><summary>{q}<ChevronDown size={17}/></summary><p>{a}</p></details>)}</div></section>
    <section className="final-cta section-wrap reveal"><img src={asset('cider.png')} alt="Cider's folded-note companion" loading="lazy"/><p className="eyebrow">A FRESH START, ONE SMALL STEP AWAY</p><h2>Stay with<br/><em>your work.</em></h2><p>Less hunting for context. More room to make something.</p><a className="button" href={`${repo}/releases/latest`}>Make room for Cider <Download size={17}/></a><a href={repo} className="source-link"><Github size={14}/> Follow along on GitHub</a></section>
  </>
}
