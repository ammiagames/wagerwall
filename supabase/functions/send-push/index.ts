// send-push/index.ts
// Sends APNs push notifications to a specific user's registered devices.
// Called by other edge functions (notify-partner, daily-streak-update).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// APNs configuration — these should be set in Supabase Edge Function secrets
const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID") ?? "";
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID") ?? "";
const APNS_BUNDLE_ID = "com.wagerwall.app";
const APNS_HOST = Deno.env.get("APNS_ENVIRONMENT") === "production"
  ? "api.push.apple.com"
  : "api.sandbox.push.apple.com";

interface PushPayload {
  userId: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

Deno.serve(async (req: Request) => {
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.includes(serviceRoleKey)) {
      return new Response("Unauthorized", { status: 401 });
    }

    const { userId, title, body: messageBody, data } =
      (await req.json()) as PushPayload;

    if (!userId || !title || !messageBody) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: userId, title, body" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // Fetch user's push tokens
    const { data: tokens, error } = await supabase
      .from("push_tokens")
      .select("token")
      .eq("user_id", userId);

    if (error) throw error;
    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ message: "No push tokens registered for user" }),
        { headers: { "Content-Type": "application/json" } },
      );
    }

    // Build APNs payload
    const apnsPayload = {
      aps: {
        alert: { title, body: messageBody },
        sound: "default",
        badge: 1,
      },
      ...data,
    };

    // Note: Full APNs JWT signing requires the private key (.p8 file).
    // In production, configure APNS_AUTH_KEY secret and implement JWT signing.
    // For now, log the notification attempt for development.
    const results = [];

    if (!APNS_KEY_ID || !APNS_TEAM_ID) {
      // APNs not configured — log for development
      console.log(
        `[send-push] Would send to ${tokens.length} devices:`,
        JSON.stringify(apnsPayload),
      );

      return new Response(
        JSON.stringify({
          message: `APNs not configured. Would notify ${tokens.length} devices.`,
          payload: apnsPayload,
        }),
        { headers: { "Content-Type": "application/json" } },
      );
    }

    // Send to each device token
    for (const { token } of tokens) {
      try {
        const response = await fetch(
          `https://${APNS_HOST}/3/device/${token}`,
          {
            method: "POST",
            headers: {
              "apns-topic": APNS_BUNDLE_ID,
              "apns-push-type": "alert",
              "apns-priority": "10",
              "content-type": "application/json",
              // Authorization header with JWT would go here
              // "authorization": `bearer ${jwt}`,
            },
            body: JSON.stringify(apnsPayload),
          },
        );

        results.push({
          token: token.substring(0, 8) + "...",
          status: response.status,
        });

        // Remove invalid tokens
        if (response.status === 410) {
          await supabase
            .from("push_tokens")
            .delete()
            .eq("token", token);
        }
      } catch {
        results.push({
          token: token.substring(0, 8) + "...",
          status: "error",
        });
      }
    }

    return new Response(
      JSON.stringify({ sent: results.length, results }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
