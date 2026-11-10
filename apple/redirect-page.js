'use strict';
if(window.PeakWeekUseAppleSetup!==false){
const $=id=>document.getElementById(id);
let client,busy=false,context=null;
const setupConfig=window.PeakWeekAppleConfig||window.PeakWeekPrivateAppleConfig;
const configured=setupConfig?.enabled===true;
const isAccount=document.body.dataset.operation==='manage';
const isCallback=document.body.dataset.callback==='true';
const invitation=PeakWeekOnboarding.invitation(location.hash);
const returned=window.PeakWeekAppleReturn;
delete window.PeakWeekAppleReturn;
function stage(value){
 $('status').textContent=({preparing:'Preparing your connection…',opening_apple:'Opening Apple sign-in in this tab…',verifying:'Verifying Apple sign-in…',checking:'Checking your setup…'}[value]||'');
}
function refreshContext(){try{context=client?.store.load()||null;}catch(error){context=null;throw error;}}
function controls(){
 $('apple').disabled=busy||!client;
 $('apple').hidden=!context&&!invitation&&!isAccount;
 $('check-status').hidden=!context;$('check-status').disabled=busy;
 $('retry-confirmation').hidden=context?.operation!=='delete';
 if(context?.operation==='delete')$('apple').disabled=busy||!$('retry-delete-confirm').checked;
 $('apple').textContent=context?.operation==='delete'?'Verify with Apple and delete':context?'Continue with Apple again':'Continue with Apple';
 $('delete').disabled=busy||!$('confirm').checked;
}
function visible(name){
 for(const id of ['welcome','ready','account','deleted'])$(id).hidden=id!==name;
}
function show(result){
 if(result.phase==='redirecting'||result.phase==='busy')return;
 if(result.phase==='complete'){
  if(result.operation==='claim')visible('ready');
  else if(result.operation==='manage'){
   visible('account');$('profiles').replaceChildren();
   for(const p of result.receipt.profiles){const li=document.createElement('li');li.textContent=p.name;$('profiles').appendChild(li);}
   $('account-summary').textContent=result.receipt.profiles.length?'Your Apple connection is verified.':'No training profiles are linked to this Apple account.';
   $('confirm').checked=false;
  }else visible('deleted');
  $('status').textContent='';return;
 }
 visible('welcome');
 $('status').textContent=({cancelled:'Apple sign-in was cancelled. Nothing was connected or deleted. Continue when you’re ready.',unauthorized:'Apple could not verify this sign-in. You can try again.',restart_required:'Your setup is saved. Continue with Apple to finish connecting.',processing:'Your setup is still being checked. Tap Check setup status in a moment; you do not need another invitation.'}[result.phase]||'');
}
function fail(error){
 visible('welcome');$('status').textContent=PeakWeekRedirect.explanation(error);
 if(error?.code==='expired'||error?.code==='missing_context')context=null;
 $('status').focus({preventScroll:true});$('status').scrollIntoView({block:'nearest'});
}
async function run(work){
 if(busy||!client)return;busy=true;controls();
 try{show(await work());refreshContext();}catch(error){fail(error);}finally{busy=false;controls();}
}
$('apple').addEventListener('click',()=>run(async()=>{
 refreshContext();
 if(isAccount&&context?.operation==='claim')return client.startManage();
 if(context)return client.restart($('retry-delete-confirm').checked);
 return isAccount?client.startManage():client.startClaim(invitation);
}));
$('check-status').addEventListener('click',()=>run(()=>client.resume()));
$('confirm').addEventListener('change',controls);
$('retry-delete-confirm').addEventListener('change',controls);
$('delete').addEventListener('click',()=>run(()=>client.startDeletion($('confirm').checked)));
(async()=>{
 if(!configured){$('status').textContent='This setup is not enabled yet.';return;}
 try{
  client=PeakWeekRedirect.createClient({config:setupConfig,pageOrigin:location.origin,storage:window.sessionStorage,fetcher:window.fetch.bind(window),navigate:url=>location.assign(url),onStage:stage});
  client.store.probe();
  // An explicit new invitation is new setup intent, never a request to show a
  // previous invitation/account result. No invitation is persisted here.
  if(!isCallback&&invitation)client.store.clear();
  refreshContext();
  if(isAccount&&context?.operation!=='manage'){client.store.clear();context=null;}
  controls();
  if(isCallback){
   const parsed=PeakWeekRedirect.parseCallback(returned?.search||'');
   if(returned?.eraseFailed)throw {code:'invalid_callback'};
   await run(()=>parsed.kind==='none'?client.resume():client.finish(parsed));
  }else if(context&&(!isAccount||context.operation!=='claim'))await run(()=>client.resume());
  else if(isAccount){context=null;$('welcome-title').textContent='Your Apple connection';$('intro').textContent='Continue with Apple to manage your connected training, even if you have not installed the app.';controls();}
  else if(!invitation)throw {code:'missing_context'};
 }catch(error){fail(error);controls();}
})();
// Safari can restore this document from its back-forward cache after Apple.
// Query status using the saved proof; never replay a URL code on pageshow.
window.addEventListener('pageshow',event=>{if(event.persisted&&client&&!busy)run(()=>client.resume());});

}
