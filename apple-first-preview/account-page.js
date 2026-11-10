'use strict';
const $=id=>document.getElementById(id);
let manager,busy=false;
function message(error){return ({private_test_only:'This private setup test is not enabled for this Apple account.',cancelled:'Apple verification was cancelled. Nothing was deleted.',other_account:'Use the same Apple account shown here. Nothing was deleted.',unauthorized:'Apple verification did not finish. Please try again.',popup_blocked:'Open this page in Safari and allow the Apple sign-in window.'}[error?.code]||'The request was not confirmed. Check your connection and try again.');}
function working(value){busy=value;$('signIn').disabled=value||!manager;$('delete').disabled=value||!$('confirm').checked;}
(async()=>{
 const config=window.PeakWeekPrivateAppleConfig;if(!config?.enabled)return;
 try{
  PeakWeekAppleAuth.validateConfig(config,location.origin);
  await new Promise((resolve,reject)=>{const script=document.createElement('script');script.src='https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js';script.referrerPolicy='no-referrer';script.onload=resolve;script.onerror=reject;document.head.appendChild(script);});
  const authenticate=await PeakWeekAppleAuth.createAuthenticator({config,origin:location.origin,apple:window.AppleID,fetcher:window.fetch.bind(window)});
  manager=PeakWeekWebAccount.createAccountManager({authenticate,fetcher:window.fetch.bind(window),apiBase:config.supabaseOrigin+'/functions/v1/peakweek-native-api'});
  $('signIn').disabled=false;$('status').textContent='Sign in to see your connected training.';
 }catch(_){$('status').textContent='Apple setup could not start. Open this page in Safari and try again.';}
})();
$('signIn').addEventListener('click',async()=>{
 if(busy||!manager)return;working(true);$('account').hidden=true;$('confirm').checked=false;$('status').textContent='Finding your training…';
 try{const profiles=await manager.load();$('profiles').replaceChildren();for(const profile of profiles){const item=document.createElement('li');item.textContent=profile.name;$('profiles').appendChild(item);}$('status').textContent=profiles.length?'Your Apple connection is verified.':'No training profiles are linked to this account.';$('account').hidden=false;}
 catch(e){$('status').textContent=message(e);}finally{working(false);}
});
$('confirm').addEventListener('change',()=>{$('delete').disabled=busy||!$('confirm').checked;});
$('delete').addEventListener('click',async()=>{
 if(busy||!manager||!$('confirm').checked)return;working(true);$('status').textContent='Verify with Apple to confirm account deletion.';
 try{const result=await manager.deleteAccount(true);if(result.deleted){$('account').hidden=true;$('profiles').replaceChildren();$('status').textContent='Your Lifter account and training records have been deleted. Video cleanup finishes automatically.';}}
 catch(e){$('status').textContent=message(e);}finally{$('confirm').checked=false;working(false);}
});
