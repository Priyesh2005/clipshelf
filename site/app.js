const reduced = matchMedia('(prefers-reduced-motion: reduce)');
const sentence = document.querySelector('.reveal-sentence');
const words = sentence.textContent.trim().split(/\s+/);
sentence.replaceChildren(...words.flatMap((word, i) => { const span=document.createElement('span'); span.textContent=word; return i ? [document.createTextNode(' '),span] : [span]; }));
const spans = [...sentence.querySelectorAll('span')];
const hero = document.querySelector('.hero-screen');
const cards = [...document.querySelectorAll('.product-card')];
const nav = document.querySelector('.nav-pill');
const menu = document.querySelector('.menu-toggle');
menu.addEventListener('click', () => { const open=nav.classList.toggle('menu-open'); menu.setAttribute('aria-expanded',String(open)); menu.setAttribute('aria-label',open?'Close menu':'Open menu'); });
nav.querySelectorAll('a').forEach(a=>a.addEventListener('click',()=>{nav.classList.remove('menu-open');menu.setAttribute('aria-expanded','false');menu.setAttribute('aria-label','Open menu');}));
document.addEventListener('keydown',e=>{if(e.key==='Escape'){nav.classList.remove('menu-open');menu.setAttribute('aria-expanded','false');}});
const image=document.querySelector('#workflow-image');
const steps=[...document.querySelectorAll('.workflow-step')];
let active=0,scheduled=false;
const clamp=(n,min,max)=>Math.min(max,Math.max(min,n));
function updateScroll(){
  scheduled=false;
  document.body.classList.toggle('scrolled',scrollY>60);
  const rect=sentence.getBoundingClientRect();
  const progress=clamp((innerHeight*.85-rect.top)/(rect.height+innerHeight*.25),0,1);
  spans.forEach((s,i)=>s.classList.toggle('read',reduced.matches||i/spans.length<=progress));
  if(!reduced.matches){
    const y=clamp(scrollY,0,850);
    hero.style.transform=`translateY(${y*.035}px) rotateX(${Math.max(0,7-y*.02)}deg) rotate(${-3+y*.003}deg)`;
    cards.forEach((card,i)=>{const r=card.getBoundingClientRect();const p=clamp((innerHeight-r.top)/innerHeight,0,1);card.style.transform=`translateY(${(1-p)*35}px) rotate(${(i===0?-1:1)*(7-p*4)}deg)`;});
  }
  let next=0;
  steps.forEach((s,i)=>{if(s.getBoundingClientRect().top<innerHeight*.62)next=i;});
  if(next!==active){active=next; steps.forEach((s,i)=>s.classList.toggle('is-active',i===next)); image.src=next===1?'/assets/app-search.png':'/assets/app-history.png'; image.alt=next===1?'Actual ClipShelf search showing the matching Launch checklist':'Actual ClipShelf window showing recent sample text'; document.querySelector('#step-label').textContent=['01 / COPY','02 / FIND','03 / CARRY ON'][next];}
}
addEventListener('scroll',()=>{if(!scheduled){scheduled=true;requestAnimationFrame(updateScroll);}},{passive:true});
addEventListener('resize',updateScroll); reduced.addEventListener('change',()=>{if(reduced.matches){hero.style.transform='';cards.forEach(c=>c.style.transform='');}updateScroll();});updateScroll();
const word=document.querySelector('#rotating-word');const cycle=['words','links','notes','ideas'];let wordIndex=0;
if(!reduced.matches){setInterval(()=>{if(document.hidden||reduced.matches)return;word.classList.add('changing');setTimeout(()=>{word.textContent=cycle[++wordIndex%cycle.length];word.classList.remove('changing');},200);},2700);}
const observer=new IntersectionObserver(entries=>entries.forEach(e=>{if(e.isIntersecting){e.target.classList.add('visible');observer.unobserve(e.target);}}),{threshold:.1});
document.querySelectorAll('.section-heading,.privacy-row,.install-card').forEach(e=>{e.classList.add('reveal-in');observer.observe(e);});
document.querySelector('#copy-command').addEventListener('click',async()=>{const status=document.querySelector('#copy-status');try{await navigator.clipboard.writeText(document.querySelector('#install-command').textContent);status.textContent='Copied. Review the installer, then paste into Terminal.';}catch{status.textContent='Copy blocked by your browser. Select and copy the command above.';}});
document.querySelectorAll('a[href="#install-help"]').forEach(a=>a.addEventListener('click',()=>{document.querySelector('#install-help').open=true;}));
if(location.hash==='#install-help')document.querySelector('#install-help').open=true;
