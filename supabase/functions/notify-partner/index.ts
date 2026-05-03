// notify-partner/index.ts
// Routes notifications to an accountability partner via push notification and/or email.
// Called by check-heartbeats and process-disable-request.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface NotifyPayload {
  userId: string;
  partnerEmail?: string;
  partnerUserId?: string;
  type: "heartbeat_stale" | "disable_request" | "streak_milestone";
  message: string;
}

const notificationTitles: Record<string, string> = {
  heartbeat_stale: "Partner Alert",
  disable_request: "Protection Disable Request",
  streak_milestone: "Partner Milestone",
};

Deno.serve(async (req: Request) => {
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.includes(serviceRoleKey)) {
      return new Response("Unauthorized", { status: 401 });
    }

    const payload = (await req.json()) as NotifyPayload;
    const { userId, partnerEmail, partnerUserId, type, message } = payload;

    if (!userId || !type || !message) {
      return new Response(
        JSON.stringify({
          error: "Missing required fields: userId, type, message",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const title = notificationTitles[type] ?? "WagerWall";
    const results: string[] = [];

    // Get the user's display name for context
    const { data: profile } = await supabase
      .from("user_profiles")
      .select("display_name")
      .eq("id", userId)
      .single();

    const userName = profile?.display_name ?? "Your partner";
    const fullMessage = `${userName}: ${message}`;

    // Send push notification to partner if they have a user account
    if (partnerUserId) {
      try {
        await supabase.functions.invoke("send-push", {
          body: {
            userId: partnerUserId,
            title,
            body: fullMessage,
            data: { type, sourceUserId: userId },
          },
        });
        results.push("push_sent");
      } catch {
        results.push("push_failed");
      }
    }

    // Send email notification to partner
    if (partnerEmail) {
      // In production, integrate with an email service (SendGrid, Resend, etc.)
      // For now, log the email that would be sent
      console.log(
        `[notify-partner] Email to ${partnerEmail}: ${title} - ${fullMessage}`,
      );
      results.push("email_logged");
    }

    return new Response(
      JSON.stringify({
        message: `Notification sent via: ${results.join(", ")}`,
        type,
      }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
