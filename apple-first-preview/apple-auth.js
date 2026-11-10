(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.PeakWeekAppleAuth=api;})(typeof globalThis!=='undefined'?globalThis:this,function(){
'use strict';
const defaultConfig=Object.freeze({enabled:false,clientId:'com.peakweek.lifter.web',redirectURI:'https://rickndanger-ctrl.github.io/PeakWeek/apple-first-preview/callback.html',pageOrigin:'https://rickndanger-ctrl.github.io',supabaseOrigin:'https://otgsdsvswiehymubkyki.supabase.co',publicKey:''});
function validateConfig(c,origin){
 const redirect=new URL(c.redirectURI),supabase=new URL(c.supabaseOrigin);
 if(c.enabled!==true||typeof c.publicKey!=='string'||!c.publicKey||c.pageOrigin!==defaultConfig.pageOrigin||c.redirectURI!==defaultConfig.redirectURI||c.clientId!=='com.peakweek.lifter.web'||origin!==c.pageOrigin||redirect.origin!==origin||redirect.protocol!=='https:'||redirect.hash||redirect.search||supabase.origin!=='https://otgsdsvswiehymubkyki.supabase.co')throw {code:'unavailable'};
}
async function createAuthenticator({config,origin,apple,fetcher,cryptoImpl=globalThis.crypto}){
 validateConfig(config,origin);
 if(!apple?.auth?.init||!apple?.auth?.signIn||!cryptoImpl?.subtle)throw {code:'unavailable'};
 let challenge=null,busy=false;
 const hex=bytes=>Array.from(bytes,x=>x.toString(16).padStart(2,'0')).join('');
 async function prepare(){
  const rawNonce=hex(cryptoImpl.getRandomValues(new Uint8Array(32))),state=hex(cryptoImpl.getRandomValues(new Uint8Array(32)));
  const digest=await cryptoImpl.subtle.digest('SHA-256',new TextEncoder().encode(rawNonce));
  challenge={rawNonce,state};
  apple.auth.init({clientId:config.clientId,scope:'',redirectURI:config.redirectURI,state,nonce:hex(new Uint8Array(digest)),usePopup:true});
 }
 await prepare();
 return async function authenticate(){
  if(busy||!challenge)throw {code:'unavailable'};
  busy=true;const current=challenge;challenge=null;
  try{
   // Called synchronously from the button click; nonce preparation happened
   // before it so iPhone Safari retains the popup's user gesture.
   let response;
   try{response=await apple.auth.signIn();}catch(error){
    if(['popup_closed_by_user','user_cancelled_authorize','access_denied'].includes(error?.error))throw {code:'cancelled'};
    if(error?.error==='popup_blocked_by_browser')throw {code:'popup_blocked'};
    throw {code:'unauthorized'};
   }
   const authorization=response?.authorization;
   if(authorization?.state!==current.state||typeof authorization.id_token!=='string'||!authorization.id_token||typeof authorization.code!=='string'||!authorization.code)throw {code:'unauthorized'};
   const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),30000);
   try{
    const reply=await fetcher(config.supabaseOrigin+'/auth/v1/token?grant_type=id_token',{
     method:'POST',credentials:'omit',cache:'no-store',redirect:'error',referrerPolicy:'no-referrer',signal:controller.signal,
     headers:{'Content-Type':'application/json',apikey:config.publicKey},
     body:JSON.stringify({provider:'apple',id_token:authorization.id_token,nonce:current.rawNonce}),
    });
    const data=await reply.json().catch(()=>({}));
    if(!reply.ok||typeof data.access_token!=='string'||!data.access_token||typeof data.user?.id!=='string'||!data.user.id)throw {code:'unauthorized'};
    // Only the immediately following authenticated request receives these.
    // No refresh token, name or email is saved by the web setup.
    return {accessToken:data.access_token,appleCode:authorization.code,userID:data.user.id};
   }finally{clearTimeout(timer);}
  }finally{
   busy=false;
   await prepare();
  }
 };
}
return {defaultConfig,validateConfig,createAuthenticator};
});
