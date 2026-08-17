// PeakWeek pipeline API. Bearer = the project anon key (passes verify_jwt);
// real credentials travel in X-PW-Token: a device token (client app) or a
// coach token (Mac app). Tokens are stored as SHA-256 hashes only.
import { createClient } from "jsr:@supabase/supabase-js@2";

const supa = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const BUCKET = "peakweek-videos";

async function sha256(s: string): Promise<string> {
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(d)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function deviceAuth(req: Request): Promise<{ clientId: string } | null> {
  const token = req.headers.get("X-PW-Token");
  if (!token) return null;
  const hash = await sha256(token);
  const { data } = await supa.from("pw_devices").select("id, client_id")
    .eq("token_hash", hash).maybeSingle();
  if (!data) return null;
  await supa.from("pw_devices").update({ last_seen_at: new Date().toISOString() })
    .eq("id", data.id);
  return { clientId: data.client_id };
}

async function coachAuth(req: Request): Promise<boolean> {
  const token = req.headers.get("X-PW-Token");
  if (!token) return false;
  const hash = await sha256(token);
  const { data } = await supa.from("pw_coach_tokens").select("id")
    .eq("token_hash", hash).maybeSingle();
  return !!data;
}

function pairingCode(): string {
  // 8 chars, unambiguous alphabet (no 0/O/1/I).
  const alphabet = "23456789ABCDEFGHJKMNPQRSTUVWXYZ";
  const bytes = crypto.getRandomValues(new Uint8Array(8));
  return Array.from(bytes).map((b) => alphabet[b % alphabet.length]).join("");
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  // Path after the function name: /peakweek-api/<route...>
  const parts = url.pathname.split("/").filter(Boolean);
  const route = parts.slice(1).join("/");

  try {
    // ---------- client-app routes (device token) ----------
    if (route === "pair" && req.method === "POST") {
      const { code, deviceName } = await req.json();
      if (!code) return json({ error: "missing code" }, 400);
      const { data: pc } = await supa.from("pw_pairing_codes")
        .select("code, client_id, expires_at, used_at")
        .eq("code", String(code).toUpperCase()).maybeSingle();
      if (!pc || pc.used_at || new Date(pc.expires_at) < new Date()) {
        return json({ error: "invalid or expired code" }, 401);
      }
      const token = crypto.randomUUID() + crypto.randomUUID();
      await supa.from("pw_pairing_codes").update({ used_at: new Date().toISOString() })
        .eq("code", pc.code);
      await supa.from("pw_devices").insert({
        client_id: pc.client_id,
        token_hash: await sha256(token),
        name: deviceName ?? null,
      });
      const { data: client } = await supa.from("pw_clients_mirror")
        .select("id, name, unit").eq("id", pc.client_id).single();
      return json({ token, client });
    }

    if (route === "week" && req.method === "GET") {
      const auth = await deviceAuth(req);
      if (!auth) return json({ error: "unauthorized" }, 401);
      const { data } = await supa.from("pw_published_weeks")
        .select("week_num, program_stamp, payload, published_at")
        .eq("client_id", auth.clientId).maybeSingle();
      return json({ week: data ?? null });
    }

    if (route === "submissions" && req.method === "POST") {
      const auth = await deviceAuth(req);
      if (!auth) return json({ error: "unauthorized" }, 401);
      const b = await req.json();
      if (!b.id || !b.lift || !b.load || !b.unit || !b.reps) {
        return json({ error: "missing fields" }, 400);
      }
      const hasVideo = !!b.has_video;
      const videoPath = hasVideo ? `${auth.clientId}/${b.id}.mp4` : null;
      const { error } = await supa.from("pw_submissions").upsert({
        id: b.id,
        client_id: auth.clientId,
        performed_at: b.performed_at ?? new Date().toISOString(),
        lift: b.lift,
        exercise_name: b.exercise_name ?? null,
        load: b.load,
        unit: b.unit,
        reps: b.reps,
        rpe: b.rpe ?? null,
        prescribed_pct: b.prescribed_pct ?? null,
        prescribed_rpe: b.prescribed_rpe ?? null,
        week_num: b.week_num ?? null,
        program_stamp: b.program_stamp ?? null,
        note: b.note ?? null,
        video_path: videoPath,
        video_status: hasVideo ? "pending" : "none",
      }, { onConflict: "id", ignoreDuplicates: true });
      if (error) return json({ error: error.message }, 500);
      if (hasVideo && videoPath) {
        const { data: up, error: upErr } = await supa.storage.from(BUCKET)
          .createSignedUploadUrl(videoPath);
        if (upErr) return json({ ok: true, upload: null, warning: upErr.message });
        return json({ ok: true, upload: { url: up.signedUrl, token: up.token, path: videoPath } });
      }
      return json({ ok: true });
    }

    if (route === "submissions/video-done" && req.method === "POST") {
      const auth = await deviceAuth(req);
      if (!auth) return json({ error: "unauthorized" }, 401);
      const { id } = await req.json();
      await supa.from("pw_submissions").update({ video_status: "uploaded" })
        .eq("id", id).eq("client_id", auth.clientId);
      return json({ ok: true });
    }

    if (route === "submissions/mine" && req.method === "GET") {
      const auth = await deviceAuth(req);
      if (!auth) return json({ error: "unauthorized" }, 401);
      const { data } = await supa.from("pw_submissions")
        .select("id, performed_at, lift, load, unit, reps, rpe, status, video_status, created_at")
        .eq("client_id", auth.clientId)
        .order("created_at", { ascending: false }).limit(20);
      return json({ submissions: data ?? [] });
    }

    // ---------- coach routes (coach token) ----------
    if (route.startsWith("admin/")) {
      if (!(await coachAuth(req))) return json({ error: "unauthorized" }, 401);
    }

    if (route === "admin/pairing-codes" && req.method === "POST") {
      const { client_id, name, unit } = await req.json();
      if (!client_id || !name || !unit) return json({ error: "missing fields" }, 400);
      await supa.from("pw_clients_mirror").upsert({ id: client_id, name, unit });
      const code = pairingCode();
      await supa.from("pw_pairing_codes").insert({
        code,
        client_id,
        expires_at: new Date(Date.now() + 24 * 3600 * 1000).toISOString(),
      });
      return json({ code });
    }

    if (route === "admin/inbox" && req.method === "GET") {
      const { data } = await supa.from("pw_submissions").select("*")
        .eq("status", "new").order("created_at").limit(100);
      // Orphan sweep: videos uploaded >14d ago whose submission was ingested
      // long ago (ack normally deletes; this catches lost acks).
      const cutoff = new Date(Date.now() - 14 * 86400 * 1000).toISOString();
      const { data: orphans } = await supa.from("pw_submissions")
        .select("id, video_path").eq("video_status", "uploaded")
        .lt("created_at", cutoff).limit(20);
      if (orphans?.length) {
        await supa.storage.from(BUCKET).remove(orphans.map((o) => o.video_path!));
        await supa.from("pw_submissions").update({ video_status: "none" })
          .in("id", orphans.map((o) => o.id));
      }
      return json({ submissions: data ?? [] });
    }

    if (route === "admin/video-url" && req.method === "POST") {
      const { path } = await req.json();
      if (!path) return json({ error: "missing path" }, 400);
      const { data, error } = await supa.storage.from(BUCKET)
        .createSignedUrl(path, 3600);
      if (error) return json({ error: error.message }, 404);
      return json({ url: data.signedUrl });
    }

    if (route === "admin/ack" && req.method === "POST") {
      const { ids } = await req.json();
      if (!Array.isArray(ids) || ids.length === 0) return json({ ok: true });
      const { data: rows } = await supa.from("pw_submissions")
        .select("id, video_path, video_status").in("id", ids);
      await supa.from("pw_submissions")
        .update({ status: "ingested", ingested_at: new Date().toISOString() })
        .in("id", ids);
      const paths = (rows ?? []).filter((r) => r.video_path && r.video_status === "uploaded")
        .map((r) => r.video_path!);
      if (paths.length) await supa.storage.from(BUCKET).remove(paths);
      return json({ ok: true });
    }

    if (route === "admin/publish-week" && req.method === "POST") {
      const { client_id, name, unit, week_num, program_stamp, payload } = await req.json();
      if (!client_id || !week_num || !payload) return json({ error: "missing fields" }, 400);
      if (name && unit) {
        await supa.from("pw_clients_mirror").upsert({ id: client_id, name, unit });
      }
      const { error } = await supa.from("pw_published_weeks").upsert({
        client_id,
        week_num,
        program_stamp: program_stamp ?? new Date().toISOString(),
        payload,
        published_at: new Date().toISOString(),
      });
      if (error) return json({ error: error.message }, 500);
      return json({ ok: true });
    }

    if (route === "admin/unpair" && req.method === "POST") {
      const { client_id } = await req.json();
      if (!client_id) return json({ error: "missing client_id" }, 400);
      await supa.from("pw_devices").delete().eq("client_id", client_id);
      return json({ ok: true });
    }

    return json({ error: "not found" }, 404);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
