// check-heartbeats/index.ts
// Finds stale device heartbeats (>45 min since last heartbeat) and notifies
// the accountability partner that the user may have uninstalled or disabled the app.
// Triggered by pg_cron every 15 minutes.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req: Request) => {
  try {
    // Verify authorization (cron or service role)
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.includes(serviceRoleKey)) {
      return new Response("Unauthorized", { status: 401 });
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // Find heartbeats that are stale (>45 minutes old) and still marked active
    const cutoff = new Date(Date.now() - 45 * 60 * 1000).toISOString();

    const { data: staleHeartbeats, error: fetchError } = await supabase
      .from("device_heartbeats")
      .select("id, user_id, device_id, last_heartbeat")
      .eq("is_active", true)
      .lt("last_heartbeat", cutoff);

    if (fetchError) {
      throw fetchError;
    }

    if (!staleHeartbeats || staleHeartbeats.length === 0) {
      return new Response(JSON.stringify({ message: "No stale heartbeats" }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // Mark stale heartbeats as inactive
    const staleIds = staleHeartbeats.map((h: { id: string }) => h.id);
    await supabase
      .from("device_heartbeats")
      .update({ is_active: false })
      .in("id", staleIds);

    // Notify partners for each affected user
    const userIds = [
      ...new Set(staleHeartbeats.map((h: { user_id: string }) => h.user_id)),
    ];

    for (const userId of userIds) {
      // Find active accountability partners
      const { data: partners } = await supabase
        .from("accountability_partners")
        .select("partner_email, partner_user_id")
        .eq("user_id", userId)
        .eq("status", "active");

      if (partners && partners.length > 0) {
        // Call notify-partner function for each partner
        for (const partner of partners) {
          try {
            await supabase.functions.invoke("notify-partner", {
              body: {
                userId,
                partnerEmail: partner.partner_email,
                partnerUserId: partner.partner_user_id,
                type: "heartbeat_stale",
                message:
                  "WagerWall may have been uninstalled or disabled on your partner's device.",
              },
            });
          } catch {
            // Continue notifying other partners even if one fails
          }
        }
      }
    }

    return new Response(
      JSON.stringify({
        message: `Processed ${staleHeartbeats.length} stale heartbeats for ${userIds.length} users`,
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
