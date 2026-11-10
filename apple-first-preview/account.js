(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.PeakWeekWebAccount=api;})(typeof globalThis!=='undefined'?globalThis:this,function(){
'use strict';
function createAccountManager({authenticate,fetcher,apiBase}){
 const base=new URL(apiBase);
 if(base.protocol!=='https:'||base.username||base.password||base.search||base.hash)throw Error('HTTPS API origin required');
 if(typeof authenticate!=='function'||typeof fetcher!=='function')throw Error('Verified authentication adapter required');
 let owner=null,busy=false;
 async function request(path,session,body){
  const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),30000);
  try{
   const response=await fetcher(base.href.replace(/\/$/,'')+path,{method:body?'POST':'GET',credentials:'omit',cache:'no-store',redirect:'error',referrerPolicy:'no-referrer',signal:controller.signal,headers:{Authorization:'Bearer '+session.accessToken,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});
   const data=await response.json().catch(()=>({}));
   if(!response.ok)throw {code:response.status===401?'unauthorized':data.code==='private_test_only'?'private_test_only':'network'};
   return data;
  }finally{clearTimeout(timer);}
 }
 return {
  async load(){
   if(busy)throw {code:"busy"};busy=true;
   try {
   owner=null;const session=await authenticate();
   if(!session?.userID||!session?.accessToken)throw {code:'unauthorized'};
   const data=await request('/lifter-account/profiles',session);
   if(!Array.isArray(data.profiles)||data.profiles.some(p=>typeof p.name!=='string'))throw {code:'invalid_reply'};
   owner=session.userID;return data.profiles.map(p=>({name:p.name}));
   } finally {busy=false;}
  },
  async deleteAccount(confirmed){
   if(busy)throw {code:'busy'};
   if(!confirmed||!owner)throw {code:'confirmation_required'};
   busy=true;try {
   const session=await authenticate();
   if(session?.userID!==owner||!session?.appleCode||!session?.accessToken)throw {code:'other_account'};
   const result=await request('/lifter-account/delete',session,{confirmation:'DELETE',apple_code:session.appleCode,apple_client_id:'com.peakweek.lifter.web'});
   if(result.ok!==true)throw {code:'invalid_reply'};
   owner=null;return {deleted:true,cleanupPending:result.cleanup_pending===true};
   } finally {busy=false;}
  }
 };
}
return {createAccountManager};
});
