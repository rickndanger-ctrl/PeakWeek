import {API_BASE,ANON_KEY} from './config.js';
const $=id=>document.getElementById(id);
const STATE='peakweek-web-v1',PENDING='peakweek-invite-pending';
let state=null,selected=null,flushing=false;
try{state=JSON.parse(localStorage.getItem(STATE));}catch{}
const status=(text,error=false)=>{$('status').textContent=text;$('status').classList.toggle('error',error);};
function persist(){localStorage.setItem(STATE,JSON.stringify(state));}
function element(tag,text,className){const el=document.createElement(tag);if(text!=null)el.textContent=text;if(className)el.className=className;return el;}
function videoDB(){return new Promise((resolve,reject)=>{const r=indexedDB.open('peakweek-videos',1);r.onupgradeneeded=()=>r.result.createObjectStore('files');r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(new Error('This browser cannot save the video. Try Safari.'));});}
async function videoFile(id,value){const db=await videoDB();return new Promise((resolve,reject)=>{const tx=db.transaction('files',value===undefined?'readonly':'readwrite');const store=tx.objectStore('files');const request=value===undefined?store.get(id):value===null?store.delete(id):store.put(value,id);let result;request.onsuccess=()=>{result=request.result;};tx.oncomplete=()=>{db.close();resolve(result);};tx.onerror=()=>{db.close();reject(new Error('Could not save your video on this device.'));};});}
function randomSecret(){return Array.from(crypto.getRandomValues(new Uint8Array(32)),b=>b.toString(16).padStart(2,'0')).join('');}
async function api(route,body,token=state?.token){
 const headers={Authorization:'Bearer '+ANON_KEY,'Content-Type':'application/json'};if(token)headers['X-PW-Token']=token;
 const response=await fetch(API_BASE+'/'+route,{method:body?'POST':'GET',headers,body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(20000)});
 const data=await response.json();if(!response.ok){const error=new Error(response.status===401?'Your invitation has expired, was already used on another device, or your connection was removed. Ask your coach for a fresh invitation.':data.error||'Could not connect. Please try again.');error.status=response.status;throw error;}return data;
}
function render(){
 $('welcome').hidden=!!state;$('program').hidden=!state;$('refresh').hidden=!state;$('install').hidden=!state;
 if(!state)return;
 const root=$('program');root.replaceChildren(element('div',state.client.name,'eyebrow'));
 const w=state.week?.payload;
 if(!w){root.append(element('h1','Your program is on its way.'),element('p','You’re connected. Your coach will send your first week here.'));return;}
 root.append(element('h1','Week '+w.weekNum+' · '+w.phaseLabel),element('p',w.dateRange,'muted'));
 for(const day of w.days){const card=element('article',null,'day');card.append(element('h2',day.title));
  day.lines.forEach((line,index)=>{const row=element('div',null,'line');row.append(element('span',line));const slot=day.loggables.find(s=>s.slotIndex===index);if(slot){const button=element('button','Log result');button.onclick=()=>openLog(slot);row.append(button);}card.append(row);});root.append(card);
 }
 if(w.weekNote)root.append(element('p',w.weekNote));if(w.footer)root.append(element('p',w.footer,'muted'));
 showPending();
}
function showPending(){const n=state?.queue?.length||0;$('saved').hidden=!n;$('pending').textContent=n+' result'+(n===1?'':'s')+' saved here. Keep this device’s browser data; results will send when your connection returns.';}
function openLog(slot){selected=slot;$('exercise').textContent=slot.exerciseName;$('unit').textContent='('+state.client.unit+')';$('load').value=slot.load??'';$('reps').value=slot.reps;$('rpe').value='';$('note').value='';$('video').value='';$('log-error').textContent='';$('log').showModal();}
$('cancel').onclick=()=>$('log').close();
$('log-form').onsubmit=async event=>{
 event.preventDefault();if($('submit').disabled)return;$('submit').disabled=true;
 try{
  const w=state.week.payload;const body={id:crypto.randomUUID(),performed_at:new Date().toISOString(),lift:selected.lift,exercise_name:selected.exerciseName,load:Number($('load').value),unit:state.client.unit,reps:Number($('reps').value),week_num:w.weekNum,program_stamp:w.programStamp,note:$('note').value.trim(),has_video:false};
  if($('rpe').value)body.rpe=Number($('rpe').value);if(selected.pct!=null)body.prescribed_pct=selected.pct;if(selected.rpe!=null)body.prescribed_rpe=selected.rpe;
  const file=$('video').files[0];if(file){if(file.size>200*1024*1024)throw new Error('Choose a video under 200 MB.');await videoFile(body.id,file);body.has_video=true;}
  state.queue.push(body);try{persist();}catch{state.queue.pop();throw new Error('This browser cannot save your result. Please allow browser storage or try Safari.');}
  $('log').close();showPending();status('Result saved on this device. Sending to your coach…');await flush();await loadHistory();
 }catch(error){$('log-error').textContent=error.message;}finally{$('submit').disabled=false;}
};
async function flush(){
 if(flushing||!state)return;flushing=true;
 try{while(state.queue.length){const body=state.queue[0];const result=await api('submissions',body);
   if(body.has_video){const file=await videoFile(body.id);if(!file)throw new Error('The saved video is missing. Keep this result on this device and contact your coach.');if(!result.upload)throw new Error('Video upload is unavailable. Your result and video remain saved.');status('Uploading your video. Keep Peak Week open…');const response=await fetch(result.upload.url,{method:'PUT',headers:{'Content-Type':file.type||'video/mp4'},body:file});if(!response.ok)throw new Error('Video upload did not finish.');await api('submissions/video-done',{id:body.id});await videoFile(body.id,null);}
   state.queue.shift();persist();}showPending();status('Connected to your coach. Your results are up to date.');}
 catch(error){showPending();status(error.status===401?error.message:'Offline or unable to connect. Your result is saved and will retry.',true);}finally{flushing=false;}
}
async function loadHistory(){
 try{const data=await api('submissions/mine');state.history=data.submissions;persist();}catch{}
 $('history').hidden=!state?.history?.length;$('results').replaceChildren();
 for(const row of state?.history||[]){const el=element('div',row.lift.toUpperCase()+' · '+row.load+' '+row.unit+' × '+row.reps+(row.rpe?' @ RPE '+row.rpe:''),'result');el.append(element('small',new Date(row.performed_at).toLocaleDateString()));$('results').append(el);}
}
async function refresh(){
 if(!state)return;$('refresh').disabled=true;
 try{const data=await api('week');state.week=data.week;persist();render();await flush();await loadHistory();}
 catch(error){render();status(error.status===401?error.message:'You’re offline. Showing your last saved program. Tap Refresh when you’re connected.',true);}finally{$('refresh').disabled=false;}
}
async function connect(){
 const raw=new URLSearchParams(location.hash.slice(1)).get('invite');
 if(raw){
  if(!/^[A-F0-9]{64}$/i.test(raw)){status('This invitation is incomplete. Ask your coach to resend the full link.',true);render();return;}
  let pending;try{pending=JSON.parse(localStorage.getItem(PENDING));}catch{}
  if(!pending||pending.invite!==raw.toUpperCase())pending={invite:raw.toUpperCase(),secret:randomSecret()};
  try{
   localStorage.setItem(PENDING,JSON.stringify(pending));
   if(state?.acceptedInvite===pending.invite){history.replaceState(null,'',location.pathname);localStorage.removeItem(PENDING);await refresh();return;}
   if(state?.queue?.length){status('Send your saved results before opening a different invitation. Your existing program is still here.',true);render();return;}
   if(state && !confirm('Connect this device to the new coach invitation? Your existing program will be replaced on this device.')){render();return;}
   status('Connecting your program…');const result=await api('pair',{code:pending.invite,connectionSecret:pending.secret,deviceName:'Peak Week web'},null);
   const next={token:result.token,client:result.client,acceptedInvite:pending.invite,queue:[],history:[],week:null};
   localStorage.setItem(STATE,JSON.stringify(next));state=next;localStorage.removeItem(PENDING);history.replaceState(null,'',location.pathname);await refresh();
  }catch(error){render();status(error.message||'Could not connect. Open your invitation again to retry.',true);}
 }else if(state){render();await refresh();}else{render();status('Welcome to Peak Week.');}
}
$('refresh').onclick=refresh;window.addEventListener('online',refresh);
if('serviceWorker'in navigator)navigator.serviceWorker.register('./sw.js').catch(()=>{});
connect();
