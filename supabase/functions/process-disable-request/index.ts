// process-disable-request/index.ts
// Handles accountability partner approval/denial of protection disable requests.
// Also checks for expired cooling-off periods.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface ProcessPayload {
  requestId?: string;
  action?: "approve" | "deny";
  // If no requestId/action, runs cleanup of expired requests
}

Deno.serve(async (req: Request) => {
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.includes(serviceRoleKey)) {
      return new Response("Unauthorized", { status: 401 });
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const payload = (await req.json()) as ProcessPayload;

    // If specific request + action, process it
    if (payload.requestId && payload.action) {
      const { requestId, action } = payload;

      const { data: request, error: fetchError } = await supabase
        .from("disable_requests")
        .select("*")
        .eq("id", requestId)
        .eq("status", "pending")
        .single();

      if (fetchError || !request) {
        return new Response(
          JSON.stringify({ error: "Request not found or already processed" }),
          { status: 404, headers: { "Content-Type": "application/json" } },
        );
      }

      if (action === "approve") {
        await supabase
          .from("disable_requests")
          .update({
            status: "approved",
            partner_approved: true,
            partner_approved_at: new Date().toISOString(),
          })
          .eq("id", requestId);

        // Notify the user that their request was approved
        try {
          await supabase.functions.invoke("send-push", {
            body: {
              userId: request.user_id,
              title: "Request Approved",
              body: "Your partner has approved the protection disable request. The cooling-off period is still active.",
              data: { type: "disable_approved", requestId },
            },
          });
        } catch {
          // Non-critical
        }

        return new Response(
          JSON.stringify({ message: "Request approved", requestId }),
          { headers: { "Content-Type": "application/json" } },
        );
      } else {
        // Deny — cancel the request
        await supabase
          .from("disable_requests")
          .update({ status: "cancelled" })
          .eq("id", requestId);

        // Notify the user
        try {
          await supabase.functions.invoke("send-push", {
            body: {
              userId: request.user_id,
              title: "Request Denied",
              body: "Your partner has denied the protection disable request. Stay strong!",
              data: { type: "disable_denied", requestId },
            },
          });
        } catch {
          // Non-critical
        }

        return new Response(
          JSON.stringify({ message: "Request denied", requestId }),
          { headers: { "Content-Type": "application/json" } },
        );
      }
    }

    // No specific request — run cleanup of expired pending requests
    const now = new Date().toISOString();

    // Find requests where cooloff has ended and partner approved
    const { data: readyRequests } = await supabase
      .from("disable_requests")
      .select("id, user_id")
      .eq("status", "approved")
      .lt("cooloff_ends_at", now);

    let expired = 0;

    if (readyRequests && readyRequests.length > 0) {
      // These requests have completed their cooling-off period with partner approval
      // In a full implementation, this would actually disable the blocking service
      for (const request of readyRequests) {
        await supabase
          .from("disable_requests")
          .update({ status: "expired" })
          .eq("id", request.id);

        try {
          await supabase.functions.invoke("send-push", {
            body: {
              userId: request.user_id,
              title: "Protection Disable Available",
              body: "Your cooling-off period has ended. You can now disable protection in the app.",
              data: { type: "cooloff_ended", requestId: request.id },
            },
          });
        } catch {
          // Non-critical
        }

        expired++;
      }
    }

    // Expire pending requests that have passed their cooloff without approval
    const { data: stalePending } = await supabase
      .from("disable_requests")
      .select("id")
      .eq("status", "pending")
      .lt("cooloff_ends_at", now);

    if (stalePending && stalePending.length > 0) {
      const staleIds = stalePending.map((r: { id: string }) => r.id);
      await supabase
        .from("disable_requests")
        .update({ status: "expired" })
        .in("id", staleIds);
      expired += stalePending.length;
    }

    return new Response(
      JSON.stringify({
        message: `Processed ${expired} expired requests`,
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
