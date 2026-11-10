(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.PeakWeekRedirect=api;})(typeof globalThis!=='undefined'?globalThis:this,function(){
'use strict';
const key='peakweek.private.apple.transaction.v1';
const hex64=/^[a-f0-9]{64}$/;
const statePattern=/^[A-Za-z0-9_-]{32,256}$/;
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const origin='https://rickndanger-ctrl.github.io';
const callback=origin+'/PeakWeek/apple-first-preview/callback.html';
const messages={
 storage_unavailable:'Safari could not save this temporary setup. Allow website storage, then try again. No connection was changed.',
 missing_context:'This tab has no saved setup to finish. Start from your coach’s invitation in this Safari tab.',
 expired:'This setup has expired. Open your coach’s invitation to start again.',
 wrong_state:'This Apple response does not match the setup in this tab. Nothing was connected.',
 invalid_callback:'Apple’s return could not be verified. Nothing was connected.',
 cancelled:'Apple sign-in was cancelled. You can continue when you’re ready.',
 unauthorized:'Apple verification did not finish. Please try again.',
 invitation_unavailable:'This invitation is no longer available. Ask your coach for a new one.',
 private_test_only:'This private setup is only available to the invited test account.',
 other_account:'Use the Apple account already connected to this training.',
 account_deletion_pending:'Account removal is still finishing. Please wait before starting again.',
 unavailable:'This private setup option is not available yet.',
 processing:'The connection is still being checked. Check its status before starting again.',
 restart_required:'Continue with Apple again to finish this saved setup.',
 confirmation_required:'Confirm account deletion before continuing with Apple.',
 network:'The result is not confirmed yet. Check setup status to see whether it finished.',
 invalid_reply:'The server did not confirm this setup. Check its status before trying again.',
};
function explanation(error){return messages[error?.code]||messages.network;}
function parseCallback(search){
 const p=new URLSearchParams(String(search).replace(/^\?/,''));
 if(!p.toString())return {kind:'none'};
 const state=p.get('state');
 if(p.getAll('state').length!==1||!statePattern.test(state||''))return {kind:'invalid'};
 if(p.has('id_token')||p.has('access_token')||p.has('refresh_token'))return {kind:'invalid'};
 if(p.getAll('code').length===1&&!p.has('error')){
  const code=p.get('code');return code&&code.length<=4096?{kind:'code',state,code}:{kind:'invalid'};
 }
 if(p.getAll('error').length===1&&!p.has('code'))return {kind:'error',state,error:['user_cancelled_authorize','access_denied'].includes(p.get('error'))?'cancelled':'unauthorized'};
 return {kind:'invalid'};
}
function createStore(storage,now=()=>Date.now()){
 function probe(){try{const probeKey=key+'.probe';storage.setItem(probeKey,'1');if(storage.getItem(probeKey)!=='1')throw Error();storage.removeItem(probeKey);}catch(_){throw {code:'storage_unavailable'};}}
 function clear(){try{storage.removeItem(key);}catch(_){throw {code:'storage_unavailable'};}}
 function clean(record){
  if(!record||!['claim','manage','delete'].includes(record.operation)||!statePattern.test(record.state||'')||!hex64.test(record.browser_secret||'')||!hex64.test(record.raw_nonce||'')||!Number.isFinite(Date.parse(record.expires_at)))throw {code:'missing_context'};
  if(Date.parse(record.expires_at)<=now())throw {code:'expired'};
  return {version:1,operation:record.operation,state:record.state,browser_secret:record.browser_secret,raw_nonce:record.raw_nonce,expires_at:record.expires_at};
 }
 return {probe,clear,
  save(record){const safe=clean(record);probe();try{storage.setItem(key,JSON.stringify(safe));}catch(_){throw {code:'storage_unavailable'};}return safe;},
  load(){let value;try{value=storage.getItem(key);}catch(_){throw {code:'storage_unavailable'};}if(!value)return null;
   try{return clean(JSON.parse(value));}catch(error){clear();throw error?.code?error:{code:'missing_context'};}
  },
 };
}
function createClient({config,pageOrigin,storage,fetcher,navigate,onStage=()=>{},cryptoImpl=globalThis.crypto,now=()=>Date.now(),sleep=ms=>new Promise(r=>setTimeout(r,ms)),pollAttempts=6,pollDelay=1500,requestTimeout=15000}){
 if(config?.enabled!==true||config.clientId!=='com.peakweek.lifter.web'||config.pageOrigin!==origin||pageOrigin!==origin||config.redirectURI!==callback||config.supabaseOrigin!=='https://otgsdsvswiehymubkyki.supabase.co')throw {code:'unavailable'};
 const store=createStore(storage,now),base=config.supabaseOrigin+'/functions/v1/peakweek-native-api/onboarding/apple/';
 let busy=false;
 const hex=bytes=>Array.from(bytes,x=>x.toString(16).padStart(2,'0')).join('');
 const random=()=>hex(cryptoImpl.getRandomValues(new Uint8Array(32)));
 const hash=async value=>hex(new Uint8Array(await cryptoImpl.subtle.digest('SHA-256',new TextEncoder().encode(value))));
 async function request(route,body,timeout=requestTimeout){
  const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),timeout);
  try{
   const response=await fetcher(base+route,{method:'POST',credentials:'omit',cache:'no-store',redirect:'error',referrerPolicy:'no-referrer',signal:controller.signal,headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
   const data=await response.json().catch(()=>({}));
   if(!response.ok){
    const code=typeof data.code==='string'?data.code:response.status===404?'unavailable':response.status===401?'unauthorized':'network';
    if(code==='setup_expired'){store.clear();throw {code:'expired'};}
    throw {code};
   }
   return data;
  }catch(error){throw error?.code?error:{code:'network'};}finally{clearTimeout(timer);}
 }
 function context(){const saved=store.load();if(!saved)throw {code:'missing_context'};return saved;}
 function validateStart(reply,proofs,operation){
  const url=new URL(reply.authorization_url);
  const p=url.searchParams;
  const expected={client_id:config.clientId,redirect_uri:callback,response_type:'code',response_mode:'query',state:reply.state,nonce:proofs.nonce_hash};
  if(url.origin!=='https://appleid.apple.com'||url.pathname!=='/auth/authorize'||url.hash||url.username||url.password||!statePattern.test(reply.state||'')||p.has('scope')||Object.keys(expected).some(k=>p.getAll(k).length!==1||p.get(k)!==expected[k])||Array.from(p.keys()).some(k=>!Object.hasOwn(expected,k)))throw {code:'invalid_reply'};
  const expires=Date.parse(reply.expires_at);
  if(!Number.isFinite(expires)||expires<=now()||expires>now()+15*60*1000)throw {code:'invalid_reply'};
  return {record:{operation,state:reply.state,browser_secret:proofs.browser_secret,raw_nonce:proofs.raw_nonce,expires_at:reply.expires_at},url:url.href};
 }
 function completed(reply,saved){
  const r=reply.receipt;
  if(reply.status!=='complete'||r?.ok!==true)throw {code:'invalid_reply'};
  if(saved.operation==='claim'&&(!uuid.test(r.workspace_id)||!uuid.test(r.client_id)))throw {code:'invalid_reply'};
  if(saved.operation==='manage'&&(!Array.isArray(r.profiles)||r.profiles.some(p=>typeof p.name!=='string')))throw {code:'invalid_reply'};
  if(saved.operation==='delete'&&r.deleted!==true)throw {code:'invalid_reply'};
  return {phase:'complete',operation:saved.operation,receipt:r};
 }
 async function status(saved,timeout){return request('status',{state:saved.state,browser_secret:saved.browser_secret},timeout);}
 async function settle(reply,saved){
  const deadline=now()+20000;
  for(let attempt=0;attempt<pollAttempts;attempt++){
   if(reply.status==='complete')return completed(reply,saved);
   if(reply.status==='pending'||reply.status==='restart_required')return {phase:'restart_required',operation:saved.operation};
   if(reply.status!=='processing')throw {code:'invalid_reply'};
   onStage('checking');
   if(attempt===pollAttempts-1)return {phase:'processing',operation:saved.operation};
   if(now()+pollDelay>=deadline)return {phase:'processing',operation:saved.operation};
   await sleep(pollDelay);reply=await status(saved,Math.max(1,Math.min(requestTimeout,deadline-now())));
  }
 }
 async function exclusive(work){if(busy)return {phase:'busy'};busy=true;try{return await work();}finally{busy=false;}}
 async function start(operation,invitation,restarting=false,confirmation=false){
  return exclusive(async()=>{
   store.probe();
   const old=restarting||operation==='delete'?context():null;
   if(operation==='delete'&&(!confirmation||old?.operation!=='manage'&&!restarting))throw {code:'confirmation_required'};
   if(operation==='claim'&&!restarting&&!/^[A-Fa-f0-9]{64}$/.test(invitation||''))throw {code:'invitation_unavailable'};
   onStage('preparing');
   const proofs={browser_secret:random(),raw_nonce:random()};
   proofs.browser_hash=await hash(proofs.browser_secret);proofs.nonce_hash=await hash(proofs.raw_nonce);
   let body={operation,browser_hash:proofs.browser_hash,nonce_hash:proofs.nonce_hash};
   if(restarting)body={state:old.state,browser_secret:old.browser_secret,browser_hash:proofs.browser_hash,nonce_hash:proofs.nonce_hash};
   else if(operation==='claim')body.invitation=invitation;
   else if(operation==='delete')Object.assign(body,{confirmation:'DELETE',management_state:old.state,management_browser_secret:old.browser_secret});
   const reply=await request(restarting?'restart':'start',body);
   const next=validateStart(reply,proofs,operation);store.save(next.record);
   onStage('opening_apple');navigate(next.url);return {phase:'redirecting',operation};
  });
 }
 return {store,
  startClaim:invitation=>start('claim',invitation),
  startManage:()=>start('manage'),
  startDeletion:confirmed=>start('delete',null,false,confirmed),
  restart(confirmed=false){const saved=context();if(saved.operation==='delete'&&!confirmed)return Promise.reject({code:'confirmation_required'});return start(saved.operation,null,true,confirmed);},
  resume(){return exclusive(async()=>{onStage('checking');const saved=context();return settle(await status(saved),saved);});},
  finish(returned){return exclusive(async()=>{
   const saved=context();if(returned.kind==='invalid'||returned.kind==='none')throw {code:'invalid_callback'};
   if(returned.state!==saved.state)throw {code:'wrong_state'};
   if(returned.kind==='error')return {phase:returned.error,operation:saved.operation};
   onStage('verifying');let reply;
   try{reply=await request('finish',{state:saved.state,browser_secret:saved.browser_secret,raw_nonce:saved.raw_nonce,code:returned.code});}
   catch(error){if(error.code==='restart_required')return {phase:'restart_required',operation:saved.operation};if(error.code!=='network'&&error.code!=='processing')throw error;onStage('checking');reply=await status(saved);}
   return settle(reply,saved);
  });},
 };
}
return {createClient,createStore,parseCallback,explanation,key};
});
